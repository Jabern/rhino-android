#!/bin/sh
# clang for Termux's glibc (aarch64): the prefix /data/data/com.termux/files/usr/glibc
# inside the sysroot, programs run there without proot
G=$(dirname "$(readlink -f "$0")")
T=/data/data/com.termux/files/usr/glibc
link="-Wl,--dynamic-linker=$T/lib/ld-linux-aarch64.so.1 -Wl,-rpath,$T/lib"
# static programs (wine-preloader) are loaded by the kernel itself
case " $* " in *" -static"*) link= ;; esac
exec ccache clang --target=aarch64-linux-gnu --sysroot="$G/sysroot" -fuse-ld=lld -Qunused-arguments \
    -isystem "$G/sysroot$T/include" -B"$G/sysroot$T/lib" -L"$G/sysroot$T/lib" \
    --gcc-install-dir="$G/sysroot$T/lib/gcc/aarch64-linux-gnu/14" $link "$@"
