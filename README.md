# Outpost (Sierra, 1994) on Windows 10 / 11 — one-click launcher

Sierra's **Outpost** is a 16-bit Windows 3.1 game. 64-bit Windows has no 16-bit
subsystem, so double-clicking `OUTPOST.EXE` does nothing (or says *"This app
can't run on your PC"*), and compatibility mode doesn't help.

This launcher makes it a double-click again. It uses
[otvdm / winevdm](https://github.com/otya128/winevdm), a free, open-source
16-bit Windows layer for 64-bit Windows — no virtual machine, no Windows 3.1
install disks, no registry changes, no admin rights.

**You need your own copy of the Outpost CD** (the disc itself, or a BIN/CUE or
ISO image of it). No game files are included here — only the launcher.

## How to use

1. Download this repository (green **Code** button → **Download ZIP**) and unzip
   it somewhere permanent, e.g. `C:\Games\Outpost`.
2. Put your Outpost CD in the drive, or make sure the CD image (`Outpost.bin`
   or `Outpost.iso`) is in that folder, your Downloads, or your Desktop.
3. Double-click **`Play Outpost.bat`**.

The first run does everything else, then never again:

- downloads otvdm (about 10 MB) into an `otvdm` subfolder;
- finds your CD image (asks you to pick it if it can't), converts a BIN/CUE rip
  to a plain ISO if needed, and mounts it;
- unpacks the game itself from the CD's installer archive `RESOURCE.000` —
  including the five DLL/DRV files the original installer scattered into
  `C:\WINDOWS`, which is why half-copied installs never work;
- copies the `BITMAPS`, `VIDEOS` and `MUSIC` folders (about 270 MB) and the
  manual PDF, so the disc is never needed again.

After that, `Play Outpost.bat` starts straight into the game.

## Screen size

Outpost draws itself at 1994 pixel sizes, so on a modern monitor it is tiny.
The launcher therefore switches your monitor to a lower resolution while the
game runs and switches it back when you close the game. Edit the two numbers
near the top of `Play Outpost.bat` to taste:

```bat
set GAME_WIDTH=1280
set GAME_HEIGHT=720
```

| Setting      | Effect                                        |
|--------------|-----------------------------------------------|
| `1280` `720` | 1.5× bigger, keeps widescreen shape (default) |
| `1024` `768` | about 2× bigger, 4:3 shape                    |
| `800` `600`  | about 2.4× bigger — basically 1994            |
| `0` `0`      | leave the screen alone                        |

If anything ever leaves your screen at the low resolution (a crash, Task
Manager), double-click **`Fix my screen.bat`**.

## Troubleshooting

- **"VCRUNTIME140.dll is missing"** — install the Microsoft Visual C++
  Redistributable, 32-bit (x86): <https://aka.ms/vs/17/release/vc_redist.x86.exe>
- **"Windows protected your PC"** — click *More info* → *Run anyway*. otvdm is
  open source and widely used but not code-signed.
- **Intro movie / animations error out or show black** — open `OUTPOST.INI` in
  Notepad and change `movies=on` to `movies=off` (and if needed `anims=on` to
  `anims=off`). Outpost plays its FLC movies through a 16-bit Autodesk Animator
  MCI driver (`MCIAAP.DRV`), the piece most likely to misbehave under otvdm.
  The game itself is unaffected.
- **The automatic otvdm download fails** (no internet, antivirus) — download
  `otvdm-vX.X.X.zip` from <https://github.com/otya128/winevdm/releases> and
  unzip it so you have `Outpost\otvdm\otvdm.exe`.
- **Setup can't find or mount the CD image** — do it by hand: mount the image
  (Windows can mount `.iso` files directly; for BIN/CUE use a tool such as
  [WinCDEmu](https://wincdemu.sysprogs.org/) or convert it with
  [IsoBuster](https://www.isobuster.com/)), copy `BITMAPS`, `VIDEOS`, `MUSIC`
  and `RESOURCE.000` into the launcher folder, and run `Play Outpost.bat` again
  (it will unpack `RESOURCE.000` for you if `OUTPOST.EXE` is missing).
- **Still stuck?** The always-works fallback is a real Windows 3.1 inside
  [DOSBox-X](https://dosbox-x.com) or [86Box](https://86box.net) — more setup,
  but 100 % authentic.

## What the files are

| File | Purpose |
|------|---------|
| `Play Outpost.bat` | The launcher. Double-click this. |
| `Fix my screen.bat` | Restores your normal resolution if a crash left it small. |
| `run-game.ps1` | Helper: lowers the resolution, runs the game through otvdm, waits, restores. Runs hidden. |
| `setup-cd-data.ps1` | Helper: first-run CD image handling and `RESOURCE.000` unpacking. |

You never run the `.ps1` files yourself. Each launch, the launcher rewrites the
`opimage=` line in `OUTPOST.INI` to point at the folder's current location, so
you can move the folder freely.

## Technical notes, for the curious

- `RESOURCE.000` is Sierra's Windows-installer archive: a `DISK01` header,
  26-byte directory entries, then each file compressed with PKWARE's DCL
  "implode". The decompressor in `setup-cd-data.ps1` is a port of zlib's
  `contrib/blast.c`.
- A BIN/CUE rip of the disc is MODE1/2352 raw sectors plus a CD-audio track;
  the ISO conversion strips the 16-byte sync/header and 288-byte ECC from each
  sector and stops at the end of the data track.
- The installer also added `[mci] Autodesk=mciaap.drv` to `system.ini` and
  `flc=Autodesk` to `win.ini`. otvdm routes MCI to the 32-bit `winmm`, where no
  Autodesk Animator driver exists — hence the `movies=off` advice above.
- The game writes `rez=<width>,<height>` and `[windows]` panel positions to
  `OUTPOST.INI` itself; `rez` records the screen size rather than setting it.

## Credits

- Outpost © 1994 Sierra On-Line. This repository contains no game files.
- [otvdm / winevdm](https://github.com/otya128/winevdm) by otya128 and
  contributors, based on Wine.
- Launcher scripts: MIT License (see `LICENSE`).
