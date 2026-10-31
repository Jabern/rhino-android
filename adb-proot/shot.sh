#!/bin/sh
# Screenshot the phone's Xvfb (proot setup) to the PC: shot.sh <out.png>
ADB=${ADB:-adb}
xwd=$(mktemp --suffix=.xwd)
$ADB shell '/data/local/tmp/rhino/enter.sh /bin/sh -c "DISPLAY=:1 xwd -root -silent > /tmp/shot.xwd"' &&
$ADB pull /data/local/tmp/rhino/debian/tmp/shot.xwd "$xwd" >/dev/null &&
magick "$xwd" "$1"
rm -f "$xwd"
