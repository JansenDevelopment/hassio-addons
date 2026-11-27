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
4. The log lists the SDRplay devices it finds. Without an RSP the server stops at once
   ("No streamable source found"); the app then tries again every 30 seconds, so plugging
   the RSP in later is enough.
5. On your computer, open SDRconnect and connect to the server at the IP address of the
   Home Assistant machine, port 50000 (TCP).

## Options

| Option | Meaning |
|---|---|
| `accept_licence` | You accept the SDRplay end user licence. Without it the app does not start. |
| `port` | TCP port the server listens on. Default 50000, SDRconnect's own default. |
| `extra_args` | Extra arguments for `SDRconnect --server`, e.g. `--max-clients=2`, `--hwser=<serial>`, `--samplerate=2000000`, `--antenna=1`, `--exclusive`. `--help` prints them all in the log. Normally empty. |

## Notes

- Tested on Home Assistant OS (amd64, Supervisor 2026.11) without an RSP: the image builds
  in under a minute, the server starts and waits for a device. Not yet tested with an RSP.
- The image is based on Ubuntu 24.04 (fixed in the `Dockerfile`): the Supervisor ignores
  `build_from` and would otherwise give the Alpine base.
- Settings of SDRconnect are kept in the app's `/data`, so they survive updates and are
  part of Home Assistant backups.
- Per the licence (section 6) SDRconnect may send details of the radio to an SDRplay server
  and check for firmware updates.
- Updating SDRconnect: a new release has a new build id and checksums in the `Dockerfile`
  (`SDRCONNECT_BUILD`, `SDRCONNECT_SHA256_*`, from https://www.sdrplay.com/software/install.sh)
  and a new app version.
