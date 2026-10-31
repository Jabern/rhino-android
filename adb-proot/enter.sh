#!/system/bin/sh
# Run a command inside the Debian proot: enter.sh <cmd...>
R=/data/local/tmp/rhino
. $R/env.sh
exec $R/bin/proot --kill-on-exit -0 -l -r $R/debian -w /root \
  -b /dev -b /proc -b /sys -b /dev/urandom:/dev/random \
  -b $R/debian/tmp:/dev/shm \
  -b $R/dmi:/sys/class/dmi/id \
  /usr/bin/env -i ${DISPLAY:+DISPLAY=$DISPLAY} ${RHINO_WINE:+RHINO_WINE=$RHINO_WINE} HOME=/root TERM=xterm LANG=C.UTF-8 \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$@"
