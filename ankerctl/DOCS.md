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
| `printer_ip` | Optional; the printer's fixed IP. The PPPP handshake then goes straight to it (unicast) instead of as a broadcast, so it can cross a VPN or routed subnet. See "Printer in another subnet". |
| `cors_origins` | Optional; comma-separated exact origins (`http://<ha-ip>:8123`) that may call the API from a browser, e.g. a dashboard served by Home Assistant. Patched binary (`cors.sh`); empty = no CORS, as upstream. |
| `debug` | Optional; starts ankerctl with `--dev`: debug logging and `/api/debug/*` (services, video stats, PPPP reconnect). Troubleshooting only. |

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
- The camera only streams while something watches `/ws/video` (the web UI does). Without
  one, `/api/camera/frame` waits and fails, and `pppp_connected` stays off: ankerctl opens
  PPPP on demand.

## Printer in another subnet (VPN)

Measured with an M5 behind an OpenVPN server on the router (25-11-2026):

- The printer answers a unicast LanSearch, but only from its own subnet. From a VPN
  address it stays silent, so the router must masquerade VPN traffic to the printer.
- It answers from another UDP port than 32108, to the masqueraded address. For the router
  that is a new flow to itself, so it also needs a DNAT of `printer → router:32108` to the
  VPN address of the Home Assistant host.

```
iptables -t nat -I POSTROUTING 2 -s <vpn-subnet> -d <printer-ip>/32 -o br0 -j MASQUERADE
iptables -t nat -I PREROUTING -i br0 -s <printer-ip>/32 -d <router-lan-ip>/32 -p udp --dport 32108 -j DNAT --to-destination <ha-vpn-ip>
```

On stock Asus firmware such rules vanish on a reboot; re-apply them from Home Assistant
(SSH key + `shell_command` on a timer).
