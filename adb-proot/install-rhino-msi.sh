#!/bin/sh
# inside proot: install rhino.msi directly. Its DLL custom actions don't set
# their properties under FEX (IsRhinoInstalled returns 1 but leaves
# RHINO_80_INSTALLED unset), so pass what they set on x86-64.
L=/root/install.log
s() { echo "$(date +%T) $*" >> $L; }
s "msi start"
WINEDLLOVERRIDES="winemenubuilder.exe=d" wenv wine msiexec /i 'Z:\root\installers\rhino-8.36.msi' /qn /l*v 'C:\rhino-msi.log' \
  RHINO_80_INSTALLED=0 RHINO_50_X64_INSTALLED=0 RHINO_50_X86_INSTALLED=0 RMA_LICENSEISINSTALLED=0 \
  ARPSYSTEMCOMPONENT=1 MSIFASTINSTALL=7 DEFER_NET48_REBOOT=1 \
  ENABLE_AUTOMATIC_UPDATES=0 DISABLE_INTERNET_ACCESS=0 SEND_STATISTICS=0 INSTALL_EN=1 >> $L 2>&1
s "msi rc=$?"
wenv wineserver -w
s finished-msi
