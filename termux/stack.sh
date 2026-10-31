#!/data/data/com.termux/files/usr/bin/sh
# (Re)start everything around Rhino in Termux: sshd (dev access over adb
# forward 8022), Termux:X11 on :0, Openbox, x11vnc (localhost:5900), VirGL server.
termux-wake-lock 2>/dev/null
pgrep -x sshd >/dev/null || sshd
if ! pgrep -f 'com.termux.x11 :0' >/dev/null; then
    setsid -f sh -c "termux-x11 :0 > ~/x11.log 2>&1"
    sleep 3
fi
am start -n com.termux.x11/.MainActivity >/dev/null 2>&1
pgrep -x openbox >/dev/null || DISPLAY=:0 setsid -f sh -c "openbox > ~/openbox.log 2>&1"
pgrep -x x11vnc >/dev/null || setsid -f sh -c "x11vnc -display :0 -localhost -rfbport 5900 -forever -shared -nopw -noshm -quiet > ~/vnc.log 2>&1"
pgrep -f virgl_test_server_android >/dev/null || setsid -f sh -c "virgl_test_server_android > ~/virgl.log 2>&1"
echo stack-up
