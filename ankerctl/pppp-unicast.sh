#!/bin/sh
# Patch for ankerctl 1.0.3: send the PPPP LanSearch handshake straight to the
# printer's known IP instead of to 255.255.255.255.
#
# Upstream always broadcasts ("the printer only responds to broadcast
# LanSearch, not unicast"). An M5 does answer a unicast LanSearch on
# UDP 32108 with a PunchPkt (verified 25-11-2026), and a broadcast never
# crosses a VPN or a routed subnet. With ANKERCTL_PPPP_UNICAST=1 and a printer
# ip_addr in the config, the handshake is unicast; without either, nothing
# changes.
set -eu
F=internal/service/pppp.go

grep -q 'cli, err := ppppclient.OpenBroadcastLAN(duid)' "$F"
sed -i 's|cli, err := ppppclient.OpenBroadcastLAN(duid)|cli, err := openLANHandshake(duid, printer.IPAddr)|' "$F"
sed -i 's|^\t"net"$|\t"net"\n\t"os"|' "$F"

cat >> "$F" <<'EOF'

// openLANHandshake opens the LAN client for the LanSearch handshake: unicast
// to the known printer IP when ANKERCTL_PPPP_UNICAST=1, broadcast otherwise.
// Bound to PPPPLANPort either way, like OpenBroadcastLAN.
func openLANHandshake(duid protocol.Duid, ip string) (*ppppclient.Client, error) {
	if ip != "" && os.Getenv("ANKERCTL_PPPP_UNICAST") == "1" {
		slog.Info("ppppservice: unicast LanSearch to known IP", "ip", ip)
		return ppppclient.Open(duid, ip, ppppclient.PPPPLANPort, ppppclient.PPPPLANPort)
	}
	return ppppclient.OpenBroadcastLAN(duid)
}
EOF

grep -q 'openLANHandshake(duid, printer.IPAddr)' "$F"
grep -q '^	"os"$' "$F"
echo "pppp-unicast patch applied"
