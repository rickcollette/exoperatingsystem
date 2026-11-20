import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import mku1mb


def bank(number, tail=b"EOS-RESET-TAIL!!"):
    return bytes([number]) * (mku1mb.BANK - len(tail)) + tail


class U1MBImageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def inputs(self, banks):
        paths = []
        for i, data in enumerate(banks):
            path = Path(self.tmp.name) / f"bank{i}.bin"
            path.write_bytes(data)
            paths.append(path)
        return paths

    def test_pads_to_exact_raw_slot_size(self):
        image = mku1mb.build(self.inputs([bank(1), bank(2)]))
        self.assertEqual(len(image), 40 * mku1mb.BANK)
        self.assertEqual(image[:mku1mb.BANK], bank(1))
        self.assertEqual(image[mku1mb.BANK:2 * mku1mb.BANK], bank(2))
        erased = image[2 * mku1mb.BANK:]
        self.assertEqual(erased[:mku1mb.BANK - mku1mb.TAIL],
                         b"\xff" * (mku1mb.BANK - mku1mb.TAIL))
        self.assertEqual(erased[-mku1mb.TAIL:], bank(1)[-mku1mb.TAIL:])

    def test_rejects_overflow_and_mismatched_tails(self):
        with self.assertRaisesRegex(ValueError, "holds 40"):
            mku1mb.build(self.inputs([bank(i % 255) for i in range(41)]))
        with self.assertRaisesRegex(ValueError, "tails differ"):
            mku1mb.build(self.inputs([bank(1), bank(2, b"different-tail!!")]))

    def test_u1mb_kernel_uses_fixed_sdx_bank_latch(self):
        root = Path(__file__).resolve().parents[1]
        kernel = (root / "build/u1mb/kernel.bin").read_bytes()
        standard = (root / "build/eos/kernel.bin").read_bytes()
        self.assertIn(bytes.fromhex("8d e0 d5"), kernel)  # STA $D5E0
        self.assertNotIn(bytes.fromhex("9d 00 d5"), kernel)  # no AtariMax STA $D500,X
        self.assertIn(bytes.fromhex("9d 00 d5"), standard)
        self.assertNotIn(bytes.fromhex("8d e0 d5"), standard)


if __name__ == "__main__":
    unittest.main()
