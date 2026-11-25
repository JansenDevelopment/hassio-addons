# OpenVPN client (split tunnel)

Connects Home Assistant to an OpenVPN server and sends **only the networks you list**
through the tunnel. Everything else, including Home Assistant's own internet traffic and
DNS, keeps using the normal connection.

Made for reaching the LAN of another house whose router (for example an Asus) runs an
OpenVPN server that pushes `redirect-gateway` for its own roaming users. This app ignores
that, so Home Assistant does not send all its traffic through the other house.

## Setup

1. Export the client profile (`.ovpn`) from the OpenVPN server.
2. Put it in this app's config folder: on the Samba share that is
   `addon_configs/<slug>_openvpn_client/` (`local_openvpn_client` for a local install).
3. Set `config_file` to the file name, and `username`/`password` if the server asks for them.
4. List the remote networks under `routes` (CIDR, e.g. `192.168.31.0/24`).
5. Start the app and check the log for `Initialization Sequence Completed`.

## Options

| Option | Meaning |
|---|---|
| `config_file` | Name of the `.ovpn` file in the config folder. |
| `username`, `password` | Credentials for servers that use `auth-user-pass`. Stored by the Supervisor, written to a file inside the container with mode 600. |
| `routes` | Networks that go through the tunnel. |
| `ignore_pushed_routes` | Ignore all routes the server pushes, including `redirect-gateway` (`--route-nopull`). Default on. |
| `ignore_pushed_dns` | Ignore DNS servers the server pushes. Default on. |
| `verbosity` | OpenVPN log level, 0-6. |

## Pitfalls

- **Another route to the same network wins.** If the Tailscale app on this Home Assistant
  accepts a subnet route for the same LAN (`accept_routes`), Tailscale's policy routing
  takes precedence and this tunnel is never used. Turn `accept_routes` off, or stop
  advertising that subnet elsewhere.
- **Subnets must not overlap** with the local LAN or other VPNs.
- The `.ovpn` file contains the client keys: keep the config folder out of shared backups
  you do not trust.
