# SDRconnect server (SDRplay)

Runs [SDRconnect](https://sdrplay.com/sdrconnect/) by SDRplay as a **server** next to
Home Assistant, for an SDRplay RSP on a USB port of the Home Assistant machine. You
listen and tune from SDRconnect on another computer (Windows, macOS or Linux) that
connects to this server over the network. One machine, no separate operating system.

SDRconnect is closed-source software of SDRplay Limited. It is not part of this
repository: the app downloads it from sdrplay.com while it is built and checks the
SHA-256 that SDRplay publishes.

## Requirements

- An SDRplay RSP (all models except the RSP1; SDRconnect only works with SDRplay hardware).
- Home Assistant OS on amd64 (x86-64) or aarch64 (64-bit ARM).
- CPU headroom: SDRconnect demodulates on the server. A wide bandwidth on a weak CPU
  also slows Home Assistant down, since an app has no CPU limit.

## Setup

1. Plug the RSP into the Home Assistant machine.
2. Install this app. The build downloads ~125 MB from sdrplay.com.
3. Read the SDRplay licence (the app log shows it on the first start). If you accept it,
   set `accept_licence` to `true` and start the app.
4. The log shows how many SDRplay devices it sees on USB.
5. On your computer, open SDRconnect and connect to the server at the IP address of the
   Home Assistant machine.

## Options

| Option | Meaning |
|---|---|
| `accept_licence` | You accept the SDRplay end user licence. Without it the app does not start. |
| `extra_args` | Extra command-line arguments for `SDRconnect --server`. Normally empty. |

## Notes

- Settings of SDRconnect are kept in the app's `/data`, so they survive updates and are
  part of Home Assistant backups.
- Per the licence (section 6) SDRconnect may send details of the radio to an SDRplay server
  and check for firmware updates.
- Updating SDRconnect: a new release has a new build id and checksums in the `Dockerfile`
  (`SDRCONNECT_BUILD`, `SDRCONNECT_SHA256_*`, from https://www.sdrplay.com/software/install.sh)
  and a new app version.
