import unittest

from tools.apt import APTError, APTTable, ENTRY_SIZE, SECTOR_SIZE, from_bytes, new_table


def header(flags=0, count=17, next_lba=0, prev_lba=0, next_off=0, prev_off=0,
           boot=1):
    data = bytearray(16)
    data[0] = flags
    data[1:4] = b"APT"
    data[4] = boot
    data[5] = count
    data[6] = next_off // ENTRY_SIZE
    data[7] = prev_off // ENTRY_SIZE
    data[8:12] = next_lba.to_bytes(4, "little")
    data[12:16] = prev_lba.to_bytes(4, "little")
    return data


def entry(access=3, ptype=0, start=20, size=100, part_id=1, flags=0):
    data = bytearray(16)
    data[0] = access
    data[1] = ptype
    data[2:6] = start.to_bytes(4, "little")
    data[6:10] = size.to_bytes(4, "little")
    data[10:12] = part_id.to_bytes(2, "little")
    data[12] = flags
    return data


def image_with_table(flags=0):
    image = bytearray(128 * SECTOR_SIZE)
    sec = bytearray(SECTOR_SIZE)
    sec[:16] = header(flags=flags, count=18, boot=4)
    # Fifteen mapping slots; slot 4 currently maps partition 1.
    sec[16 + 4 * 16:16 + 5 * 16] = entry(part_id=1, flags=0x40)
    # Remaining mapping entries are empty. Partition table begins at entry 16.
    sec[16 + 15 * 16:16 + 16 * 16] = entry()
    # Include a reserved/unknown record after the editable DOS partition.
    sec[16 + 16 * 16:16 + 17 * 16] = entry(access=0x83, ptype=0x45,
                                             start=120, size=4, part_id=0x1234)
    if flags & 0x80:
        image[:SECTOR_SIZE:2] = sec[:SECTOR_SIZE // 2]
    else:
        image[:SECTOR_SIZE] = sec
    return image


class APTTests(unittest.TestCase):
    def test_reads_and_updates_mapping_boot_and_dos_partition(self):
        image = image_with_table()
        table = from_bytes(image)
        self.assertEqual(table.boot_drive, 4)
        self.assertEqual(len(table.mappings), 15)
        self.assertEqual(len(table.partitions), 2)
        table.set_boot_drive(2)
        table.set_mapping(1, 1)
        table.set_partition(1, start=24, size=90, automount=False,
                            write_protected=True)
        table.write()
        again = from_bytes(image)
        self.assertEqual(again.boot_drive, 2)
        self.assertEqual(again.partitions[0].start, 24)
        self.assertEqual(again.partitions[0].size, 90)
        self.assertEqual(again.partitions[0].data[12] & 0xC0, 0x80)
        self.assertEqual(again.mappings[0].data[10:12], b"\x01\x00")

    def test_preserves_unknown_reserved_entries_and_unrelated_sector_bytes(self):
        image = image_with_table()
        image[400:446] = bytes(range(46))
        before_unknown = bytes(image[16 + 16 * 16:16 + 17 * 16])
        table = from_bytes(image)
        table.set_boot_drive(3)
        table.set_partition(1, size=88)
        with self.assertRaises(APTError):
            table.set_partition(2, start=70)
        table.write()
        self.assertEqual(bytes(image[16 + 16 * 16:16 + 17 * 16]), before_unknown)
        self.assertEqual(image[400:446], bytes(range(46)))

    def test_supports_even_byte_only_tables_without_touching_odd_bytes(self):
        image = bytearray(128 * SECTOR_SIZE)
        first = bytearray(SECTOR_SIZE)
        first[:16] = header(flags=0x80, count=16, next_lba=1, boot=4)
        second = bytearray(SECTOR_SIZE)
        second[:16] = header(count=3, prev_lba=0)
        second[16:32] = entry()
        second[32:48] = entry(access=0x83, ptype=0x45, start=120,
                               size=4, part_id=0x1234)
        image[:SECTOR_SIZE:2] = first[:SECTOR_SIZE // 2]
        image[SECTOR_SIZE:2 * SECTOR_SIZE:2] = second[:SECTOR_SIZE // 2]
        image[1:SECTOR_SIZE:2] = b"\xA5" * 256
        image[SECTOR_SIZE + 1:2 * SECTOR_SIZE:2] = b"\x5A" * 256
        table = from_bytes(image)
        self.assertEqual(table.boot_drive, 4)
        table.set_boot_drive(5)
        table.write()
        self.assertEqual(image[1:SECTOR_SIZE:2], b"\xA5" * 256)
        self.assertEqual(image[SECTOR_SIZE + 1:2 * SECTOR_SIZE:2], b"\x5A" * 256)
        self.assertEqual(from_bytes(image).boot_drive, 5)

    def test_reads_table_chain_and_rejects_cycle(self):
        image = bytearray(128 * SECTOR_SIZE)
        first = bytearray(SECTOR_SIZE)
        first[:16] = header(count=2, next_lba=1, next_off=0)
        first[16:32] = entry()
        second = bytearray(SECTOR_SIZE)
        second[:16] = header(count=16, prev_lba=0, prev_off=0)
        # Fourteen mapping slots continue in the linked sector; the final slot
        # and partition entry make up the declared fifteen slots plus partition.
        for i in range(15):
            second[16 + i * 16:32 + i * 16] = entry()
        image[:SECTOR_SIZE] = first
        image[SECTOR_SIZE:2 * SECTOR_SIZE] = second
        table = from_bytes(image)
        self.assertEqual(len(table.sectors), 2)
        self.assertEqual(len(table.partitions), 1)
        second[:16] = header(count=16, next_lba=1, prev_lba=0)
        image[SECTOR_SIZE:2 * SECTOR_SIZE] = second
        with self.assertRaisesRegex(APTError, "cyclic"):
            from_bytes(image)

    def test_rejects_unknown_revision_for_writes(self):
        image = image_with_table(flags=0x20)
        table = from_bytes(image)
        with self.assertRaisesRegex(APTError, "unknown APT table revision"):
            table.set_boot_drive(1)

    def test_mapping_copies_partition_id_and_follows_edits(self):
        image = image_with_table()
        table = from_bytes(image)
        table.partitions[0].data[10:12] = (0x0102).to_bytes(2, "little")
        table._dirty_entry(table.partitions[0])
        table.set_mapping(2, 1)
        table.set_partition(1, size=80)
        table.write()
        again = from_bytes(image)
        self.assertEqual(again.mappings[1].data, again.partitions[0].data)
        self.assertEqual(again.mapped_partition(2), 1)
        self.assertEqual(again.mappings[1].size, 80)
        # ID 0 (IDEA2APT's first partition) maps like any other
        table = from_bytes(image)
        table.partitions[0].data[10:12] = b"\x00\x00"
        table._dirty_entry(table.partitions[0])
        table.set_mapping(3, 1)
        table.write()
        self.assertEqual(from_bytes(image).mapped_partition(3), 1)

    def test_new_table_is_read_back(self):
        image = bytearray(4096 * SECTOR_SIZE)
        image[:SECTOR_SIZE] = new_table(
            [{"start": 64, "size": 1024}, {"start": 1088, "size": 512, "sector_size": 256}],
            {2: 1, 3: 2}, boot_drive=2)
        table = from_bytes(image)
        self.assertEqual(table.boot_drive, 2)
        self.assertEqual([p.start for p in table.partitions], [64, 1088])
        self.assertEqual(table.mapped_partition(2), 1)
        self.assertEqual(table.mapped_partition(3), 2)
        self.assertIsNone(table.mapped_partition(1))
        self.assertEqual(table.partitions[1].sector_size_code, 2)

    def test_rejects_invalid_header_count(self):
        image = image_with_table()
        image[5] = 0
        with self.assertRaisesRegex(APTError, "entry count"):
            from_bytes(image)


if __name__ == "__main__":
    unittest.main()
