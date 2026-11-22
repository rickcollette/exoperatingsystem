# VIM/TAR physical-hardware acceptance

This card is the final external release check. The automated equivalent runs
on a 64K Altirra 800XL in `vim-interactive` and `tar-native`; this card must be
performed by a person with a physical Atari because the repository workspace
cannot press a real keyboard or observe a real disk interface.

Record the Atari model, RAM size, keyboard type, video standard, storage
interface, EOS build/commit, and date. Start with BASIC disabled and no memory
expansion enabled; `MEM` must report a 64K configuration.

## VIM keyboard card

1. Create LF, CRLF and ATASCII files containing mixed case, a tab, a 255-byte
   line and at least 30 lines. Keep copies for byte comparison.
2. Open each with `vim file`. Confirm 22 editing rows, readable tabs, exact
   filename case, `gg`, `G`, arrows, `0`, `$`, `/pattern`, wrapped `n`, and
   vertical/horizontal scrolling.
3. Exercise `i`, `a`, `o`, Backspace, Return, `x`, `dd`, `yy`, `p`, and `u`.
   Confirm one `u` restores each operation and a continuous multiline INSERT
   session. Confirm Escape reliably returns to NORMAL on the physical key.
4. Try to add byte 256 to the full line. Confirm `Buffer full`, no data change,
   and continued editing.
5. Run `:e` on a NUL-containing file, a mixed-newline file, a 256-byte-line
   file, and a missing file. Confirm the current text and filename survive.
6. Run `:w` on an existing file; answer N, then repeat and answer Y. Confirm
   cancellation keeps the changed marker and Y writes the expected bytes.
7. Fill a scratch disk, provoke a write failure, and confirm an error is shown,
   VIM remains usable, and the changed marker remains set. Exit with `:q!`.
8. Byte-compare the successful LF, CRLF and ATASCII saves with their expected
   newline styles. Confirm a new file uses LF.

## TAR card

1. Archive a two-level directory tree containing mixed-case text and binary
   files. List it, extract it on a modern computer, and compare every byte.
2. Create USTAR and V7 archives on the modern computer, including directory
   entries and a known timestamp. Extract on EOSFS and verify tree, bytes and
   timestamp with `ls -l`/`stat`.
3. Attempt extraction over an existing file. Confirm TAR reports and preserves
   it. Confirm an existing directory is explicitly reused.
4. Try archives containing `/absolute`, `../parent`, a bad checksum and a
   truncated data block. Confirm each is rejected and no unsafe file appears.

Sign-off is complete only when all observations pass and the recorded hardware
details are added below or to the release record.

Physical result: **not run in the repository environment**.
