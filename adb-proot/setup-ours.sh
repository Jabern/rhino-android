#!/bin/sh
# inside proot: set up our Wine (rhino-linux patches 01-40, ARM64EC) next to
# Hangover. Expects /root/wine-rhino-arm64.tar (from ~/src/rhino-arm/dist) and
# /root/prefix-rhino8-ours (a copy of the Hangover-installed Rhino prefix).
set -e
W=/opt/wine-rhino
P=/root/prefix-rhino8-ours

rm -rf $W && tar xf /root/wine-rhino-arm64.tar -C / && rm /root/wine-rhino-arm64.tar
# FEX: x86-64 (ARM64EC) and x86 (WoW64) emulators, taken from Hangover
cp /usr/lib/wine/aarch64-windows/libarm64ecfex.dll /usr/lib/wine/aarch64-windows/libwow64fex.dll $W/lib/wine/aarch64-windows/

# undo the Hangover-era drop-ins: our build has patches 12 and 15 built in
S=$P/drive_c/windows/system32
[ -f $S/ncrypt.dll.hangover ] && mv -f $S/ncrypt.dll.hangover $S/ncrypt.dll
[ -f $S/wbem/wbemprox.dll.hangover ] && mv -f $S/wbem/wbemprox.dll.hangover $S/wbem/wbemprox.dll

export RHINO_WINE=ours
WINEDEBUG=-all wenv wineboot -u
wenv wine reg add 'HKLM\Software\Microsoft\Wow64\amd64' /ve /d libarm64ecfex.dll /f
wenv wine reg add 'HKLM\Software\Microsoft\Wow64\x86' /ve /d libwow64fex.dll /f
wenv wine reg delete 'HKCU\Software\Wine\DllOverrides' /v ncrypt /f || true
wenv wine reg delete 'HKCU\Software\Wine\DllOverrides' /v wbemprox /f || true
# as in rhino-linux's deploy-rhino.sh: Edge Update never exits and keeps
# wineserver alive
for svc in edgeupdate edgeupdatem; do
    wenv wine reg add "HKLM\\System\\CurrentControlSet\\Services\\$svc" /v Start /t REG_DWORD /d 4 /f || true
done
timeout 10 wenv wineserver -w || wenv wineserver -k
echo "our Wine: $(wenv wine --version)"
