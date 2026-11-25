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

# --- fixed printer IP ---------------------------------------------------------
# ankerctl finds the printer with a LAN broadcast. That does not cross a VPN or
# a routed subnet; with a known IP it talks to the printer directly (unicast).
PRINTER_IP="$(opt .printer_ip)"
if [ -n "$PRINTER_IP" ] && [ -f /data/config/default.json ]; then
    jq --arg ip "$PRINTER_IP" '.printers |= (if (. | length) > 0 then (.[0].ip_addr = $ip) else . end)' \
        /data/config/default.json > /data/config/default.json.tmp \
        && mv /data/config/default.json.tmp /data/config/default.json
    chown ankerctl:ankerctl /data/config/default.json
    chmod 600 /data/config/default.json
    # patched binary: handshake goes straight to this IP (pppp-unicast.sh)
    export ANKERCTL_PPPP_UNICAST=1
    log "Printer IP fixed at ${PRINTER_IP} (unicast PPPP handshake)"
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
        # host_network apps do not always resolve the internal app hostnames;
        # the Mosquitto app publishes 1883 on the host, so localhost works too.
        if ! getent hosts "$HA_MQTT_HOST" >/dev/null 2>&1; then
            HA_MQTT_HOST=127.0.0.1
        fi
        export HA_MQTT_HOST HA_MQTT_PORT HA_MQTT_USER HA_MQTT_PASSWORD
        # The env vars only seed a NEW config: once default.json exists (after
        # the Anker login) its home_assistant block wins. Write ours into it so
        # the broker credentials from the Supervisor are actually used.
        CFG=/data/config/default.json
        if [ -f "$CFG" ]; then
            jq --arg h "$HA_MQTT_HOST" --arg p "$HA_MQTT_PORT" --arg u "$HA_MQTT_USER" --arg pw "$HA_MQTT_PASSWORD" \
                '.home_assistant = ((.home_assistant // {}) + {enabled: true, mqtt_host: $h, mqtt_port: ($p|tonumber),
                  mqtt_username: $u, mqtt_password: $pw,
                  discovery_prefix: ((.home_assistant.discovery_prefix // "") | if . == "" then "homeassistant" else . end)})' \
                "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
            chown ankerctl:ankerctl "$CFG"
            chmod 600 "$CFG"
        fi
        log "MQTT discovery on ${HA_MQTT_HOST}:${HA_MQTT_PORT}"
    else
        log "ha_mqtt is on, but there is no MQTT broker app (install Mosquitto): discovery off"
    fi
fi

log "Starting ankerctl web server on port ${ANKERCTL_PORT}"

if [ "${HA_MQTT_ENABLED:-false}" != "true" ]; then
    exec /app/entrypoint.sh ankerctl webserver --listen "0.0.0.0:${ANKERCTL_PORT}"
fi

# Upstream 1.0.3 registers the Home Assistant worker as "homeassistant" but
# auto-starts "ha" ("unknown service"), so discovery never starts on boot.
# Saving the MQTT settings once through the API restarts the worker; the
# credentials are already in default.json, so only "enabled" is sent.
/app/entrypoint.sh ankerctl webserver --listen "0.0.0.0:${ANKERCTL_PORT}" &
CHILD=$!
trap 'kill -INT "$CHILD" 2>/dev/null; wait "$CHILD"; exit 0' INT TERM

i=0
until curl -fsS "http://127.0.0.1:${ANKERCTL_PORT}/api/health" >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 60 ] || ! kill -0 "$CHILD" 2>/dev/null; then break; fi
    sleep 1
done
if curl -fsS -X POST -H "Content-Type: application/json" ${API_KEY:+-H "X-Api-Key: $API_KEY"} \
        -d '{"enabled": true}' "http://127.0.0.1:${ANKERCTL_PORT}/api/settings/mqtt" >/dev/null 2>&1; then
    log "Home Assistant discovery started"
else
    log "Could not start Home Assistant discovery through the API (no printer configured yet?)"
fi

wait "$CHILD"
