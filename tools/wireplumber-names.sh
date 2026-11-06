#!/usr/bin/env bash
# Show each input's sound card under its own name (HAudio 2, HUHDAudio 1) in
# OBS and other PipeWire programs, which show the name WirePlumber gives a
# source instead of the driver's. From ACASIS's PluseAudio/install.sh; covers
# every name this driver can use. Optional: the driver works without it.
#
# Usage: tools/wireplumber-names.sh install|uninstall|print [--no-restart]
#   install, uninstall  write or remove the rule, then restart the user's
#                       WirePlumber and PipeWire, which interrupts all audio
#                       for a moment. --no-restart leaves that to the next login.
#   print               print the rule
#
# Needs WirePlumber 0.5 or later, which reads these .conf rules; earlier
# versions ignore them. Uninstalling the driver removes the rule too.
set -euo pipefail

CONF_DIR=${HWS_WP_CONF_DIR:-/etc/wireplumber/wireplumber.conf.d}
# the file name ACASIS's script used, so this replaces its rule
CONF=$CONF_DIR/80-hws-audio-names.conf

rule() {   # card name
    cat <<RULE
  {
    matches = [
      {
        media.class = "Audio/Source"
        device.api = "alsa"
        alsa.driver_name = "hwsvideo"
        alsa.card_name = "$1"
      }
    ]
    actions = { update-props = { node.description = "$1" } }
  }
RULE
}

# Names are numbered by input across a card's port ID (0-3): one input per port
# on the UHD family, up to four on the HD family. AHD cards have no sound.
generate() {
    local i
    echo "# Written by HWS_VIDEO_CAPTURE_GENERIC tools/wireplumber-names.sh"
    echo "monitor.alsa.rules = ["
    for i in 1 2 3 4; do rule "HUHDAudio $i"; done
    for i in $(seq 1 16); do rule "HAudio $i"; done
    echo "]"
}

# sudo only where it's needed
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

restart_audio() {
    local user=${SUDO_USER:-$(id -un)} uid
    uid=$(id -u "$user")
    if [ "$(id -u)" -eq "$uid" ]; then
        systemctl --user restart wireplumber pipewire pipewire-pulse && return 0
    else
        sudo -u "$user" XDG_RUNTIME_DIR="/run/user/$uid" \
            systemctl --user restart wireplumber pipewire pipewire-pulse && return 0
    fi
    echo "Couldn't restart the audio services. Log out and back in to apply this." >&2
}

check_version() {
    local v
    command -v wireplumber >/dev/null || { echo "WirePlumber isn't installed, so this rule would do nothing." >&2; exit 1; }
    v=$(wireplumber --version | sed -n 's/.*libwireplumber //p' | head -1)
    if [ -n "$v" ] && [ "$(printf '%s\n0.5\n' "$v" | sort -V | head -1)" != "0.5" ]; then
        echo "WirePlumber $v doesn't read .conf rules (0.5 or later does), so this rule would do nothing." >&2
        exit 1
    fi
}

cmd=${1:-}
restart=1
[ "${2:-}" = "--no-restart" ] && restart=0
case $cmd in
    print)
        generate
        ;;
    install)
        check_version
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' EXIT
        generate >"$tmp"
        as_root mkdir -p "$CONF_DIR"
        as_root install -m 644 "$tmp" "$CONF"
        echo "Wrote $CONF"
        [ $restart -eq 0 ] || restart_audio
        echo "Reopen OBS and look in the Audio Input Capture device list."
        ;;
    uninstall)
        as_root rm -f "$CONF"
        echo "Removed $CONF"
        [ $restart -eq 0 ] || restart_audio
        ;;
    *)
        sed -n '2,13p' "$0" >&2
        exit 2
        ;;
esac
