# Rhino on ARM Linux

Goal: Rhino 7, 8 and 9 on 64-bit ARM Linux (Snapdragon X laptops, Asahi on
Apple Silicon, Ampere workstations, Raspberry Pi 5 class boards), using the
same patched Wine as the x86-64 release.

McNeel ships Rhino for Windows as x86-64 only (there is no Windows ARM64
build), so the Rhino code itself is always emulated. Only the code around it
can run natively.

## How it fits together

```
Rhino.exe, RhinoCommon, .NET JIT output      x86-64   -> FEX (libarm64ecfex.dll)
Wine PE DLLs: ntdll, user32, win32u, d3d...   ARM64EC  -> native
Wine Unix side, winex11, Vulkan/GL drivers    aarch64  -> native
```

Wine built with `--enable-archs=arm64ec,aarch64,i386` runs x86-64 programs in
an ARM64EC process: FEX emulates only the program's own code, while every
Wine DLL it calls runs natively. This is what Hangover and the Android
launchers do, and it beats running all of Wine under emulation.

## Plan

### Phase 0: does Rhino start at all?

No Wine changes. Run the **existing x86-64 runtime** (v1.4.x) under full
FEX-Emu with an x86-64 rootfs on an aarch64 machine. Everything is emulated,
so it is slow, but it tests what matters first: the installer, .NET 8 under
emulation, Cloud Zoo sign-in, and the OpenGL viewport on that GPU driver.
The numbers become the baseline for Phase 1.

### Phase 1: native Wine (ARM64EC)

- Build `wine-src` (dev/wine-11.20 + patches 01-40) with ARM64EC.
  None of our patches adds x86-only code, so they should carry over; patches
  29/30/32 (dcomp, cross-process windows, server) need a runtime check.
- Upstream Wine still lacks some pieces FEX needs. The FEX wiki points to a
  fork for now. Check what is missing before choosing a base.
- FEX ARM64EC + WoW64 modules (`libarm64ecfex.dll`, `libwow64fex.dll`) go
  into the runtime's `aarch64-windows/`.
- DXVK: try the x86-64 build (emulated) first, then an ARM64EC build.
- New CI job in `build-wine.yml` (ubuntu-24.04-arm runner), producing a
  `wine-rhino-aarch64` artifact next to the x86-64 one.

### Phase 2: packaging

- `install.sh` picks the runtime from `uname -m`.
- Flatpak: the Freedesktop runtime exists for aarch64; build the app for both
  arches.

## Known blockers

| Issue | Why it matters |
|---|---|
| **16K pages** | FEX needs 4K pages. Asahi kernels use 16K, so Asahi needs a 4K microVM (muvm, as Fedora Asahi does for Steam). Same problem on Android 15+ devices with 16K pages. |
| **OpenGL 4.x** | Rhino's viewport needs desktop GL 4.1+ that works reliably. McNeel blames unstable Qualcomm GL drivers for Rhino's crashes on Windows ARM. On Linux: Freedreno/Turnip (+Zink), Asahi GL 4.6, panfrost (Mali) needs checking. |
| **.NET JIT under emulation** | CoreCLR writes x86-64 code at runtime, and FEX has to translate it again. Startup is mostly JIT already (see linbench), so expect a big slowdown at first. |
| **WebView2 (Rhino 9 Script Editor)** | Edge is x86-64 and multi-process. Put off until the basics work. |

## Hardware needed

The build machine is x86-64. Each phase needs at least one real aarch64 box
with a working GPU. QEMU is fine for building, but too slow to judge FEX and
can't test graphics.
