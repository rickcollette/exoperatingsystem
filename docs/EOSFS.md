# EOSFS: the EOS native file system

Version 2 specification. The EOSFS specification is covered by the project's
MIT License.

EOSFS is EOS's resident filesystem. SDFS and Atari DOS volumes are handled by
transient Toolkit programs, keeping their parsers and compatibility state out
of the always-resident kernel.

EOS is a ground-up rewrite: its kernel, loader, command processor, and
filesystem implementation are new EOS code, not a port of BW-DOS's FMS or a
patched SDX filesystem. EOSFS has its own extent allocation and length-tagged
directory records. Native callers see that one record shape even for compact
read-only `CAR:` storage; no native command parses an SDFS/8.3 record.

Development uses modern host-side tools for speed and accuracy: MADS assembles
the 6502 code, Python utilities create and check filesystem images, a host-side
6502 simulator speeds up iteration, and emulator suites exercise disk
operations and compare results against reference behavior. This makes it
practical to measure allocation, lookup, and I/O costs while keeping the final
implementation small enough for Atari hardware. See [EOS benchmarks](BENCHMARKS.md)
for the measured workloads and their limits. These host tools are used while
building and testing EOS; they are not needed by the running Atari system.

## 1. The idea

EOSFS retains the compact volume header, bitmap and extent allocation proven
by version 1, but no longer uses SDFS directory records or 8.3 names.

* `/` is the only native path separator. A leading `/` starts at the volume
  root; `.` and `..` have their usual meanings.
* A path component is 1 to 31 visible ASCII bytes. `/`, `*`, `?` and NUL are
  invalid in a stored component; `*` and `?` are reserved for glob patterns.
  Space is valid and is carried through the shell with quoting. Names preserve
  case and compare byte-for-byte.
* The resident path buffer is 128 bytes, including its NUL terminator. The
  maximum complete path is therefore 127 bytes; depth is limited by that
  length rather than by a separate nesting counter.
* Directory entries are fixed at 44 bytes. Fixed records avoid heap use,
  variable-record fragmentation and rename-time directory rewrites on a 6502.
* Extent lists, sparse reads, the allocation bitmap and dirty-volume recovery
  remain bounded and allocation-free. Directories use linear lookup for now,
  avoiding a second allocation and write for every directory mutation.

## 2. Why it is faster

* A file is usually one extent: reading it is consecutive sectors with no map
  sectors to read in between, and positioning (POINT) is arithmetic within
  the extent list (one list sector holds 63 extents on a 256-byte disk; an
  SDFS map sector covers 126 sectors).
* Writing grows the file's last extent when the sector after it is free, and
  allocation starts from the volume's next-free hint, so files stay
  contiguous, which multi-sector transfers (E2) can use.
* Large directories, being files, are contiguous too.

The extent layout adds its largest advantage on sequential files and repeated
seeks. Real-drive results include disk
rotation and transfer time, so they vary by drive, protocol, geometry, and
machine; the benchmark document records the test setup.

## 3. On the disk

### 3.1 Volume header (sector 1)

The revision byte at offset 32 is `$47` for a clean EOSFS v2 volume and `$48`
while changes may not all be on disk. Offsets 33-34 hold the sector size.

Before the first sector of a
volume is written after its header was last written clean, EOS writes
sector 1 with `$48`; when it flushes the volume it writes every other changed
sector first and the header, with `$47`, last. A volume mounted with `$48` (EOS
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

Directories are files containing 44-byte EOSFS entries, found through their
extent list.

### 3.3 Directory entries

| Offset | Size | Field |
| --- | ---: | --- |
| 0 | 1 | status/attributes |
| 1 | 2 | first extent-list sector; in a directory header, parent directory |
| 3 | 3 | byte length; in a directory header, directory-file length |
| 6 | 1 | name length, 1-31 |
| 7 | 31 | name bytes followed by zero padding |
| 38 | 6 | day, month, year, hour, minute, second |

The first record is the directory header and uses the same layout, including
its timestamp. The directory's own name also lives in its parent entry.

## 4. Implementation status

The v2 migration is deliberately staged so no checkpoint silently writes an
uncheckable format.

* Complete: the host builder/checker, v2 revision bytes, 44-byte records,
  31-byte exact-case names, 127-byte path validation and boot-image tests.
* Complete: page-6 buffers for two 32-byte components and a 128-byte path;
  the resident parser and resolver accept paths up to 127 bytes and use `/`.
* Complete: resident linear directory scanning, case-sensitive glob matching,
  create, rename, timestamps, directory growth and FORMAT output use v2 records.
* Complete: the resident mount accepts only EOSFS v2 revisions `$47`/`$48`.
* Complete: bank 7 now contains only EOSFS extent, mount, direct-transfer and
  dirty-header helpers. Its DOS2/MyDOS dispatch paths are unreachable, the v1
  directory-index code is not assembled, and their resident workspace has
  been removed. Foreign filesystems are no longer mount targets.
* Complete: the resident size gate requires `MEMLO <= $17C9`, under-ROM state
  through at most `$C7A7`; the current end is `$C798`, and the cache is fixed
  at `$C800`. Seven 512-byte cache
  slots remain. The 128-byte conditional continuation buffer occupies
  `$C718-$C797`; foreign-media features do not consume this space.
* Complete: transient Toolkit support. `fsinfo` detects, recursively lists,
  checks and imports DOS2/MyDOS and SDFS. `fsexport` performs explicit export
  with lossy-name/collision reporting, and `fscreate` explicitly creates the
  bounded 720x128 foreign profiles. None adds a resident parser or formatter.

`eos/fmsx.icl` remains the extent implementation: sector lookup, growing the
last extent, adding/chaining extent-list sectors, sparse reads and trimming.
`tools/sdfs.py` is currently the reference v2 image builder and checker.

* FORMAT writes EOSFS only, including the EOSFS boot loader. `BOOT file` records the
  file's first extent list in sector 1. Host images use
  `atr create --profile eos ... --boot file`; the loader is embedded in `atr`.
  It supports 128 and 256 byte sectors; the stock OS cannot boot 512 byte
  sectors.

EOSFS writes into the middle of a sparse gap by splitting the gap extent and
allocating only the sectors actually written. Reading gaps and writing past
the end (which makes a gap) are supported as well.

## 5. Later versions

* 24-bit sector numbers (volumes over 65535 sectors; XDCB devices).

## 6. Cache and transfer behavior

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
