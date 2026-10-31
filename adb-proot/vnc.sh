#!/bin/sh
# inside proot: mirror the Termux:X11 display (:0) over VNC on the phone's
# localhost only; reach it from the PC with: adb forward tcp:5900 tcp:5900
exec x11vnc -display :0 -localhost -rfbport 5900 -forever -shared -nopw -noshm -quiet -o /root/x11vnc.log
