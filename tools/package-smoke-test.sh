#!/usr/bin/env bash
# Install a package from packaging/build-package.sh in a throwaway container,
# check DKMS built the module, then remove it. Run after tools/ci-build.sh,
# which installs the kernel headers. Don't run it on a real system.
#
# Usage: tools/package-smoke-test.sh DIST_DIR
set -euo pipefail
dist=${1:?usage: $0 DIST_DIR}
[ -e /run/.containerenv ] || [ -e /.dockerenv ] || [ -n "${GITHUB_ACTIONS:-}" ] \
    || { echo "this installs and removes packages; run it in a container" >&2; exit 1; }
# Fedora's kernel-devel doesn't own the build link the kernel package normally makes
for k in /usr/src/kernels/*/; do
    [ -d "$k" ] || continue
    v=$(basename "$k")
    mkdir -p "/lib/modules/$v"
    [ -e "/lib/modules/$v/build" ] || ln -s "$k" "/lib/modules/$v/build"
done
if command -v dnf >/dev/null; then
    dnf -y -q install "$dist"/*.rpm
else
    export DEBIAN_FRONTEND=noninteractive
    apt-get -qq install -y "$dist"/*.deb
fi
dkms status hwsvideo
dkms status hwsvideo | grep -q ': installed' || { echo "DKMS didn't install the module" >&2; exit 1; }
find /lib/modules -name 'hwsvideo.ko*' | grep -q . || { echo "no hwsvideo module" >&2; exit 1; }
[ -e /etc/modprobe.d/hwsvideo.conf ]
if command -v dnf >/dev/null; then
    dnf -y -q remove hwsvideo-dkms
else
    apt-get -qq remove -y hwsvideo-dkms
fi
if find /lib/modules -name 'hwsvideo.ko*' | grep -q .; then
    echo "removing the package left the module behind" >&2
    exit 1
fi
echo "package install and removal OK"
