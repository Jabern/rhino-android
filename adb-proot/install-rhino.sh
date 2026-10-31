#!/bin/sh
# inside proot: Mono/Gecko, then the Rhino installer; log to /root/install.log
L=/root/install.log
s() { echo "$(date +%T) $*" >> $L; }
s start
wenv wine winecfg /v win10 >> $L 2>&1; s "winver: $(wenv wine cmd /c ver 2>/dev/null | tr -d "\r" | grep -i version)"
[ -n "$SKIP_PREP" ] && { WINEDLLOVERRIDES="winemenubuilder.exe=d" wenv wine /root/installers/rhino_en-us_8.36.26293.11001.exe /passive /norestart >> $L 2>&1; s "installer rc=$?"; wenv wineserver -w; s finished; exit; }
WINEDLLOVERRIDES="winemenubuilder.exe=d" wenv wineboot -u >> $L 2>&1; wenv wineserver -w
s "wineboot -u done; mono: $(ls /root/prefix-rhino8/drive_c/windows/mono 2>&1 | tr '\n' ' ')"
wenv wine msiexec /i /root/.cache/wine/wine-gecko-2.47.4-x86_64.msi /qn >> $L 2>&1
s "gecko64 rc=$?"
WINEDLLOVERRIDES="winemenubuilder.exe=d" wenv wine /root/installers/rhino_en-us_8.36.26293.11001.exe /passive /norestart >> $L 2>&1
s "installer rc=$?"
wenv wineserver -w
s finished
