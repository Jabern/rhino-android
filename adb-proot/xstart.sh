#!/bin/sh
# inside proot: start Xvfb :1 once
export DISPLAY=:1
if ! xdpyinfo >/dev/null 2>&1; then
  mkdir -p /tmp/.X11-unix
  nohup Xvfb :1 -screen 0 1600x900x24 -nolisten tcp >/root/xvfb.log 2>&1 &
  for i in $(seq 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
fi
xdpyinfo | grep dimensions
