# Rhino on Android

McNeel Rhino 8 (Windows, x86-64) running on an Android phone: Wine built for
ARM64EC with the [rhino-linux](https://github.com/Jabern/rhino-linux) patches,
[FEX](https://github.com/FEX-Emu/FEX) for the x86 code, Termux's glibc, and
Termux:X11 for the display. No root, no proot.

Experimental and unofficial: McNeel does not support Rhino on ARM or Android.

## Status (2026-10-31)

Tested on a Samsung Galaxy A24 (Helio G99, Mali-G57 MC2, 6 GB, Android 16).

- Rhino 8.36 installs and runs; sign-in and licensing work.
- Start to the Licensing window: about 40 s (first start of a new prefix longer).
- Viewport on the GPU through VirGL (OpenGL reported as 4.5); WPF panels in
  software. CPU drawing (llvmpipe) as fallback: `RHINO_GL=llvmpipe rhino`.
- Memory is the main limit: with 6 GB Android may close Termux under load.
  Close other apps; turn on "Disable child process restrictions" in
  Developer options.

## Install

Build the package (`package/`, see below) or take it from a release, copy it to
the phone and follow [package/README.txt](package/README.txt). In short:
GitHub Termux + Termux:X11, your own Rhino 8 installer from rhino3d.com in
Download/, then in Termux `sh install.sh`, and `rhino` to start.

## Layout

| Path | What |
|---|---|
| `termux/` | `rhino-android` (launcher: machine identity, .NET settings, install), `rhino` (display + start), `stack.sh` (dev: sshd, VNC) |
| `package/` | `install.sh` and README for end users; the runtime archive and APKs are added at release time |
| `patches/` | Wine patches 41-43 on top of rhino-linux 01-40 (Android machine identity and network, server dir without /tmp, X11 BadWindow) |
| `termux-glibc/` | `fetch-sysroot.py` (sysroot from Termux's glibc packages), `cc.sh` (cross compiler wrapper) |
| `shim/` | LD_PRELOAD shim for the earlier adb-shell/proot setup (abstract sockets, execmod) |
| `adb-proot/` | the first setup: Debian in proot driven from adb, Hangover, Xvfb |
| `bench/` | viewport benchmark (RhinoScript + runner) |
| `exception-hook/` | .NET startup hook that logs first-chance exceptions (Rhino's host ignores it) |
| `docs/` | `LOG.md` (lab log, all findings), `HANDOVER.md`, `arm-linux.md` |

## Building the runtime

1. Wine: `rhino-linux` source with patches 01-40, then `patches/` 41-43.
2. Sysroot: `termux-glibc/fetch-sysroot.py db pkgs sysroot <packages>` (see `docs/LOG.md`).
3. Configure with `CC=termux-glibc/cc.sh`, `CFLAGS="-O2 -DWINE_SERVER_DIR_IN_PREFIX"`,
   `--host=aarch64-linux-gnu --enable-archs=arm64ec,aarch64,i386`,
   `i386_CC=clang x86_64_CC=clang`, `--with-wine-tools=` a native build of the same tree.
4. Install with `--prefix=/data/data/com.termux/files/usr/glibc/opt/wine-rhino`, add
   FEX's `libarm64ecfex.dll` and `libwow64fex.dll` to `lib/wine/aarch64-windows/`,
   the glibc libraries from the sysroot, and Debian's `libxml2.so.2` (Termux's Mesa
   was built against it).

## License

Scripts: MIT. Wine patches: LGPL-2.1-or-later, like Wine.
