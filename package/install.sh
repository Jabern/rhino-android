#!/data/data/com.termux/files/usr/bin/sh
# Rhino 8 on Android: one-time setup in Termux (GitHub build, not Play Store).
#   sh install.sh [path/to/rhino_en-us_8.x.exe]
# Without a path, the newest rhino_en-us_8*.exe in Download/ is used.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
say() { printf '\n== %s\n' "$*"; }

[ "$(uname -m)" = aarch64 ] || { echo "This needs a 64-bit ARM phone." >&2; exit 1; }
case "$PREFIX" in /data/data/com.termux/files/usr) ;; *) echo "Run this in Termux." >&2; exit 1 ;; esac
ram=$(awk '/MemTotal/ { print int($2 / 1048576 + 0.5) }' /proc/meminfo)
echo "Phone: $(getprop ro.product.manufacturer) $(getprop ro.product.model), Android $(getprop ro.build.version.release), ${ram} GB RAM"
[ "$ram" -ge 6 ] || echo "Warning: with ${ram} GB RAM Android will likely close Rhino. 6 GB or more is recommended."

say "Storage access (allow it when Android asks)"
[ -d "$HOME/storage/downloads" ] || termux-setup-storage
sleep 2
bundle=$1
[ -n "$bundle" ] || bundle=$(ls -t "$HOME"/storage/downloads/rhino_en-us_8*.exe /sdcard/Download/rhino_en-us_8*.exe 2>/dev/null | head -1)
[ -f "$bundle" ] || { echo "Rhino 8 installer not found. Download it from rhino3d.com into Download/ and run again." >&2; exit 1; }
echo "Rhino installer: $bundle"

say "Termux packages"
pkg update -y
pkg install -y x11-repo
# the Cloudflare mirror of the X11 repository times out on some networks
sed -i 's|packages-cf.termux.dev|packages.termux.dev|' "$PREFIX/etc/apt/sources.list.d/x11.list"
pkg update -y
pkg install -y termux-x11-nightly openbox virglrenderer-android xterm zstd curl

say "Rhino runtime (Wine with FEX, glibc, Mesa)"
tar --zstd -xf "$HERE/rhino-android-termux.tar.zst" -C "$PREFIX/.." --strip-components=4
chmod 755 "$PREFIX/bin/rhino-android" "$PREFIX/bin/rhino"
mkdir -p "$HOME/.rhino-android" "$HOME/.cache/wine"

say "Wine Mono and Gecko (needed by the Rhino installer)"
while read -r addon sum; do
    f=$HOME/.cache/wine/$(basename "$addon")
    echo "$sum  $f" | sha256sum -c --status 2>/dev/null && continue
    curl -fsSL --retry 3 -o "$f" "https://dl.winehq.org/wine/$addon"
    echo "$sum  $f" | sha256sum -c --status || { echo "bad download: $f" >&2; exit 1; }
done <<'ADDONS'
wine-mono/11.3.0/wine-mono-11.3.0-x86.msi df2dfc1665c2511882e7cabd56eafd0c0a3d94e5a7e86f969277f6c189d418d3
wine-gecko/2.47.4/wine-gecko-2.47.4-x86.msi 26cecc47706b091908f7f814bddb074c61beb8063318e9efc5a7f789857793d6
wine-gecko/2.47.4/wine-gecko-2.47.4-x86_64.msi e590b7d988a32d6aa4cf1d8aa3aa3d33766fdd4cf4c89c2dcc2095ecb28d066f
ADDONS

say "Display (Termux:X11 opens; come back to Termux to follow along)"
pgrep -f 'com.termux.x11 :0' >/dev/null || { setsid -f sh -c "termux-x11 :0 > ~/.rhino-android/x11.log 2>&1"; sleep 3; }
pgrep -x openbox >/dev/null || DISPLAY=:0 setsid -f sh -c "openbox > ~/.rhino-android/openbox.log 2>&1"

say "Installing Rhino 8 (10-15 minutes, the screen may stay dark)"
DISPLAY=:0 RHINO_GL=llvmpipe rhino-android --install "$bundle"

say "Done. Start Rhino with:  rhino"
echo "Sign in: click Login, copy the link and open it in a browser on this phone."
