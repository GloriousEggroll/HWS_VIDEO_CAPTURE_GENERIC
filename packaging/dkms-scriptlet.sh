# shellcheck shell=sh
# Shared by the .rpm and .deb install scripts, which set VER and ACTION first
# (postinst or prerm). A failed module build must not fail the package install:
# the kernel's headers may just not be there yet, and DKMS retries at the next
# kernel install.
case "$ACTION" in
    postinst)
        dkms add -m hwsvideo -v "$VER" >/dev/null 2>&1 || true
        built=0
        for kb in /lib/modules/*/build; do
            [ -e "$kb/Makefile" ] || continue
            k=$(basename "$(dirname "$kb")")
            if dkms install -m hwsvideo -v "$VER" -k "$k" --force; then
                built=1
            else
                echo "hwsvideo: the build failed for kernel $k; the log is under /var/lib/dkms/hwsvideo/$VER/build/make.log" >&2
            fi
        done
        [ "$built" -eq 1 ] || echo "hwsvideo: no module built yet. Install your kernel's headers, then run: sudo dkms autoinstall" >&2
        for old in HwsUHDX1CaptureForLinux HwsCaptureForLinux HwsAHDCaptureForLinux; do
            [ -d "/var/lib/dkms/$old" ] && echo "hwsvideo: remove the old driver, which claims the same cards: sudo dkms remove $old --all" >&2
        done
        echo "hwsvideo: reboot, or run: sudo modprobe hwsvideo"
        ;;
    prerm)
        dkms remove -m hwsvideo -v "$VER" --all >/dev/null 2>&1 || true
        ;;
esac
exit 0
