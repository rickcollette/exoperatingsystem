#!/usr/bin/env python3
"""EOS in the Atari800 emulator: startup and everyday runtime behavior.

usage: atari800_smoke.py [case ...]     (default: all)

Each case boots build/EOS.car with one SDFS disk in D1:. EOS runs
EOSAUTO.BAT from it; the batch writes its results to files (output
redirection), and the host checks the disk after the emulator is stopped:

  xl      800XL, 64K, NTSC: COPY and TYPE (also checked on screen by OCR),
          MKDIR and a copy into the directory, DIR, a relocatable program
          (HELLO.COM with parameters), a CAR: file; then a warm reset (F5)
          and a typed command whose output must reach the disk
  xe      130XE (128K): the same batch with EOS using the extra memory
  pal     800XL in PAL mode: the same batch
  rambo   320K (Rambo XL): the same batch

Requires Atari800 (its built-in AltirraOS is enough), xdotool, ImageMagick
and Tesseract. ATARI800_EXE selects the executable.
"""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import emu  # noqa: E402
import sdfs  # noqa: E402

ATARI800 = os.environ.get("ATARI800_EXE", "atari800")
TIMEOUT = int(os.environ.get("ATARI800_TIMEOUT", "60"))
PAYLOAD = b"EOS800WRITEPASS\x9bfilesystem write and readback\x9b"
CASES = {
    "xl": ["-xl"],
    "xe": ["-xe"],
    "pal": ["-xl", "-pal"],
    "rambo": ["-rambo"],
}
BATCH = [
    "COPY WRITE.IN WRITE.OUT",
    "MKDIR SUB",
    "COPY WRITE.IN SUB>COPY.OUT",
    "HELLO ONE TWO >>HELLO.TXT",
    "DIR SUB> >>DIR.TXT",
    "TYPE CAR:ALIASES.INI >>CAR.TXT",
    "MEM >>MEM.TXT",
    "ECHO DONE >>DONE.TXT",
    "TYPE WRITE.OUT",
]


def ensure_display():
    if not os.environ.get("DISPLAY"):
        xvfb = shutil.which("xvfb-run")
        if not xvfb:
            sys.exit("atari800_smoke: xvfb-run required when DISPLAY is unset")
        os.execvp(xvfb, [xvfb, "-a", "-s", "-screen 0 1024x768x24",
                         sys.executable, *sys.argv])


def screen_text(wid, out):
    raw = out / "screen.png"
    big = out / "screen-big.png"
    subprocess.run(["import", "-window", wid, str(raw)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["convert", str(raw), "-crop", "320x192+8+24", "+repage",
                    "-resize", "800%", "-threshold", "40%", str(big)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    p = subprocess.run(["tesseract", str(big), "stdout", "--psm", "6"], check=True,
                       capture_output=True, text=True)
    return p.stdout


def files_on(atr):
    vol = sdfs.Volume(str(atr))
    entries = vol.check()
    return vol.errors, {name: entry.get("data") for name, entry in entries}


def window(proc):
    found = subprocess.run(["xdotool", "search", "--onlyvisible", "--name",
                            "Atari 800 Emulator"], capture_output=True, text=True)
    ids = found.stdout.splitlines()
    return ids[-1] if ids else None


def wait_file(atr, name, proc, deadline):
    """Poll the disk image until name exists (the emulator writes in place)."""
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            return False
        try:
            errors, files = files_on(atr)
            if not errors and name in files:
                return True
        except Exception:      # (a half-written sector while polling)
            pass
        time.sleep(1)
    return False


def run_case(name, machine, exe, cart, hello):
    with tempfile.TemporaryDirectory(prefix="eos-atari800-", dir=ROOT / "build") as tmp:
        out = Path(tmp)
        tree = out / "tree"
        tree.mkdir()
        (tree / "WRITE.IN").write_bytes(PAYLOAD)
        (tree / "HELLO.COM").write_bytes(hello)
        (tree / "EOSAUTO.BAT").write_bytes(emu.atascii(BATCH))
        atr = out / "smoke.atr"
        emu.mkatr(atr, tree, ["EOSAUTO.BAT", "WRITE.IN", "HELLO.COM"], 184320)
        log = open(out / "atari800.log", "wb")
        cmd = [exe, *machine, "-nobasic", "-cart", str(cart), str(atr)]
        proc = subprocess.Popen(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                start_new_session=True)
        e = []
        try:
            deadline = time.monotonic() + TIMEOUT
            if not wait_file(atr, "/DONE.TXT", proc, deadline):
                log.flush()
                tail = (out / "atari800.log").read_text(errors="replace")[-600:]
                return ["startup batch did not finish (no DONE.TXT)\n" + tail]
            time.sleep(2)
            wid = window(proc)
            text = screen_text(wid, out) if wid else ""
            if "WRITEPASS" not in text:
                e.append("TYPE WRITE.OUT not seen on screen (OCR: %r)" % text[-120:])
            if name == "xl" and wid:
                # warm reset, then a command typed at the prompt
                # (SDL takes XTEST input for the focused window only)
                subprocess.run(["xdotool", "windowfocus", "--sync", wid], capture_output=True)
                subprocess.run(["xdotool", "key", "F5"], capture_output=True)
                time.sleep(4)
                subprocess.run(["import", "-window", wid, str(ROOT / "build" / "atari800-reset.png")],
                               capture_output=True)
                for ch in "ECHO RESET OK >>RESETOK":   # (no period: Atari800 drops it)
                    subprocess.run(["xdotool", "type", ch], capture_output=True)
                    time.sleep(0.12)
                subprocess.run(["xdotool", "key", "Return"], capture_output=True)
                time.sleep(3)
                subprocess.run(["import", "-window", wid, str(ROOT / "build" / "atari800-typed.png")],
                               capture_output=True)
                if not wait_file(atr, "/RESETOK", proc, time.monotonic() + 30):
                    e.append("no RESETOK after the warm reset and a typed command")
        finally:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            proc.wait(timeout=5)
            log.close()
        shutil.copyfile(atr, ROOT / "build" / ("atari800-%s.atr" % name))   # (for a look)
        errors, files = files_on(atr)
        txt = lambda n: emu.text(files.get(n) or b"")
        if errors:
            e.append("file system check: " + "; ".join(errors[:3]))
        if files.get("/WRITE.OUT") != PAYLOAD:
            e.append("WRITE.OUT differs")
        if files.get("/SUB/COPY.OUT") != PAYLOAD:
            e.append("SUB>COPY.OUT differs")
        if "HI" not in txt("/HELLO.TXT") or "ONE" not in txt("/HELLO.TXT") or \
                "TWO" not in txt("/HELLO.TXT"):
            e.append("HELLO.COM output %r" % txt("/HELLO.TXT"))
        if "COPY" not in txt("/DIR.TXT"):
            e.append("DIR SUB output %r" % txt("/DIR.TXT")[:80])
        if "XCOPY=COPY /R" not in txt("/CAR.TXT"):
            e.append("CAR:ALIASES.INI output %r" % txt("/CAR.TXT")[:80])
        if not txt("/MEM.TXT").strip():
            e.append("no MEM output")
        if name == "xl" and "RESET OK" not in txt("/RESETOK") and \
                not any("RESET" in x for x in e):
            e.append("RESETOK %r" % txt("/RESETOK"))
        (ROOT / "build" / ("atari800-%s-mem.txt" % name)).write_text(txt("/MEM.TXT"))
        return e


def main():
    ensure_display()
    exe = shutil.which(ATARI800) if os.path.sep not in ATARI800 else ATARI800
    if not exe or not Path(exe).exists():
        sys.exit("atari800_smoke: Atari800 not found (set ATARI800_EXE)")
    for name in ("xdotool", "import", "convert", "tesseract"):
        if not shutil.which(name):
            sys.exit("atari800_smoke: missing tool: " + name)
    cart = ROOT / "build/EOS.car"
    hello = ROOT / "build/eos/HELLO.COM"
    if not cart.exists() or not hello.exists():
        sys.exit("atari800_smoke: build/EOS.car or build/eos/HELLO.COM missing; run make eos")
    failed = 0
    for name in sys.argv[1:] or list(CASES):
        e = run_case(name, CASES[name], exe, cart, hello.read_bytes())
        what = ("boot, batch file, COPY/TYPE, MKDIR and subdirectory copy, DIR, HELLO.COM, "
                "CAR: read, MEM" + (", warm reset and a typed command" if name == "xl" else ""))
        print("atari800 %-6s %s  %s" % (name, "FAIL" if e else "PASS", "; ".join(e) or what),
              flush=True)
        failed += bool(e)
    return 1 if failed else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        sys.exit(f"atari800_smoke: {exc}")
