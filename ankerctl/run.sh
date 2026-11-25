#!/bin/sh
# Home Assistant app wrapper around ankerctl (Go rewrite).
# Everything ankerctl stores (Anker login, printer keys, SQLite history,
# timelapses) lives under /data, so it survives updates and is in HA backups.
set -eu

OPTIONS=/data/options.json
opt() { jq -r "$1 // empty" "$OPTIONS"; }

log() { echo "[ankerctl-app] $*"; }

# --- persistent config for the ankerctl user --------------------------------
# ankerctl uses /home/ankerctl/.ankerctl (from the user's passwd entry, not
# $HOME), which is inside the container and would be lost on every update.
mkdir -p /data/config /data/captures /data/logs
chown -R ankerctl:ankerctl /data/config /data/captures /data/logs
chmod 700 /data/config
rm -rf /home/ankerctl/.ankerctl
ln -s /data/config /home/ankerctl/.ankerctl

# Session secret: generated once, so logins in the web UI survive restarts.
if [ ! -s /data/session_secret ]; then
    (umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > /data/session_secret)
fi
FLASK_SECRET_KEY="$(cat /data/session_secret)"
export FLASK_SECRET_KEY

# --- web server --------------------------------------------------------------
export ANKERCTL_HOST=0.0.0.0
ANKERCTL_PORT="$(opt .port)"
export ANKERCTL_PORT
UPLOAD_RATE_MBPS="$(opt .upload_rate_mbps)"
export UPLOAD_RATE_MBPS
TIMELAPSE_ENABLED="$(opt .timelapse)"
export TIMELAPSE_ENABLED
export TIMELAPSE_CAPTURES_DIR=/data/captures

API_KEY="$(opt .api_key)"
if [ -n "$API_KEY" ]; then
    export ANKERCTL_API_KEY="$API_KEY"
    log "API key set: write operations need it"
else
    log "No API key: anyone on the LAN can send prints and G-code"
fi

# --- Home Assistant MQTT discovery ------------------------------------------
if [ "$(opt .ha_mqtt)" = "true" ]; then
    MQTT="$(curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mqtt 2>/dev/null || true)"
    if [ -n "$MQTT" ] && [ "$(echo "$MQTT" | jq -r '.result')" = "ok" ]; then
        export HA_MQTT_ENABLED=true
        HA_MQTT_HOST="$(echo "$MQTT" | jq -r '.data.host')"
        HA_MQTT_PORT="$(echo "$MQTT" | jq -r '.data.port')"
        HA_MQTT_USER="$(echo "$MQTT" | jq -r '.data.username // empty')"
        HA_MQTT_PASSWORD="$(echo "$MQTT" | jq -r '.data.password // empty')"
        export HA_MQTT_HOST HA_MQTT_PORT HA_MQTT_USER HA_MQTT_PASSWORD
        log "MQTT discovery on ${HA_MQTT_HOST}:${HA_MQTT_PORT}"
    else
        log "ha_mqtt is on, but there is no MQTT broker app (install Mosquitto): discovery off"
    fi
fi

log "Starting ankerctl web server on port ${ANKERCTL_PORT}"
exec /app/entrypoint.sh ankerctl webserver --listen "0.0.0.0:${ANKERCTL_PORT}"
