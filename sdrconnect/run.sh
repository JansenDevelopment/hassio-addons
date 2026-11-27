#!/bin/bash
# Home Assistant app wrapper around SDRconnect in server mode, as SDRplay's own
# systemd service runs it (install.sh: "/opt/sdrconnect/SDRconnect --server").
set -euo pipefail

OPTIONS=/data/options.json
opt() { jq -r "$1 // empty" "$OPTIONS"; }
log() { echo "[sdrconnect-app] $*"; }

# The SDRplay licence has to be accepted by the person who installs the app, not by us.
if [ "$(opt .accept_licence)" != "true" ]; then
    log "SDRconnect is licensed by SDRplay Limited. Read the licence below; to accept it,"
    log "set 'accept_licence' to true in the app configuration and start the app again."
    echo
    cat /opt/sdrconnect/LICENCE
    exit 1
fi

# SDRconnect keeps its settings in the home directory: put that in /data, so it
# survives updates and is part of Home Assistant backups.
mkdir -p /data/home
export HOME=/data/home
export XDG_CONFIG_HOME=/data/home/.config
export XDG_DATA_HOME=/data/home/.local/share

if ls /dev/bus/usb >/dev/null 2>&1; then
    rsp="$(grep -l '^1df7$' /sys/bus/usb/devices/*/idVendor 2>/dev/null | wc -l || true)"
    log "SDRplay devices on USB: ${rsp}"
else
    log "No USB bus visible in the container"
fi

EXTRA="$(opt .extra_args)"
log "Starting SDRconnect --server ${EXTRA}"
cd /opt/sdrconnect
# shellcheck disable=SC2086  # extra_args are meant to be split into words
exec ./SDRconnect --server ${EXTRA}
