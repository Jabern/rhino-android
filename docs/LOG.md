# Rhino on Android

Goal: Rhino on an Android phone or tablet, ideally with a mouse and keyboard
or a desktop mode (Samsung DeX and similar).

This builds on [ARM Linux notes](arm-linux.md): the same ARM64EC Wine +
FEX runtime, with patches 01-40, run inside an Android app.

## How it fits together

```
Android app (container launcher, X server, input)
 └─ glibc userland (proot / chroot) or bionic Wine build
     └─ Wine ARM64EC + FEX         <- rhino-arm runtime
         ├─ Rhino.exe (x86-64, emulated)
         ├─ DXVK -> Vulkan -> Turnip (Mesa, Adreno)
         └─ OpenGL -> Zink -> Turnip   (Rhino viewport)
```

## Plan

### Phase 1: runtime package for existing launchers

Don't write an APK first. Winlator-family launchers (Winlator, its Ludashi /
Bionic / Cmod forks) already provide containers, an X server, Turnip,
FEXCore and Box64. Many accept custom Wine packages. We ship our patched
ARM64EC Wine as such a package, plus a deploy script that installs Rhino in
the container (vcrun2022, fonts, registry from `tools/`).

This shows whether Rhino can be used on a phone at all.

### Phase 2: our own app (only if Phase 1 shows it is worth it)

A dedicated APK: one prefix per Rhino version, our launcher logic
(`tools/rhino-linux`, `rhino-versions.sh`), and input handling built for
Rhino (right-drag rotate, middle-drag pan, pinch zoom mapped to
Rhino's viewport gestures).

## Known blockers

| Issue | Why it matters |
|---|---|
| **GPU** | Adreno + Turnip is the only good path: Vulkan for DXVK and Zink for Rhino's OpenGL 4.x viewport. Mali (panvk) and PowerVR are much weaker. Target Adreno 7xx/8xx first. |
| **Zink history** | On NVIDIA, Zink hit Xid 109 and lost its device (why v1.4.2 went back to native GL). On Turnip it is the only desktop GL available, so it has to work there. |
| **16K pages** | Some Android 15+ devices use 16K pages. The community ARM64EC builds ship separate 16K variants; we need to as well. |
| **Memory** | Rhino 8 + Wine + FEX needs several GB. Android's low-memory killer and the phantom process killer (Android 12+) can kill the container. Needs 8 GB+ devices plus testing. |
| **Input** | Rhino needs a mouse. Touch only works for viewing. |
| **Windowing** | Our X11 patches (23-35) assume a real X server with a WM. The launcher's X server behaves differently: frame extents, popups and maximize need checking. |
| **WebView2 / Rhino 9** | Same as ARM, but worse on a phone. Target Rhino 8 first. |

## Test device: Samsung Galaxy A24 (SM-A245F)

Android 16, not rooted, Termux + Termux:X11.

- CPU: MediaTek Helio G99 (MT6789), 2x Cortex-A76 + 6x Cortex-A55. ARMv8.2
  with LSE atomics, which FEX runs well on. Only two fast cores.
- GPU: Mali-G57 MC2 on Samsung's own driver. That gives GLES 3.2 and Vulkan,
  but no desktop OpenGL, and no Turnip because it isn't an Adreno.
  Stock kernel uses Mali kbase, not panfrost, so Mesa panfrost/panvk can't be
  used without root.
- Measured over adb (2026-10-31): kernel 6.12 GKI, 4K pages, 5.8 GB RAM
  (~1.8 GB free) + 8 GB zram. CPU flags include atomics and lrcpc.
  Mali driver r54p1, Vulkan 1.3.303, but no `shaderClipDistance`,
  `shaderCullDistance`, `fillModeNonSolid`, `multiViewport`, `shaderFloat64`,
  `textureCompressionBC` or `VK_EXT_vertex_attribute_divisor`. DXVK needs these
  features, so it won't start: WPF goes through wined3d. Zink can't offer
  GL 4.x without fp64.
- Working without root from `adb shell` (uid shell) in `/data/local/tmp`:
  Termux's proot (+ libtalloc, libandroid-shmem) with a Debian 13 arm64 rootfs.
  Android blocks hard links for the shell user, so proot needs `-l`.
  Android's own `/system/bin` programs can't be run under proot (EPERM), but
  Debian's programs can.
- OpenGL for Rhino's viewport, in order of what to try:
  1. llvmpipe (Mesa on the CPU): GL 4.5, always works, slow.
  2. VirGL over the GLES driver: faster, but GL version and stability vary.
  3. Zink on the Mali Vulkan driver: least likely to work.
- Process killer: turn on "Disable child process restrictions" in
  Developer options, otherwise Android 16 kills Wine's child processes.

This phone is a test for whether Rhino starts. It's too slow for daily use.

## Phase 0 log (2026-10-31, Galaxy A24, driven from the PC over adb)

Stack: adb shell (uid shell) -> Termux proot -> Debian 13 arm64 -> Hangover
11.16 (upstream Wine 11.16 ARM64EC + FEX) -> Xvfb + Mesa llvmpipe. Scripts in
`../adb-proot/`, everything on the phone lives in `/data/local/tmp/rhino`.

The adb shell's SELinux domain blocks two things Wine needs, worked around
by `../shim/abstract-sockets.c` (LD_PRELOAD, see `adb-proot/wenv`):

1. **No socket or FIFO files** anywhere, only abstract sockets. wineserver's
   `bind` fails. The shim moves path sockets to abstract names and leaves a
   regular marker file that `lstat` reports as a socket (ntdll checks it
   before connecting).
2. **No `execmod`**: file-backed pages that were written (PE relocations)
   can't be made executable ("noexec filesystem?" and a stack overflow at
   the first thread). Anonymous executable memory is allowed, so the shim
   moves such ranges into anonymous memory before `mprotect`.

Inside the Termux app (untrusted_app domain) both may behave differently.
Check there before keeping these as Wine patches.

Results so far:
- `wineboot -i`: ~100 s, FEX runs 32-bit and 64-bit x86 code.
- `glfps.exe` (x86-64, OpenGL): 157 fps on llvmpipe, GL 4.5 compatibility
  profile. x86-64 + FEX + OpenGL work.
- Wine Mono 11.3.0 was not taken from `~/.cache/wine` (Wine asked to
  download it; clicked Install with xdotool). Gecko x86_64 installed fine.
- Rhino 8.36 bundle (`/passive`): VC 2013/2022, WebView2, .NET 10 Desktop
  and ASP.NET runtimes all install (~7 min). `rhino.msi` then fails 0x643:
  the native DLL custom action `IsRhinoInstalled` (MsiInstUtil) returns 1
  but never sets `RHINO_80_INSTALLED`, so the "newer build is already
  installed" launch condition fails. On x86-64 it sets it to 0.
  Workaround: `adb-proot/install-rhino-msi.sh` runs `rhino.msi` directly
  with the properties those custom actions set (~8 min, rc 0).
  Root cause to find: MSI custom action server (MsiSetProperty over RPC)
  under ARM64EC/FEX.
- First Rhino start crashed in .NET (0xC0000005 in a thread pool worker):
  W^X double mapping vs the shim's execmod copy. With the launcher's .NET
  settings (`DOTNET_EnableWriteXorExecute=0` etc., see `run-rhino.sh`),
  **Rhino 8 SR36 reaches the splash screen and Licensing window in ~10 min**
  (Rhino.exe ~465 MB RSS).
- Display: Termux:X11 started from adb (`app_process` + the app's APK,
  `TMPDIR=/tmp` so its abstract socket is `@/tmp/.X11-unix/X0`, XKB data
  from the Debian rootfs), forced to 1920x1080 landscape via the
  `com.termux.x11.CHANGE_PREFERENCE` broadcast. x11vnc mirrors `:0` on the
  phone's localhost, `adb forward tcp:5900` brings it to the PC
  (`gvncviewer localhost:0`). Same Rhino on both screens.
  `adb-proot/start-phone.sh` brings everything up (`stop` tears it down).
- Second start (warm caches): Licensing window in **76 s** (first: ~10 min).
  Sign-in redirects to `127.0.0.1:1717`; also forwarded so a PC browser works.
- After sign-in (token saved in `cloudzoo.json`, 2 MiB padded as on x86):
  "An unexpected error occurred. Object reference not set to an instance
  of an object." on every start, then Rhino quits and crashes on the way
  out (Dictionary race in `PlugInSettings.DetachWatchers`, or CLR assert
  "managed code after thread state destroyed").
  - Our x86-64 `ncrypt.dll` (patch 15) and `wbemprox.dll` (patch 12), with
    the builtin marker cleared and loaded native under FEX: loads fine
    (`+loaddll` shows ncrypt native), error unchanged.
  - Patch 13 (server, licensing in Session 0) can't be dropped in.
  - `DOTNET_STARTUP_HOOKS` (exception-hook/) is ignored by Rhino's .NET host.
  - `wenv` used to force `WINEDEBUG=-all`; fixed, debug runs before that
    printed nothing.

## Support

McNeel does not support Rhino on ARM. This is a community port, like
the Linux one.

## Without proot: Termux + glibc (built 2026-10-31, not yet tested on the phone)

Our Wine (`wine-src` dev/perf-startup + the changes below) built against
Termux's glibc (`termux-glibc/`, packages from service.termux-pacman.dev/gpkg):
programs ask for `/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1`
and run directly in Termux. Runtime: `~/src/rhino-arm/dist/rhino-android-termux.tar.zst`
(glibc libs, Mesa llvmpipe, Wine in `$PREFIX/glibc/opt/wine-rhino`, FEX DLLs,
launcher `$PREFIX/bin/rhino-android`, source `termux/rhino-android`).

Build: `termux-glibc/fetch-sysroot.py` + `termux-glibc/cc.sh` as CC,
`CFLAGS="-O2 -DWINE_SERVER_DIR_IN_PREFIX"`, build dir `~/src/rhino-arm/build-wine-termux`.

Wine changes (uncommitted in wine-src):
- winex11: ignore BadWindow on Map/UnmapWindow (window destroyed by another process)
- nsiproxy: stable locally administered MAC when Android denies SIOCGIFHWADDR
- ntdll/server: `WINE_SERVER_DIR_IN_PREFIX` uses Wine's Android server dir (no /tmp)
- ntdll/nsiproxy: `WINE_DMI_DIR` fallback for DMI files and machine-id
  (the licensing NullReferenceException came from empty DMI/UUID/MAC)

Install on the phone:
1. Replace Play Store Termux with the GitHub build (termux-app releases,
   arm64-v8a): the Play build targets a newer API that forbids running
   programs from app storage. Uninstalling it wipes Termux's data.
2. In Termux: `pkg install x11-repo && pkg install termux-x11-nightly zstd`
   and `termux-setup-storage`.
3. From the PC: `adb push ~/src/rhino-arm/dist/rhino-android-termux.tar.zst /sdcard/Download/`
   (plus the Rhino bundle and rhino.msi).
4. In Termux: `tar --zstd -xf /sdcard/Download/rhino-android-termux.tar.zst -C /`
5. `termux-x11 :0 &`, open Termux:X11, then
   `rhino-android --install /sdcard/Download/rhino_en-us_8.36.26293.11001.exe /sdcard/Download/rhino-8.36.msi`
   and `rhino-android`.

Not yet known: whether the app domain blocks execmod (the shim's mprotect
fallback) and whether the fixed-address preloader (no static-pie: Termux's
libc.a isn't PIC) is fine on this kernel.
