#!/bin/sh
# From the PC: bring up Rhino on the phone over adb.
#   Termux:X11 (:0, shown on the phone) + x11vnc mirror (PC: localhost:5900) + Rhino 8.
# Usage: [ADB=adb] [RHINO_WINE=ours] start-phone.sh   (ours: our Wine, else Hangover)
#        start-phone.sh stop
set -e
ADB=${ADB:-adb}
R=/data/local/tmp/rhino

if [ "$1" = stop ]; then
    $ADB shell "$R/enter.sh wenv wineserver -k; pkill x11vnc; kill \$(pidof termux-x11)" || true
    $ADB forward --remove tcp:5900 2>/dev/null || true
    $ADB forward --remove tcp:1717 2>/dev/null || true
    exit 0
fi

# Termux:X11 server, started the way the termux-x11 command does. The shell
# user may only use abstract sockets, so TMPDIR=/tmp gives it the abstract
# name X clients in the proot look for (@/tmp/.X11-unix/X0).
if ! $ADB shell pidof termux-x11 >/dev/null; then
    $ADB shell "cd $R; XKB_CONFIG_ROOT=$R/debian/usr/share/X11/xkb TMPDIR=/tmp \
        CLASSPATH=\$(pm path com.termux.x11 | cut -d: -f2) \
        nohup app_process / --nice-name=termux-x11 com.termux.x11.CmdEntryPoint :0 -ac \
        </dev/null >$R/termux-x11.log 2>&1 &"
    sleep 3
fi
# Landscape 1920x1080, fullscreen
$ADB shell am broadcast -a com.termux.x11.CHANGE_PREFERENCE -p com.termux.x11 \
    --es displayResolutionMode custom --es displayResolutionCustom 1920x1080 \
    --es forceOrientation landscape --es fullscreen true >/dev/null
$ADB shell "input keyevent KEYCODE_WAKEUP; am start -n com.termux.x11/.MainActivity" >/dev/null 2>&1

# One adb shell per background job: jobs started next to other commands in the
# same adb shell get killed when it exits.
$ADB shell pidof openbox >/dev/null ||
    $ADB shell "cd $R; nohup ./enter.sh /usr/bin/env DISPLAY=:0 openbox </dev/null >$R/openbox.log 2>&1 &"
$ADB shell pidof x11vnc >/dev/null ||
    $ADB shell "cd $R; nohup ./enter.sh /usr/local/bin/rhino-vnc </dev/null >/dev/null 2>&1 &"
$ADB forward tcp:5900 tcp:5900 >/dev/null
# Rhino sign-in redirects to 127.0.0.1:1717, so signing in from the PC browser also works
$ADB forward tcp:1717 tcp:1717 >/dev/null

$ADB shell "ps -A -o ARGS | grep -q '^wine Rhino.exe\|Rhino.exe$'" ||
    $ADB shell "cd $R; RHINO_WINE=$RHINO_WINE nohup ./enter.sh /usr/local/bin/run-rhino </dev/null >/dev/null 2>&1 &"

echo "Phone: Termux:X11 is in front. PC: gvncviewer localhost:0 (Rhino takes ~10 min to start)."
