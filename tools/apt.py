"""Read and safely edit Atari Partition Table (APT) sectors.

This is the host-side reference implementation used to create disposable APT
fixtures and verify byte preservation. Runtime EOS tools use the same on-disk
layout, but perform sector I/O through the Atari SIO interface.
"""
from dataclasses import dataclass


SECTOR_SIZE = 512
HEADER_SIZE = 16
ENTRY_SIZE = 16
SIGNATURE = b"APT"
MAX_CHAIN = 4096


class APTError(ValueError):
    pass


def _u32le(data, offset):
    return int.from_bytes(data[offset:offset + 4], "little")


def _p32le(data, offset, value):
    data[offset:offset + 4] = int(value).to_bytes(4, "little")


@dataclass
class TableSector:
    lba: int
    header_offset: int
    raw: bytearray
    logical: bytearray
    even_bytes: bool
    next_lba: int
    next_offset: int
    previous_lba: int
    previous_offset: int
    entry_count: int
    entries: list


@dataclass
class APTEntry:
    data: bytearray
    table_sector: TableSector
    logical_offset: int

    @property
    def access(self):
        return self.data[0]

    @property
    def partition_type(self):
        return self.data[1]

    @property
    def sector_size_code(self):
        return self.data[0] & 3

    @property
    def start(self):
        return _u32le(self.data, 2)

    @property
    def size(self):
        return _u32le(self.data, 6)

    @property
    def partition_id(self):
        return int.from_bytes(self.data[10:12], "little")

    @property
    def reserved(self):
        return bool(self.access & 0x80 or self.access & 0x30 or
                    self.partition_type not in (0, 1, 2, 3))


class APTTable:
    """APT table backed by read_sector(lba) and write_sector(lba, bytes)."""

    def __init__(self, read_sector, write_sector, sector_count):
        self._read = read_sector
        self._write = write_sector
        self.sector_count = sector_count
        self.sectors = []
        self.entries = []
        self._dirty = set()
        self._load()

    @staticmethod
    def _decode_sector(raw, even_bytes):
        if len(raw) != SECTOR_SIZE:
            raise APTError("APT requires 512-byte physical sectors")
        return bytearray(raw[::2] if even_bytes else raw)

    @staticmethod
    def _encode_sector(logical, raw, even_bytes):
        result = bytearray(raw)
        if even_bytes:
            result[::2] = logical
        else:
            result[:] = logical
        return result

    @staticmethod
    def _find_header(sector):
        for offset in range(0, len(sector) - HEADER_SIZE + 1, ENTRY_SIZE):
            if sector[offset + 1:offset + 4] == SIGNATURE:
                return offset
        return None

    def _locate_first(self):
        raw = self._read(0)
        if len(raw) != SECTOR_SIZE:
            raise APTError("sector 0 is not 512 bytes")
        for even in (False, True):
            logical = self._decode_sector(raw, even)
            off = self._find_header(logical)
            if off == 0:
                return 0, off, even
        # A PC protective MBR can contain the APT container in type $7F.
        for i in range(4):
            off = 446 + i * 16
            if raw[off + 4] == 0x7F:
                start = int.from_bytes(raw[off + 8:off + 12], "little")
                if 0 < start < self.sector_count:
                    candidate = self._read(start)
                    for even in (False, True):
                        logical = self._decode_sector(candidate, even)
                        hdr = self._find_header(logical)
                        if hdr == 0:
                            return start, hdr, even
        raise APTError("APT header not found at LBA 0 or in protective partition")

    def _load(self):
        lba, offset, even = self._locate_first()
        seen = set()
        prev = 0
        while True:
            if len(self.sectors) >= MAX_CHAIN:
                raise APTError("APT chain exceeds safety limit")
            if lba in seen or not 0 <= lba < self.sector_count:
                raise APTError(f"invalid or cyclic APT sector chain at LBA {lba}")
            seen.add(lba)
            raw = bytearray(self._read(lba))
            logical = self._decode_sector(raw, even)
            if offset + HEADER_SIZE > len(logical):
                raise APTError(f"header offset out of range in LBA {lba}")
            h = logical[offset:offset + HEADER_SIZE]
            if h[1:4] != SIGNATURE:
                raise APTError(f"bad APT signature in LBA {lba}")
            count = h[5]
            if not 1 <= count <= 32 or offset + count * ENTRY_SIZE > len(logical):
                raise APTError(f"invalid entry count in LBA {lba}")
            nxt = _u32le(h, 8)
            prv = _u32le(h, 12)
            sector = TableSector(lba, offset, raw, logical, even, nxt,
                                 h[6] * ENTRY_SIZE, prv, h[7] * ENTRY_SIZE,
                                 count, [])
            if self.sectors and (prv != prev or sector.previous_offset != self.sectors[-1].header_offset):
                raise APTError(f"broken backward link in LBA {lba}")
            for n in range(1, count):
                entryoff = offset + n * ENTRY_SIZE
                entry = APTEntry(bytearray(logical[entryoff:entryoff + ENTRY_SIZE]),
                                 sector, entryoff)
                sector.entries.append(entry)
                self.entries.append(entry)
            self.sectors.append(sector)
            if not nxt:
                break
            prev, lba, offset = sector.lba, nxt, sector.next_offset
            if offset % ENTRY_SIZE or offset + HEADER_SIZE > len(logical):
                raise APTError("next APT header offset is invalid")
        first = self.sectors[0]
        h = first.logical[first.header_offset:first.header_offset + HEADER_SIZE]
        self.flags = h[0]
        self.revision = (h[0] >> 5) & 3
        self.boot_drive = h[4] & 0x0F
        self.mapping_slots = 15 + (h[0] & 0x0F)
        if len(self.entries) < self.mapping_slots:
            raise APTError("APT table is shorter than its declared mapping slots")
        self.mappings = self.entries[:self.mapping_slots]
        self.partitions = self.entries[self.mapping_slots:]
        if self.revision != 0:
            self.read_only_reason = "unknown APT table revision"
        else:
            self.read_only_reason = ""

    def _mutable(self, entry=None):
        if self.read_only_reason:
            raise APTError(self.read_only_reason)
        if entry is not None and entry.reserved:
            raise APTError("reserved or unknown partition entries are read-only")

    def _dirty_entry(self, entry):
        self._dirty.add(entry.table_sector.lba)

    def set_boot_drive(self, drive):
        self._mutable()
        if drive not in range(16):
            raise APTError("boot drive must be 0 (none) through 15")
        first = self.sectors[0]
        first.logical[first.header_offset + 4] = drive
        self._dirty.add(first.lba)
        self.boot_drive = drive

    def mapped_partition(self, drive):
        """The 1-based partition number mapped to drive, or None."""
        slot = self.mappings[drive - 1]
        if not slot.data[0] & 3:
            return None
        for n, part in enumerate(self.partitions, 1):
            if part.data[0] & 3 and part.data[1:12] == slot.data[1:12]:
                return n
        return None

    def set_mapping(self, drive, partition_number=None):
        """Map D1:-D15: to a 1-based partition-table entry; None unmaps."""
        self._mutable()
        if drive not in range(1, self.mapping_slots + 1):
            raise APTError("drive is outside the mapping slot range")
        slot = self.mappings[drive - 1]
        if partition_number is None:
            if slot.data[0] != 0:
                self._mutable(slot)
            slot.data[0] = 0
            self._dirty_entry(slot)
            return
        if not 1 <= partition_number <= len(self.partitions):
            raise APTError("partition number is out of range")
        part = self.partitions[partition_number - 1]
        self._mutable(part)
        if part.partition_type != 0:
            raise APTError("only DOS partitions can be mapped to a DOS drive")
        if part.data[0] & 3 == 0 or not part.start or not part.size:
            raise APTError("partition is empty or invalid")
        # A mapping slot is a byte copy of the partition entry, ID included
        # (as IDEA2APT writes them and the IDE2.0PLUS BIOS reads them; the
        # BIOS does not check the ID, IDEA2APT numbers partitions from 0).
        slot.data[:] = part.data
        self._dirty_entry(slot)

    def set_partition(self, number, *, start=None, size=None, sector_size=None,
                       automount=None, write_protected=None):
        """Edit a known DOS partition entry; all omitted fields are preserved."""
        self._mutable()
        if not 1 <= number <= len(self.partitions):
            raise APTError("partition number is out of range")
        part = self.partitions[number - 1]
        self._mutable(part)
        if part.partition_type != 0:
            raise APTError("only known DOS partitions can be edited")
        before = bytes(part.data[1:12])
        if start is not None:
            if not 1 <= start < self.sector_count:
                raise APTError("partition start is outside the disk")
            _p32le(part.data, 2, start)
        if size is not None:
            if size <= 0 or part.start + size > self.sector_count:
                raise APTError("partition size is outside the disk")
            _p32le(part.data, 6, size)
        if sector_size is not None:
            codes = {128: 1, 256: 2, 512: 3}
            if sector_size not in codes:
                raise APTError("APT sector size must be 128, 256, or 512")
            part.data[0] = (part.data[0] & 0xFC) | codes[sector_size]
        if automount is not None:
            part.data[12] = (part.data[12] | 0x40) if automount else (part.data[12] & ~0x40)
        if write_protected is not None:
            part.data[12] = (part.data[12] | 0x80) if write_protected else (part.data[12] & ~0x80)
        end = part.start + part.size
        if end > self.sector_count:
            raise APTError("partition extent is outside the disk")
        for other_number, other in enumerate(self.partitions, 1):
            if other_number == number or not other.start or not other.size:
                continue
            if part.start < other.start + other.size and other.start < end:
                raise APTError(f"partition overlaps partition {other_number}")
        self._dirty_entry(part)
        # Update any mapping slots referring to this partition without touching
        # unrelated/reserved bytes in the slot.
        for slot in self.mappings:
            if slot.data[0] & 3 and not slot.data[0] & 0x80 and \
                    bytes(slot.data[1:12]) == before:
                slot.data[:] = part.data
                self._dirty_entry(slot)

    def write(self):
        """Write dirty table sectors, preserving all unrecognized sector bytes."""
        self._mutable()
        by_lba = {s.lba: s for s in self.sectors}
        for entry in self.entries:
            if entry.table_sector.lba in self._dirty:
                start = entry.logical_offset
                entry.table_sector.logical[start:start + ENTRY_SIZE] = entry.data
        for lba in sorted(self._dirty):
            sector = by_lba[lba]
            raw = self._encode_sector(sector.logical, sector.raw, sector.even_bytes)
            self._write(lba, bytes(raw))
        self._dirty.clear()


def from_bytes(image):
    """Open a mutable raw disk image bytearray (512-byte sectors)."""
    if len(image) % SECTOR_SIZE:
        raise APTError("disk image length is not a multiple of 512 bytes")
    count = len(image) // SECTOR_SIZE

    def read(lba):
        start = lba * SECTOR_SIZE
        return bytes(image[start:start + SECTOR_SIZE])

    def write(lba, data):
        start = lba * SECTOR_SIZE
        image[start:start + SECTOR_SIZE] = data

    return APTTable(read, write, count)


def new_table(partitions, mappings=None, boot_drive=0):
    """A fresh single-sector revision 0 table for a disposable disk image.

    partitions: dicts with start, size and optionally sector_size (512),
    id (number), automount and write_protected; mappings: {drive: partition
    number}. Returns the 512-byte sector to write at LBA 0. EOS's APT
    command never creates tables this way; it only edits existing ones.
    """
    count = 1 + 15 + len(partitions)
    if count > 32:
        raise APTError("a single table sector holds at most 16 partitions")
    sec = bytearray(SECTOR_SIZE)
    sec[0:6] = bytes([0]) + SIGNATURE + bytes([boot_drive & 0x0F, count])
    codes = {128: 1, 256: 2, 512: 3}
    entries = []
    for n, p in enumerate(partitions, 1):
        e = bytearray(ENTRY_SIZE)
        e[0] = codes[p.get("sector_size", 512)]
        _p32le(e, 2, p["start"])
        _p32le(e, 6, p["size"])
        e[10:12] = p.get("id", n).to_bytes(2, "little")
        e[12] = (0x40 if p.get("automount", True) else 0) | \
                (0x80 if p.get("write_protected") else 0)
        entries.append(e)
    for drive, n in (mappings or {}).items():
        off = drive * ENTRY_SIZE
        sec[off:off + ENTRY_SIZE] = entries[n - 1]
    for n, e in enumerate(entries):
        off = (16 + n) * ENTRY_SIZE
        sec[off:off + ENTRY_SIZE] = e
    return bytes(sec)
