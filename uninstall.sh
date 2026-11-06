#!/usr/bin/env bash
# Remove the hwsvideo driver: every version install.sh or the development
# tools added to DKMS, the vendor drivers it replaced (HwsUHDX1Capture,
# HwsCapture, HwsAHDCapture), and everything the older installers (scripts/hws-*.sh) left behind.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exec sudo -- "$0" "$@"

MODULE=hwsvideo
OLD_MODULES=(HwsUHDX1Capture HwsCapture HwsAHDCapture)
shopt -s nullglob

# DKMS: this package, and the names the two old drivers used
for name in hwsvideo HwsUHDX1CaptureForLinux HwsUHDX1Capture.ko HwsCaptureForLinux HwsCapture.ko HwsAHDCaptureForLinux HwsAHDCapture.ko; do
    for d in /var/lib/dkms/"$name"/*/; do
        ver=$(basename "$d")
        case "$ver" in kernel-*|source) continue ;; esac
        echo "Removing $name $ver from DKMS"
        dkms remove -m "$name" -v "$ver" --all >/dev/null 2>&1 || true
    done
    rm -rf "/var/lib/dkms/$name"
done
for p in /usr/src/hwsvideo-* /usr/src/HwsUHDX1CaptureForLinux-* /usr/src/HwsUHDX1Capture.ko-* /usr/src/HwsUHDX1Capture.ko_* \
         /usr/src/HwsCaptureForLinux-* /usr/src/HwsCapture.ko-* /usr/src/HwsCapture.ko_* \
         /usr/src/HwsAHDCaptureForLinux-* /usr/src/HwsAHDCapture.ko-* /usr/src/HwsAHDCapture.ko_*; do
    echo "Removing $p"
    rm -rf "$p"
done

# the old installers' copy of the sources and their /usr/bin links
if [ -e /usr/local/share/HWS ]; then
    echo "Removing /usr/local/share/HWS"
    rm -rf /usr/local/share/HWS
fi
for l in /usr/bin/hws-*.sh; do
    echo "Removing $l"
    rm -f "$l"
done

# ACASIS's Kylin installer loads its module at boot with a service, from /opt
for svc in hws hwsuhdx1; do
    f=/etc/systemd/system/$svc.service
    if [ -e "$f" ] && grep -q hws-load.sh "$f"; then
        echo "Removing $f"
        command -v systemctl >/dev/null && systemctl disable "$svc.service" >/dev/null 2>&1
        rm -f "$f"
        command -v systemctl >/dev/null && systemctl daemon-reload >/dev/null 2>&1
    fi
done
if [ -e /usr/local/sbin/hws-load.sh ] || [ -e /opt/HWS/ko ]; then
    echo "Removing /usr/local/sbin/hws-load.sh and /opt/HWS/ko"
    rm -rf /usr/local/sbin/hws-load.sh /opt/HWS/ko
    rmdir /opt/HWS 2>/dev/null || true
fi

# modules a non-DKMS install copied into the kernel trees
for m in "$MODULE" "${OLD_MODULES[@]}"; do
    while IFS= read -r -d '' f; do
        echo "Removing $f"
        rm -f "$f"
    done < <(find /lib/modules -name "$m.ko*" -print0 2>/dev/null)
done

for k in /lib/modules/*/; do
    [ -e "$k/modules.order" ] || continue
    depmod -a "$(basename "$k")" 2>/dev/null || true
done

# install.sh's blacklist of the in-kernel hws driver
for f in /etc/modprobe.d/hwsvideo.conf /etc/modprobe.d/hws-capture.conf; do
    if [ -e "$f" ]; then
        echo "Removing $f (the in-kernel hws driver may load again)"
        rm -f "$f"
    fi
done
# tools/wireplumber-names.sh's rule, or ACASIS's under the same name
if [ -e /etc/wireplumber/wireplumber.conf.d/80-hws-audio-names.conf ]; then
    echo "Removing /etc/wireplumber/wireplumber.conf.d/80-hws-audio-names.conf"
    rm -f /etc/wireplumber/wireplumber.conf.d/80-hws-audio-names.conf
fi
if [ -e /etc/modprobe.d/hws.conf ]; then
    echo "Left /etc/modprobe.d/hws.conf in place (your module options)."
fi
if [ -d "/sys/module/$MODULE" ] || [ -d /sys/module/HwsUHDX1Capture ] || [ -d /sys/module/HwsCapture ] || [ -d /sys/module/HwsAHDCapture ]; then
    echo "The driver is still loaded. Reboot to unload it."
else
    echo "Done."
fi
