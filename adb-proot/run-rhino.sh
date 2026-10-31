#!/bin/sh
# inside proot: start Rhino 8; log to /root/rhino.log
L=/root/rhino.log
echo "$(date +%T) launch (${RHINO_WINE:-hangover})" > $L
P=/root/prefix-rhino8; [ "$RHINO_WINE" = ours ] && P=/root/prefix-rhino8-ours
# same .NET settings as rhino-linux/tools/rhino-linux
export DOTNET_gcServer=0 DOTNET_TieredPGO=1 DOTNET_TC_QuickJitForLoops=1 DOTNET_ReadyToRun=1 DOTNET_GCDynamicAdaptationMode=1 DOTNET_EnableWriteXorExecute=0
# exception log (~/src/rhino-android/exception-hook), when installed
[ -f $P/drive_c/rhino-hook/RhinoExceptionHook.dll ] && export DOTNET_STARTUP_HOOKS='C:\rhino-hook\RhinoExceptionHook.dll'
cd "$P/drive_c/Program Files/Rhino 8/System"
WINEDLLOVERRIDES="winemenubuilder.exe=d" WINEDEBUG=${RHINO_WINEDEBUG:-err+all} wenv wine Rhino.exe >> $L 2>&1
echo "$(date +%T) exit rc=$?" >> $L
