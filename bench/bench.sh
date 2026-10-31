#!/data/data/com.termux/files/usr/bin/sh
# bench.sh llvmpipe|virgl|virgl45 : restart Rhino with that renderer, run bench.rvb
C=$HOME/.wine-rhino8/drive_c
wineserver -k 2>/dev/null; sleep 1
cp /sdcard/Download/bench.rvb "$C/bench.rvb"; rm -f "$C/bench-result.txt"
case "$1" in
virgl)   export GALLIUM_DRIVER=virpipe ;;
virgl45) export GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.5COMPAT MESA_GLSL_VERSION_OVERRIDE=450 ;;
esac
t=$(date +%s)
DISPLAY=:0 setsid -f sh -c 'rhino-android /nosplash "/runscript=_-LoadScript C:\bench.rvb" > ~/bench-rhino.log 2>&1'
while [ ! -s "$C/bench-result.txt" ] && [ $(( $(date +%s) - t )) -lt 400 ]; do sleep 3; done
echo "== $1 ($(( $(date +%s) - t ))s)"
[ -s "$C/bench-result.txt" ] && tr -d '\r' < "$C/bench-result.txt" | grep -aiE "second|frame|fps|error|opengl" | tail -6 || { echo "no result"; grep -aE "err:|X Error|Unhandled" ~/bench-rhino.log | tail -5; }
