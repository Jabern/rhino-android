#!/usr/bin/env python3
"""Build a sysroot from Termux's glibc packages (service.termux-pacman.dev/gpkg).

Resolves dependencies from the repo database, downloads each package once
(checked against its SHA-256) and unpacks it into SYSROOT. The packages live
under /data/data/com.termux/files/usr/glibc, so that is the sysroot's prefix.

Usage: fetch-sysroot.py DB_DIR PKG_DIR SYSROOT package...
"""
import hashlib
import os
import subprocess
import sys
import urllib.request

REPO = "https://service.termux-pacman.dev/gpkg/aarch64/"


def read_db(db_dir):
    pkgs, provides = {}, {}
    for entry in os.listdir(db_dir):
        fields, key = {}, None
        with open(os.path.join(db_dir, entry, "desc")) as f:
            for line in f.read().splitlines():
                if line.startswith("%") and line.endswith("%"):
                    key = line.strip("%")
                    fields[key] = []
                elif line and key:
                    fields[key].append(line)
        name = fields["NAME"][0]
        pkgs[name] = fields
        for p in fields.get("PROVIDES", []):
            provides.setdefault(strip_version(p), name)
    return pkgs, provides


def strip_version(dep):
    for op in (">=", "<=", "=", ">", "<"):
        dep = dep.split(op)[0]
    return dep


def resolve(pkgs, provides, wanted):
    order, seen = [], set()

    def visit(dep):
        name = strip_version(dep)
        name = name if name in pkgs else provides.get(name)
        if not name or name in seen:
            if not name:
                print("  (not in repo: %s)" % dep)
            return
        seen.add(name)
        for d in pkgs[name].get("DEPENDS", []):
            visit(d)
        order.append(name)

    for w in wanted:
        visit(w)
    return order


def fetch(pkg, pkg_dir):
    path = os.path.join(pkg_dir, pkg["FILENAME"][0])
    if not os.path.exists(path):
        urllib.request.urlretrieve(REPO + pkg["FILENAME"][0], path + ".part")
        os.rename(path + ".part", path)
    with open(path, "rb") as f:
        if hashlib.sha256(f.read()).hexdigest() != pkg["SHA256SUM"][0]:
            os.unlink(path)
            sys.exit("checksum mismatch: " + path)
    return path


def main():
    db_dir, pkg_dir, sysroot, *wanted = sys.argv[1:]
    pkgs, provides = read_db(db_dir)
    names = resolve(pkgs, provides, wanted)
    print("%d packages" % len(names))
    os.makedirs(sysroot, exist_ok=True)
    for name in names:
        path = fetch(pkgs[name], pkg_dir)
        subprocess.run(["tar", "xf", path, "-C", sysroot, "--exclude=.PKGINFO",
                        "--exclude=.BUILDINFO", "--exclude=.MTREE", "--exclude=.INSTALL"], check=True)
        print("  " + name)


if __name__ == "__main__":
    main()
