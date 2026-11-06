#!/usr/bin/env bash
# Install the hwsvideo driver (AVMatrix VC12-4K, VC41, VC42 and relatives)
# through DKMS.
#
# Copies the sources to /usr/src/hwsvideo-<version>, then
# builds and installs the module for every installed kernel that has its
# headers. DKMS rebuilds it for kernels installed later. Run it again to
# reinstall; uninstall.sh removes everything this or older installers put
# on the system.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exec sudo -- "$0" "$@"
# Ubuntu's DKMS asks for a Secure Boot key password through debconf; with
# no terminal to ask on, let it skip that instead of waiting forever
[ -t 0 ] || export DEBIAN_FRONTEND=noninteractive

NAME=hwsvideo
MODULE=hwsvideo
# The vendor drivers this one replaces (AVMatrix, ACASIS), and the names their old installers used.
LEGACY_DKMS=(HwsUHDX1CaptureForLinux HwsUHDX1Capture.ko HwsCaptureForLinux HwsCapture.ko HwsAHDCaptureForLinux HwsAHDCapture.ko)
LEGACY_MODULES=(HwsUHDX1Capture HwsCapture HwsAHDCapture)
HERE=$(cd "$(dirname "$0")" && pwd)
VER=$(sed -n 's/^PACKAGE_VERSION=//p' "$HERE/src/dkms.conf")
[ -n "$VER" ] || { echo "no PACKAGE_VERSION in $HERE/src/dkms.conf" >&2; exit 1; }

# in a subshell: os-release defines NAME too
# shellcheck source=/dev/null
os=$(. /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}")
hint() {
    case " $os " in
        *" fedora "*|*" rhel "*|*" centos "*) echo "sudo dnf install dkms gcc make kernel-devel-$(uname -r)" ;;
        *" debian "*|*" ubuntu "*) echo "sudo apt install dkms gcc make linux-headers-$(uname -r)" ;;
        *" arch "*) echo "sudo pacman -Syu dkms gcc make linux-headers, then reboot if the kernel was updated" ;;
        *) echo "install dkms, gcc, make and the headers for kernel $(uname -r)" ;;
    esac
}
for tool in dkms make gcc; do
    command -v "$tool" >/dev/null || { echo "$tool is missing. Install the build tools first:" >&2; hint >&2; exit 1; }
done
if [ ! -e "/lib/modules/$(uname -r)/build/Makefile" ]; then
    echo "The headers for the running kernel ($(uname -r)) are missing. Install them first:" >&2
    hint >&2
    exit 1
fi

src=/usr/src/$NAME-$VER
echo "Installing $NAME $VER"
if [ -d "/var/lib/dkms/$NAME/$VER" ]; then
    echo "  removing the earlier install of $VER"
    dkms remove -m "$NAME" -v "$VER" --all >/dev/null
fi
rm -rf "$src"
mkdir -p "$src"
# sources only: build output in the tree would be reused instead of compiled
find "$HERE/src" -maxdepth 1 -type f \( -name '*.c' -o -name '*.h' -o -name Makefile -o -name dkms.conf \) \
    ! -name '*.mod.c' -exec cp -t "$src" {} +
dkms add -m "$NAME" -v "$VER" >/dev/null

built=()
for kb in /lib/modules/*/build; do
    k=$(basename "$(dirname "$kb")")
    if [ ! -e "$kb/Makefile" ]; then
        echo "  skipping kernel $k: its headers aren't installed"
        continue
    fi
    echo "  building for kernel $k"
    # output stays on the terminal: Ubuntu may ask for a key password here
    if ! dkms install -m "$NAME" -v "$VER" -k "$k" --force; then
        echo "  build failed for $k; the log is under /var/lib/dkms/$NAME/$VER/build/make.log" >&2
        exit 1
    fi
    built+=("$k")
done
echo "Installed for: ${built[*]}"

# The new driver built, so the old ones can go: a leftover would claim the
# card if it loaded first. Done only now so that a failed build leaves them working.
shopt -s nullglob
for name in "${LEGACY_DKMS[@]}"; do
    for d in /var/lib/dkms/"$name"/*/; do
        ver=$(basename "$d")
        case "$ver" in kernel-*|source) continue ;; esac
        echo "Removing the old driver $name $ver from DKMS"
        dkms remove -m "$name" -v "$ver" --all >/dev/null 2>&1 || true
    done
    rm -rf "/var/lib/dkms/$name"
    for p in /usr/src/"$name"-* /usr/src/"$name"_*; do
        echo "Removing $p"
        rm -rf "$p"
    done
done
for m in "${LEGACY_MODULES[@]}"; do
    while IFS= read -r -d '' f; do
        echo "Removing $f"
        rm -f "$f"
    done < <(find /lib/modules -name "$m.ko*" -print0 2>/dev/null)
done
shopt -u nullglob
# kernels without headers get no new module, so nothing else refreshes their module list
for k in /lib/modules/*/; do
    [ -e "$k/modules.order" ] || continue
    depmod -a "$(basename "$k")" 2>/dev/null || true
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
# what the old installers left, and the old driver's blacklist (replaced below)
if [ -e /usr/local/share/HWS ]; then
    echo "Removing /usr/local/share/HWS"
    rm -rf /usr/local/share/HWS
fi
shopt -s nullglob
for f in /usr/bin/hws-*.sh; do
    echo "Removing $f"
    rm -f "$f"
done
shopt -u nullglob
rm -f /etc/modprobe.d/hws-capture.conf
if grep -sqE '^[[:space:]]*options[[:space:]]+(HwsUHDX1Capture|HwsCapture|HwsAHDCapture)[[:space:]]' /etc/modprobe.d/hws.conf; then
    echo "Note: /etc/modprobe.d/hws.conf sets options for an old driver name. They no longer apply; change the name to $MODULE."
fi

# Secure Boot only loads modules signed with an enrolled key.
enrol=0
if command -v mokutil >/dev/null && mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
    # the certificate DKMS signed with: Ubuntu's shim-signed key or DKMS's
    # own; when both exist, the one whose serial matches the module's
    key="" serial=$(modinfo -F sig_key "$MODULE" 2>/dev/null | tr -d ':' | tr 'a-f' 'A-F')
    for c in /var/lib/dkms/mok.pub /var/lib/shim-signed/mok/MOK.der; do
        [ -e "$c" ] || continue
        [ -z "$key" ] && key=$c
        form=pem
        [ "${c##*.}" = der ] && form=der
        cs=$(openssl x509 -in "$c" -inform "$form" -noout -serial 2>/dev/null | sed 's/^serial=//')
        [ -n "$serial" ] && [ "$cs" = "$serial" ] && { key=$c; break; }
    done
    state=""
    [ -n "$key" ] && state=$(mokutil --test-key "$key" 2>/dev/null || true)
    if [ -z "$key" ]; then
        echo
        echo "Secure Boot is on, but no DKMS signing key was found; see the README."
    elif grep -qi "already enrolled" <<<"$state"; then
        :
    elif grep -qi "enrollment request" <<<"$state"; then
        enrol=1
        cat <<EOF

Secure Boot is on, and the signing key ($key) is queued for enrolment.
Reboot. When the blue MOK manager screen appears, press a key within
10 seconds, then choose "Enroll MOK", "Continue", "Yes", enter the
password you chose, and "Reboot". If the screen times out, run
  sudo mokutil --import $key
and reboot again.
EOF
    else
        enrol=1
        cat <<EOF

Secure Boot is on, and the key DKMS signs the module with isn't enrolled yet:
  1. sudo mokutil --import $key
     (choose a one-time password)
  2. Reboot. When the blue MOK manager screen appears, press a key within
     10 seconds, then choose "Enroll MOK", "Continue", "Yes", enter that
     password, and "Reboot". If it times out, repeat step 1.
Until then the kernel refuses the module ("Key was rejected by service").
EOF
    fi
fi

# Linux 7.2 and later have their own driver for these cards, hws, and
# whichever driver loads first gets the card. Keep hws off them.
BLACKLIST=/etc/modprobe.d/hwsvideo.conf
cat >"$BLACKLIST" <<EOF
# Written by install.sh from HWS_VIDEO_CAPTURE_GENERIC. The in-kernel hws
# driver (Linux 7.2 and later) supports the same cards, and whichever driver
# loads first gets them. Delete this file, or run uninstall.sh, to use hws.
blacklist hws
EOF
hws_has_card=0
for d in /sys/bus/pci/drivers/hws/0000:*; do
    [ -e "$d" ] && hws_has_card=1
done
# An old driver still loaded keeps its card until a reboot.
old_loaded=""
for m in "${LEGACY_MODULES[@]}"; do
    [ -d "/sys/module/$m" ] && old_loaded=$m
done

# Minimal kernels (cloud and server images) leave out the media and sound
# modules the driver needs.
missing=()
for m in videodev videobuf2-vmalloc snd-pcm; do
    modinfo "$m" >/dev/null 2>&1 || missing+=("$m")
done
if [ ${#missing[@]} -gt 0 ]; then
    echo
    echo "This kernel lacks modules the driver needs: ${missing[*]}. Install them:"
    case " $os " in
        *" fedora "*|*" rhel "*|*" centos "*) echo "  sudo dnf install kernel-modules-$(uname -r)" ;;
        *" ubuntu "*) echo "  sudo apt install linux-modules-extra-$(uname -r)" ;;
        *) echo "  the kernel's full module package for $(uname -r)" ;;
    esac
    echo "then run: sudo modprobe $MODULE"
elif [ $enrol -eq 1 ]; then
    echo "The driver loads after the key is enrolled and the PC has rebooted."
elif [ $hws_has_card -eq 1 ]; then
    echo "The in-kernel hws driver has the card. Reboot: it won't load again ($BLACKLIST)."
elif [ -n "$old_loaded" ]; then
    echo "The old driver $old_loaded is still loaded and has the card. Reboot to use $MODULE."
elif [ -d "/sys/module/$MODULE" ]; then
    echo "The driver is already loaded. Reboot to use the version just installed ($VER)."
elif modprobe "$MODULE" 2>/dev/null; then
    echo "Loaded. Check with: v4l2-ctl --list-devices; arecord -l"
else
    echo "Not loaded yet. Reboot, or run: sudo modprobe $MODULE"
fi
