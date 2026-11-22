# EOS Linux-like conversion checklist

This is the live completion checklist for `TooLinux.md`. An item is checked
only after its implementation and focused validation pass. Measurements and
known limitations belong beside the item, not in an implicit compatibility
fallback.

## 1. Native EOSFS v2

- [x] Exact-case 1–31 byte names and distinct case twins.
- [x] Native `/` paths with a 127-byte complete-path limit.
- [x] Fixed 44-byte directory records and linear directory lookup.
- [x] Extent lists, sparse reads, append/growth, trimming and dirty recovery.
- [x] EOSFS-only resident mount; reject DOS2/MyDOS/SDFS as mount targets.
- [x] Remove resident DOS2/MyDOS dispatch and v1 name-index state.
- [x] FORMAT, boot loader and host builder/checker produce EOSFS v2.
- [x] Seven-slot cache and memory measurements documented (`MEMLO=$17C9`).
- [x] Permit spaces in EOSFS names; quoted create/redirection, cat, cp, mv,
  rename, read and removal pass end-to-end.
- [x] Write into the middle of an existing sparse gap; split the gap extent
  without allocating its zero-filled neighbors (`sparse-gap`).
- [x] Remove excluded legacy DOS2/MyDOS source and rename bank 7/source as
  EOSFS (`eosx.asm`, `eosx.icl`).
- [x] Remove unreachable resident linked-sector NOTE/POINT, SDFS map-free and
  map-trim paths and the redundant 15-byte per-drive filesystem-kind array;
  enforce resident ceilings in `resident-size`.

## 2. Shell and argument API

- [x] Lowercase keyboard/default cartridge filenames.
- [x] Exact-case external command lookup with no uppercase retry.
- [x] Move command-name scratch out of the 128-byte shell workspace.
- [x] Add fixed 16-entry `U_ARGC`/`U_ARGV` sidecar.
- [x] Single quotes, double quotes, empty quoted words and backslash escapes.
- [x] Quote-aware pipe and redirection operator scanning.
- [x] `<`, `>`, `>>`; retain `<<` as an input alias.
- [x] Read interactive, batch, pipe and `XCOMLI` lines up to 127 bytes;
  maximum-line and long-stage emulator tests pass.
- [x] Make built-ins consume parsed argv rather than reparsing COMTAB `LBUF`;
  filesystem built-ins and echo have focused quoted/spaced-name coverage.
- [x] Preserve the legacy 64-byte line and return error 182 instead of
  silently truncating programs that do not import `U_ARGV`.
- [x] Complete `$NAME`, `${NAME}`, `$?`, `$1`–`$9` expansion semantics.
- [x] Implement `&&` and `||` with last-stage pipeline status.
- [x] Prove cleanup after parse, load, command and `$TEMP`-full failures;
  `pipe-cleanup` inspects the resulting EOSFS images for leaked temporaries.
- [x] Always bracket the prompt and include the active native drive/path by
  default (`[D1:/]`, `[D1:/rick/]`); make `pwd` report only that active path.
- [x] Enable Up/Down command history by default using four compact 63-byte
  entries; live keyboard recall passes while reserving only 257 bytes.
- [x] Use the compact boot banner `EOS v<VERSION> (c)2026 Rick Collette` on
  cold boot and reset, sourced from the repository `VERSION` file.
- [x] Report immediately usable main RAM in bytes and convert free 16K banks
  to bytes in plain `mem` output; validate both 64K and 320K configurations.

## 3. Core command environment

- [x] Put `ls cat head tail wc grep which basename dirname touch stat du` on
  `CAR:` as transient programs.
- [x] Provide `cp rm cat clear` built-in spellings and `cmp` on `CAR:`.
- [x] Provide/verify `mv mkdir rmdir pwd df cd man less more echo` frontends.
- [x] Convert native core utilities to the native argv contract; `cp`, `mv`
  and the shared Unix filter parser consume `U_ARGV` directly.
- [x] Common grouped-short-option parser with option arguments and `--`.
- [x] Common `--help` behavior without per-program long-option bloat; focused
  `cat`, `head` and `tail` emulator probes return each command's usage.
- [x] Audit stdin/stdout, bounded memory, exact case and error propagation;
  the EOSFS-native core matrix covers streaming filters and long/spaced names.
- [x] Use the shared nonresident `TOLOWER` helper only for command/option
  tokens; native filenames stay exact and are never normalized.
- [x] Store exact length-tagged names in `CAR:` and omit legacy cartridge
  utilities that decode or mutate SDFS-era directory records.
- [x] Replace cartridge ED/ARC with compact modal VIM and streaming POSIX
  USTAR TAR; retain legacy ED/ARC programs and manuals on the Toolkit disk.
- [x] VIM: fixed 22-row viewport, 255-byte lines, tabs, wrapped search,
  scrolling, case-preserving names and complete normal-command coverage.
- [x] VIM: transactional ASCII/ATASCII LF/CRLF validation, non-destructive
  failed `:e`, overwrite confirmation and checked write/close failures.
- [x] VIM: one-level bounded undo for byte edits, newline joins, `dd`, `p`,
  `o`, and continuous multiline INSERT sessions.
- [x] VIM: automated live-keyboard 64K Altirra acceptance, including line
  limit/full refusal and measured text-capacity boundary.
- [x] TAR: recursive directory create/extract, explicit collision refusal,
  V7 input, EOSFS/Unix timestamp conversion and unsafe/malformed regressions.
- [ ] Run the documented VIM keyboard card on a physical 64K Atari and record
  machine/keyboard/disk-handler details (`docs/HARDWARE_ACCEPTANCE.md`). This
  cannot be executed by the repository test environment.

## 4. Foreign filesystem Toolkit

- [x] Raw block access without mounting a foreign filesystem.
- [x] Detect EOSFS, SDFS, Atari DOS 2 and MyDOS (`fsinfo`).
- [x] List live DOS2/MyDOS root entries read-only.
- [x] Recursive DOS2/MyDOS listing through a bounded 16-level transient walk.
- [x] DOS2/MyDOS structural check with bounded ownership, chain-count,
  range, loop and cross-link validation.
- [x] SDFS recursive listing through transient sector-map traversal.
- [x] SDFS structural check with map backlink, range, loop and cross-link
  validation.
- [x] Import files/directories from DOS2/MyDOS and SDFS into EOSFS with
  exact destination collision reporting and refusal.
- [x] Explicit DOS2/MyDOS and SDFS export/create through separate transient
  `fsexport` and `fscreate` commands; creation is deliberately limited to the
  unambiguous 720 x 128-byte profile.
- [x] Report destination collisions and every lossy uppercase/8.3 mapping
  before writing; exact collisions leave the foreign image byte-for-byte
  unchanged.
- [x] Malformed-image, geometry, loop, cross-link and write-refusal tests;
  unsupported geometry is refused without changing the image.

## 5. Documentation and validation

- [x] Replace `TooLinux.md` with the executable conversion plan.
- [x] Document EOSFS v2 layout, memory boundary and current cache count.
- [x] Document initial quoting, argv API and POSIX redirection.
- [x] Convert remaining active help/examples from `>` and uppercase defaults.
- [x] Document completed shell grammar, statuses and non-goals.
- [x] Update native emulator fixtures for exact case, `/`, v2 and new redirects;
  retain SDX/SDFS record probes only as an archived compatibility matrix.
- [x] Host builder/checker/unit tests pass (17 tests).
- [x] Focused shell/core/foreign tests pass.
- [x] Full EOSFS-native EOS and Toolkit matrices pass; CAR lookup, exact-name
  listing and manual-page smoke tests are part of the native matrix.
- [x] Boot passes at 64K, 128K and 320K with final measurements recorded.
- [x] Regenerate and review the combined handbook.

## Current measurements

- MEMLO: `$17C9` after replacing CAR's two 11-byte 8.3 pattern buffers with
  one 17-byte exact-name glob buffer (five resident bytes recovered).
- Interactive 64K boot MEMLO: `$18CA` after the default four-entry command
  history reserves 257 bytes; this remains below the `$18FF` acceptance gate.
- Filesystem plus shell under-ROM state ends at `$C798`; `$C718-$C797` is
  the fixed 128-byte `&&`/`||` continuation and the cache still starts at
  `$C800`.
- Primary cache: seven 512-byte slots.
- Extended-memory second-level cache: 31 sectors when a bank is available.
- CAR filesystem: 127 files, 15 banks with standard TAR and modal VIM replacing
  the legacy ARC/ED cartridge slots; ARC and ED remain transient Toolkit tools.
- Toolkit: 53 transient programs after adding `fsinfo`, `fscreate`,
  `fsexport`, `cp` and `mv`.
