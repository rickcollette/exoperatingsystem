import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import hostsim  # noqa: E402
import m6502  # noqa: E402
import sdfs  # noqa: E402


def boot_program():
    body = bytes.fromhex('a9 42 8d 00 40 60') + bytes([0xEA]) * 294
    return (b'\xff\xff' + struct.pack('<HH', 0x2000, 0x2000 + len(body) - 1) + body +
            struct.pack('<HHH', 0x02E0, 0x02E1, 0x2000))


class LoaderBus:
    def __init__(self, image):
        self.ram = bytearray(65536)
        self.image = hostsim.Atr(image)

    def read(self, addr):
        return self.ram[addr]

    def write(self, addr, value):
        self.ram[addr] = value


class EOSFSBootTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.image = Path(self.tmp.name) / 'boot.atr'
        self.loader = (ROOT / 'build/eos/EOSFSBOOT.bin').read_bytes()

    def tearDown(self):
        self.tmp.cleanup()

    def make_image(self, seclen=256):
        sdfs.build(self.image, 720, seclen,
                   {'DOS/EOS.SYS': boot_program(), 'README.TXT': b'native EOSFS'},
                   eosfs=True, boot='DOS>EOS.SYS', bootcode=self.loader)

    def test_builder_installs_loader_and_extent_boot_marker(self):
        self.make_image()
        v = sdfs.Volume(self.image)
        entries = dict(v.walk())
        self.assertTrue(v.eosfs)
        self.assertEqual(v.boot[:9], self.loader[:9])
        self.assertEqual(v.img.sector(2), self.loader[128:256])
        self.assertEqual(v.img.sector(3), self.loader[256:384])
        self.assertEqual(v.boot_map, entries['/DOS/EOS.SYS']['map'])
        v.check()
        self.assertFalse(v.errors, v.errors)

    def test_loader_reads_eosfs_extents_and_runs_xex(self):
        for seclen in (128, 256):
            with self.subTest(seclen=seclen):
                self.image = Path(self.tmp.name) / ('boot%d.atr' % seclen)
                self.make_image(seclen)
                bus = LoaderBus(self.image)
                boot = b''.join(bus.image.read(n) for n in (1, 2, 3))
                bus.ram[0x3000:0x3180] = boot
                cpu = m6502.CPU(bus)
                cpu.pc = 0x3006
                stop = 0xF000
                cpu.push((stop - 1) >> 8)
                cpu.push((stop - 1) & 0xFF)

                def rts():
                    lo = cpu.pull()
                    cpu.pc = (((cpu.pull() << 8) | lo) + 1) & 0xFFFF

                for _ in range(200000):
                    if cpu.pc == stop:
                        break
                    if cpu.pc == 0xE459:   # SIOV
                        sec = bus.ram[0x030A] | bus.ram[0x030B] << 8
                        addr = bus.ram[0x0304] | bus.ram[0x0305] << 8
                        size = bus.ram[0x0308] | bus.ram[0x0309] << 8
                        data = bus.image.read(sec)
                        self.assertIsNotNone(data, 'loader read sector %d' % sec)
                        bus.ram[addr:addr + size] = data[:size]
                        cpu.y = 1
                        cpu.nz(1)
                        rts()
                    else:
                        cpu.step()
                else:
                    self.fail('boot loader did not finish')
                self.assertEqual(bus.ram[0x4000], 0x42)

    def test_rejects_missing_boot_file_and_512_byte_boot_volume(self):
        with self.assertRaisesRegex(sdfs.SdfsError, 'boot file not found'):
            sdfs.build(self.image, 720, 256, {}, eosfs=True, boot='NO.SYS',
                       bootcode=self.loader)
        with self.assertRaisesRegex(sdfs.SdfsError, 'cannot boot 512-byte'):
            sdfs.build(self.image, 720, 512, {'EOS.SYS': boot_program()},
                       eosfs=True, boot='EOS.SYS', bootcode=self.loader)

    def test_v2_long_names_and_case_are_distinct(self):
        files = {
            'projects/Extended-Operating-System/readme.txt': b'lower',
            'projects/Extended-Operating-System/Readme.txt': b'mixed',
            'projects/Extended-Operating-System/a-name-with-31-charactersxx.txt': b'31',
        }
        sdfs.build(self.image, 720, 256, files, eosfs=True)
        v = sdfs.Volume(self.image)
        entries = dict(v.walk())
        self.assertEqual(v.version, sdfs.EOSFS_CLEAN)
        self.assertEqual(v.entry_size, sdfs.EOSFS_ENTRY)
        self.assertEqual(entries['/projects/Extended-Operating-System/readme.txt']['data'], b'lower')
        self.assertEqual(entries['/projects/Extended-Operating-System/Readme.txt']['data'], b'mixed')
        self.assertIn('/projects/Extended-Operating-System/a-name-with-31-charactersxx.txt', entries)
        v.check()
        self.assertFalse(v.errors, v.errors)

    def test_v2_rejects_name_over_31_bytes(self):
        with self.assertRaisesRegex(sdfs.SdfsError, '1..31 bytes'):
            sdfs.build(self.image, 720, 256, {'x' * 32: b'too long'}, eosfs=True)
        with self.assertRaisesRegex(sdfs.SdfsError, 'invalid EOSFS name'):
            sdfs.build(self.image, 720, 256, {'literal*name': b'bad'}, eosfs=True)
        with self.assertRaisesRegex(sdfs.SdfsError, 'invalid EOSFS name'):
            sdfs.build(self.image, 720, 256, {'has\x1fcontrol': b'bad'}, eosfs=True)

    def test_v2_path_limit_is_127_bytes(self):
        component = 'x' * 31
        at_limit = '/'.join((component, component, component, 'y' * 30))
        self.assertEqual(len('/' + at_limit), 127)
        sdfs.build(self.image, 720, 256, {at_limit: b'ok'}, eosfs=True)
        with self.assertRaisesRegex(sdfs.SdfsError, 'exceeds 127 bytes'):
            sdfs.build(self.image, 720, 256, {at_limit + 'z': b'long'}, eosfs=True)

    def test_overwrite_uses_v2_entry_size_and_exact_names(self):
        sdfs.build(self.image, 720, 256, {'startup.bat': b'old contents'}, eosfs=True)
        sdfs.overwrite(self.image, 'startup.bat', b'new', newname='Startup.bat')
        volume = sdfs.Volume(self.image)
        entries = dict(volume.check())
        self.assertNotIn('/startup.bat', entries)
        self.assertEqual(entries['/Startup.bat']['data'], b'new')
        self.assertFalse(volume.errors, volume.errors)


if __name__ == '__main__':
    unittest.main()
