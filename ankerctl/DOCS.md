# ankerctl (AnkerMake M5)

Wraps [ankerctl](https://github.com/Django1982/ankerctl_go_remake) (Go rewrite of
[ankermake-m5-protocol](https://github.com/Ankermgmt/ankermake-m5-protocol)): a web interface
and CLI to monitor and control an AnkerMake M5 without Anker's apps.

## Setup

1. Optional but recommended: install the **Mosquitto broker** app and the **MQTT** integration.
   This app then announces the printer to Home Assistant (state, temperatures, progress,
   light) via MQTT discovery. Credentials come from the Supervisor; nothing to fill in.
2. Start the app and open the web interface (port 4470).
3. On the Setup tab, log in with the AnkerMake account the printer belongs to. ankerctl
   fetches the printer and its keys from Anker's cloud and stores them under `/data`.

## Options

| Option | Meaning |
|---|---|
| `port` | Port of the web interface and the OctoPrint-compatible upload API. |
| `ha_mqtt` | MQTT discovery to Home Assistant (needs the Mosquitto app). |
| `timelapse` | Record a timelapse per print (`/data/captures`, uses ffmpeg). |
| `upload_rate_mbps` | Upload speed to the printer. |
| `api_key` | Optional; when set, uploads, G-code and printer control need it. Set one if the LAN is not trusted. |

## Workarounds in this app (ankerctl 1.0.3)

- The `HA_MQTT_*` environment variables only seed a new config. Once you log in, the
  `home_assistant` block in `default.json` wins (with `enabled: false` and an empty discovery
  prefix). On every start this app writes the Supervisor's broker credentials, `enabled: true`
  and prefix `homeassistant` into that block.
- Upstream registers the Home Assistant worker as `homeassistant` but auto-starts `ha`
  (`unknown service "ha"` in the log), so discovery never starts on boot. The app saves the
  MQTT settings once through the API after start-up, which restarts the worker.
- An empty prefix publishes discovery to `/sensor/...`; Home Assistant ignores that. If you
  ever see such retained topics, clear them with an empty retained message.

## Network

- **Status and commands** go through Anker's cloud MQTT broker (TCP 8789). No cloud, no status.
- **File upload and camera** use PPPP over UDP: directly on the LAN (ports 32100/32108), or
  via Anker's relay when the printer is not on the same LAN. `host_network` is required.
- The web interface has no login of its own: anyone who can reach port 4470 can see the
  printer. Keep the port off the internet, or set `api_key`.
