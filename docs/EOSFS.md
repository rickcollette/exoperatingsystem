# EOSFS: the EOS native file system

Version 1 specification. The EOSFS specification is covered by the project's
MIT License.

EOSFS is an optional disk format, chosen when a disk is formatted (FORMAT's
Mode: Sparta, Atari, EOS). EOS continues to read and write SpartaDOS (SDFS
2.0/2.1) and Atari DOS 2 disks.

EOS is a ground-up rewrite: its kernel, loader, command processor, and
filesystem implementation are new EOS code, not a port of BW-DOS's FMS or a
patched SDX filesystem. EOSFS is a new on-disk allocation format built on
familiar SDFS 2.1 directory and volume conventions so EOS can share path
handling, directory operations, metadata, and kernel calls between SDFS and
EOSFS. The shared conventions provide compatibility; the extent mapping and
name index are EOS-specific.

Development uses modern host-side tools for speed and accuracy: MADS assembles
the 6502 code, Python utilities create and check filesystem images, a host-side
6502 simulator speeds up iteration, and emulator suites exercise disk
operations and compare results against reference behavior. This makes it
practical to measure allocation, lookup, and I/O costs while keeping the final
implementation small enough for Atari hardware. See [EOS benchmarks](BENCHMARKS.md)
for the measured workloads and their limits. These host tools are used while
building and testing EOS; they are not needed by the running Atari system.

## 1. The idea

EOSFS follows SDFS 2.1's disk organization, but it is not an SDFS disk. SDFS
keeps a file's sectors in **sector maps** (one two-byte sector number per data
sector); EOSFS keeps **extent lists** (runs of consecutive sectors: a start
and a count). The volume revision marks EOSFS, and an optional directory name
index uses otherwise unused fields in the directory header.

EOSFS retains the SDFS boot-sector and volume-header layout, allocation
bitmap, 23-byte directory entries, names, attributes, dates, and symbolic
link representation, except for the EOSFS revision and index metadata. This
lets EOS reuse its SDFS directory and path operations while selecting the
correct allocation mapping for each mounted volume:

* EOS's new filesystem engine is shared between its SDFS and EOSFS support:
  paths, directories, names, rename, delete, attributes, and the kernel
  interface. Only the step from "the n-th sector of the file" to "a sector
  number", plus freeing and trimming, differs for extents.
* Programs that read directories raw (mode `$14`, FIXLINK.COM and the like)
  see the same entries as on SDFS.
* Programs see exactly what they see on SDFS through the kernel
  (FFIRST/FNEXT entries, GETDFREE, CHKDSK).

## 2. Why it is faster

* A file is usually one extent: reading it is consecutive sectors with no map
  sectors to read in between, and positioning (POINT) is arithmetic within
  the extent list (one list sector holds 63 extents on a 256-byte disk; an
  SDFS map sector covers 126 sectors).
* Writing grows the file's last extent when the sector after it is free, and
  allocation starts from the volume's next-free hint, so files stay
  contiguous, which multi-sector transfers (E2) can use.
* Large directories, being files, are contiguous too.

EOS also uses its sector cache and write-back strategy for SDFS, so EOSFS is
not the only format that benefits from the rewritten filesystem code. The
extent layout adds its largest advantage on sequential files, repeated seeks,
and exact-name lookups in large directories. Real-drive results include disk
rotation and transfer time, so they vary by drive, protocol, geometry, and
machine; the benchmark document records the test setup.

## 3. On the disk

### 3.1 Volume header (sector 1)

As SDFS 2.1 (the SDX User Guide's layout), with the revision byte at offset
32 set to `$45` (SDFS 2.1: `$21`). Offsets 33-34 hold the sector size as in
SDFS 2.1. SDX does not recognise `$45` and leaves the disk alone (it will
not misread it); EOS takes `$45` as EOSFS.

The revision byte is also the volume's dirty flag: `$46` while changes may
not all be on the disk, `$45` when they are. Before the first sector of a
volume is written after its header was last written clean, EOS writes
sector 1 with `$46`; when it flushes the volume (a file closed, FLUSH, the
cache emptied for another disk) it writes every other changed sector
first and the header, with `$45`, last. A volume mounted with `$46` (EOS
stopped while writing: a reset, a crash, the power) gets a quick check:
the free count is counted again from the bitmap and the header is written
clean. CHKDSK /F is the whole check (lost sectors, files whose maps
disagree with the bitmap).

### 3.2 Extent lists

A file's directory entry points (its two-byte "map" field) at its first
extent list sector, as an SDFS entry points at its first sector map. A list
sector:

| Offset | Size | Field |
| --- | --- | --- |
| 0 | 2 | the next list sector, 0 = the last |
| 2 | 2 | the previous list sector, 0 = the first |
| 4 | 4 each | extents: start sector (2), count of sectors (2) |

(seclen - 4) / 4 extents fit: 31, 63 or 127 for 128, 256, 512-byte sectors.
A count of 0 ends the extents. A start of 0 is a gap (sparse file: those
sectors read as zeros; SDFS writes 0 in a map for the same). A new list
sector is chained only when the one before is full. An empty file has no
list (map field 0); an empty list sector (all zeros) is a valid empty list,
so a new file or directory is made exactly as on SDFS.

Directories are files: their data is SDFS directory entries, found through
their extent list.

### 3.3 Directory name index

A directory may have a name index: a file, kept through an extent list
like any other, with one byte per directory entry slot. Byte k belongs to
entry k (byte 0 to the header, unused): the hash of the entry's 11-byte
name (8 + 3, blank padded), or 0 for a slot that is free or deleted.

The hash: h = 0; for each of the 11 bytes, h = (h rotated left by one bit)
exclusive-or the byte; a result of 0 becomes 1.

The directory's header entry (its first 23 bytes) points at the index:
bytes 20-21 hold the index's first extent list sector and byte 22 holds
$FF. Those are the header's time (hour, minute, second); $FF is not a
valid second, so a header without an index (an older EOSFS disk, a
directory written raw) is simply scanned as on SDFS. An index that is
missing a slot's byte (past its sectors) reads as 0.

Looking up an exact name (no wildcards): the index bytes are compared
with the name's hash and only the entries whose byte matches are read and
compared. Every write of an entry updates its byte; MKDIR and FORMAT give
new directories an empty index; RMDIR frees it; a directory written raw
(mode $1C, e.g. SORTDIR) loses its index at close (its sectors are freed,
byte 22 becomes 0).

## 4. In EOS

* `eos/fms.asm` `mount`: revision `$45` sets the drive's file system to 3; the
  extents per list sector replace the map entries per sector.
* `eos/fmsx.icl`: `locate_x` (sector index to sector; growing the last extent or
  adding one, chaining list sectors, gaps when sectors are skipped).
* `eos/dos2i.icl` (DOS 2 bank): the name index (3.3); `eos/fms.asm` `ix_scan` uses it
  in `scan_name` and `find_dir`, `ent_write` keeps it.
* `eos/dos2x.icl` (in the DOS 2 bank, for room): `free_x` and `trim_x`.
* `FORMAT`: Mode EOS writes the `$45` header and the main directory's list.
* The dirty flag (3.1): `eos/dos2.asm` `hd_hook` (called by the FMS's
  `wr_buf` before every sector write) and `mn_chk` (the quick check at
  mount); `flush_drv` writes the header last.
* `tools/sdfs.py` reads and checks EOSFS images; `tools/eosfs.py` builds them.
* FORMAT in EOS mode writes the EOSFS boot loader. `BOOT file` records the
  file's first extent list in sector 1. Host images use `make eosfsboot` and
  `tools/eosfs.py build ... --boot file`. The loader supports 128 and 256 byte
  sectors; the stock OS cannot boot 512 byte sectors.

Version 1 does not write into a gap of a sparse file (166: a write that
would split a gap); reading gaps and writing past the end (which makes a
gap) work.

## 5. Later versions

* 24-bit sector numbers (volumes over 65535 sectors; XDCB devices).
* Writing into gaps.

## 6. Faster SDFS (E1), for every disk

Independent of EOSFS, for SDFS and EOSFS disks alike:

* Write-behind: changed sectors stay in the cache until they are dropped,
  flushed or the file is closed; a dropped one goes with the changed
  sectors right after it.
* Allocation from the volume's next-free hint; EOSFS grows a file's last
  extent in place.
* A second-level cache in an extended bank: on a machine with more than
  128K, EOS takes the top free 16 KB bank for 31 sectors. Sectors the cache
  drops are kept there (not those of a file read or written through to
  their end), a miss looks there before the disk, and a sector found there
  moves back (one copy only). `eos/l2.icl`. On a real drive's timing it
  halves the time of DIR and of opening files in big directories
  (docs/BENCHMARKS.md).
* High speed transfers: Ultra Speed, the XF551's and the Indus GT's
  commands (SIOSET); FORMAT's skews for them (E2).
* Multi-sector transfers where the device has them: EOS's own CompactFlash
  and SD drivers (SIDE, SIDE2, SIDE3, MyIDE II) move several sectors in one
  request.

Not done, with the reason: read-ahead (SIO transfers are synchronous, so
there is nothing to overlap; on the CF and SD cards the CPU moves every
byte itself, and a command's own cost is under 2% of a sector's) and a
free-run summary of the bitmap (the next-free hint already finds a free
sector at once unless the disk is full or fragmented).
