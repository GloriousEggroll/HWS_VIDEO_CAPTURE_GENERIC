#!/usr/bin/env bash
# Build the DKMS package for the distribution this runs on: an .rpm on Fedora,
# a .deb on Debian and Ubuntu. The package holds the driver's sources, and DKMS
# builds the module on the machine it's installed on, for each kernel.
#
# Usage: packaging/build-package.sh OUTPUT_DIR
# Needs rpm-build on Fedora, dpkg-dev on Debian and Ubuntu.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
OUT=$(mkdir -p "${1:?usage: $0 OUTPUT_DIR}" && cd "$1" && pwd)
VER=$(sed -n 's/^PACKAGE_VERSION=//p' "$REPO/src/dkms.conf")
[ -n "$VER" ] || { echo "no PACKAGE_VERSION in src/dkms.conf" >&2; exit 1; }
# shellcheck source=/dev/null
. /etc/os-release
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# the files a package installs, under $1
stage() {
    local root=$1
    mkdir -p "$root/usr/src/hwsvideo-$VER" "$root/etc/modprobe.d" "$root/usr/share/doc/hwsvideo-dkms"
    find "$REPO/src" -maxdepth 1 -type f \( -name '*.c' -o -name '*.h' -o -name Makefile -o -name dkms.conf \) \
        ! -name '*.mod.c' -exec install -m 644 -t "$root/usr/src/hwsvideo-$VER" {} +
    install -m 644 "$REPO/packaging/hwsvideo.modprobe.conf" "$root/etc/modprobe.d/hwsvideo.conf"
    install -m 644 "$REPO/README.md" "$REPO/CHANGELOG.md" "$REPO/LICENSE" "$root/usr/share/doc/hwsvideo-dkms/"
}

case "$ID" in
    fedora)
        stage "$WORK/root"
        rpmbuild -bb "$REPO/packaging/hwsvideo-dkms.spec" \
            --define "_topdir $WORK/rpm" --define "_rpmdir $OUT" --define "_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
            --define "hws_version $VER" --define "hws_root $WORK/root" \
            --define "hws_scriptlet $REPO/packaging/dkms-scriptlet.sh"
        ;;
    debian|ubuntu)
        root=$WORK/root
        stage "$root"
        mkdir -p "$root/DEBIAN"
        pkgver="$VER-1~$ID$VERSION_ID"
        cat >"$root/DEBIAN/control" <<CONTROL
Package: hwsvideo-dkms
Version: $pkgver
Architecture: all
Maintainer: GloriousEggroll <https://github.com/GloriousEggroll/HWS_VIDEO_CAPTURE_GENERIC>
Section: kernel
Priority: optional
Depends: dkms, gcc, make
Recommends: linux-headers-generic | linux-headers-amd64
Homepage: https://github.com/GloriousEggroll/HWS_VIDEO_CAPTURE_GENERIC
Description: Driver for HWS PCIe capture cards (AVMatrix, ACASIS), DKMS sources
 V4L2 and ALSA driver for the AVMatrix VC12-4K, VC41 and VC42, ACASIS's 4K,
 1080p and AHD capture cards, and related cards.
CONTROL
        echo /etc/modprobe.d/hwsvideo.conf >"$root/DEBIAN/conffiles"
        for s in postinst prerm; do
            { echo '#!/bin/sh'; echo "VER=$VER"; echo "ACTION=$s"; cat "$REPO/packaging/dkms-scriptlet.sh"; } >"$root/DEBIAN/$s"
            chmod 755 "$root/DEBIAN/$s"
        done
        dpkg-deb --root-owner-group --build "$root" "$OUT/hwsvideo-dkms_${pkgver}_all.deb" >/dev/null
        ;;
    *)
        echo "no package format for $ID" >&2
        exit 1
        ;;
esac
ls -l "$OUT"
