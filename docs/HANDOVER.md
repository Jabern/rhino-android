# Rhino on ARM / Android: handover (2026-10-31)

Experimental work, kept outside the `rhino-linux` repository on purpose.

## Wine source: what changed and where

All ARM/Android Wine changes are on branch **`dev/arm64ec`** in
`~/src/rhino-linux/wine-src`, checked out as a separate worktree at
**`~/src/rhino-arm/wine-src`**. Same changes as patches in `patches/`.

`dev/perf-startup` (patches 36-40, the Linux work) is untouched: still at
`ea59f4e9`, clean working tree. `dev/arm64ec` = `dev/perf-startup` + 3 commits.

These edits were first made directly in the shared tree (uncommitted, on
`dev/perf-startup`) during the phone experiments. That was a mistake. They
were moved to `dev/arm64ec` the same day; nothing was pushed or released.

| Patch | Files | Effect on regular x86-64 Linux builds |
|---|---|---|
| 41 winex11: ignore BadWindow on Map/UnmapWindow | `dlls/winex11.drv/x11drv_main.c` | **Active.** A BadWindow from mapping/unmapping a window another process already destroyed no longer kills the process (upstream ignores the same error for focus/configure/SendEvent). Needs normal review before it goes into the Linux patch set. |
| 42 server dir in prefix (`WINE_SERVER_DIR_IN_PREFIX`) | `dlls/ntdll/unix/server.c`, `server/request.c` | None unless built with `-DWINE_SERVER_DIR_IN_PREFIX` (only the Termux build). |
| 43 machine/network when Android hides them | `dlls/ntdll/unix/system.c`, `dlls/nsiproxy.sys/{ndis,ip,tcp}.c`, `unix_private.h` | None in practice: every fallback runs only when the Linux call fails with EACCES/EPERM, the file is missing, or `WINE_DMI_DIR` is set (only `rhino-android` sets it). |

Why 43 exists: Android has no DMI, no dbus machine-id, and apps may not use
SIOCGIFHWADDR, netlink (`if_nameindex`, `getifaddrs`) or `/proc/net`. Wine then
reported an empty system UUID, empty serials and no network adapters, and
Rhino's licensing failed with "Object reference not set to an instance of an
object" after sign-in.

## Builds (all on the PC)

| Dir | Target | Notes |
|---|---|---|
| `build-wine-arm64` | aarch64 + ARM64EC, Debian 13 sysroot (`sysroot-trixie-arm64`) | for the proot setup |
| `build-wine-termux` | same, against Termux's glibc (`~/src/rhino-android/termux-glibc`) | runs in Termux without proot; `CC=termux-glibc/cc.sh`, `CFLAGS=-O2 -DWINE_SERVER_DIR_IN_PREFIX` |

Both were configured against `../../rhino-linux/wine-src`. **Reconfigure them
against `../wine-src` (the worktree) before the next build**, otherwise they
build `dev/perf-startup` without patches 41-43. Configure lines: see
`configure.out` / `config.log` head in each build dir. Wine tools come from
`~/src/rhino-linux/build-wine` (`--with-wine-tools`). PE side: clang for
arm64ec/aarch64/i386/x86_64 (`i386_CC=clang x86_64_CC=clang`). FEX DLLs
(`libarm64ecfex.dll`, `libwow64fex.dll`) come from Hangover 11.16 and are
selected through `HKLM\Software\Microsoft\Wow64\{amd64,x86}`.

## Phone (Galaxy A24, Mali-G57, Android 16, no root)

See `~/src/rhino-android/README.md` for the full log. Current setup: GitHub
Termux, runtime `dist/rhino-android-termux.tar.zst` unpacked into `$PREFIX`,
launcher `rhino-android`, Termux:X11 + Openbox + x11vnc (adb forward 5900),
SSH into Termux over adb forward 8022 (dev key in the session scratchpad; to
remove: `pkill sshd` and drop the `rhino-android-dev` line from
`~/.ssh/authorized_keys`). Older proot/Debian setup: `/data/local/tmp/rhino`.
