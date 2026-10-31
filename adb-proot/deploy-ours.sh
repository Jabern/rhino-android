#!/bin/sh
# From the PC: install our ARM64EC Wine (~/src/rhino-arm/dist) on the phone,
# next to Hangover, and prepare prefix-rhino8-ours for it.
# Usage: [ADB=adb] deploy-ours.sh
set -e
ADB=${ADB:-adb}
R=/data/local/tmp/rhino
HERE=$(dirname "$(readlink -f "$0")")
TAR=$HOME/src/rhino-arm/dist/wine-rhino-arm64.tar

# helper scripts (adb push keeps the PC's file mode, so chmod after)
$ADB push "$HERE/enter.sh" $R/enter.sh >/dev/null
for f in wenv run-rhino.sh setup-ours.sh vnc.sh; do
    $ADB push "$HERE/$f" $R/debian/usr/local/bin/${f%.sh} >/dev/null
done
$ADB shell "chmod 755 $R/enter.sh $R/debian/usr/local/bin/*"
# vnc.sh is installed as rhino-vnc
$ADB shell "mv -f $R/debian/usr/local/bin/vnc $R/debian/usr/local/bin/rhino-vnc"

# a copy of the Hangover-installed Rhino prefix, once
$ADB shell "[ -d $R/debian/root/prefix-rhino8-ours/drive_c ] || cp -a $R/debian/root/prefix-rhino8 $R/debian/root/prefix-rhino8-ours"

$ADB push "$TAR" $R/debian/root/wine-rhino-arm64.tar
$ADB shell "$R/enter.sh /usr/local/bin/setup-ours"
