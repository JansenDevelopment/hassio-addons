#!/usr/bin/with-contenv bashio
# OpenVPN client for Home Assistant OS that only routes the networks listed in
# the options through the tunnel. Typical use: reach the LAN of another house
# whose router runs an OpenVPN server that pushes "redirect-gateway" (all
# traffic through the tunnel) for its own roaming users.

set -e

CONFIG_DIR=/config
CONFIG_FILE="${CONFIG_DIR}/$(bashio::config 'config_file')"
AUTH_FILE=/tmp/openvpn-auth
VERBOSITY="$(bashio::config 'verbosity')"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    bashio::exit.nok "Profile not found: ${CONFIG_FILE}. Put the .ovpn file in the app's config folder (addon_configs/<slug>/ on the Samba share) and set 'config_file' to its name."
fi

# dotted netmask from a prefix length, e.g. 24 -> 255.255.255.0
prefix_to_mask() {
    local bits=$1 mask="" octet i
    for i in 1 2 3 4; do
        if (( bits >= 8 )); then octet=255; bits=$((bits - 8))
        elif (( bits > 0 )); then octet=$(( 256 - 2 ** (8 - bits) )); bits=0
        else octet=0
        fi
        mask+="${octet}"
        if (( i < 4 )); then mask+="."; fi
    done
    echo "${mask}"
}

args=(
    --config "${CONFIG_FILE}"
    --cd "${CONFIG_DIR}"
    --verb "${VERBOSITY}"
    # keep retrying forever: a router reboot or a new public IP must not leave
    # the app stopped
    --resolv-retry infinite
    --persist-key
    --persist-tun
    --auth-nocache
)

if bashio::config.has_value 'username'; then
    (
        umask 077
        printf '%s\n%s\n' "$(bashio::config 'username')" "$(bashio::config 'password')" > "${AUTH_FILE}"
    )
    args+=(--auth-user-pass "${AUTH_FILE}")
elif grep -qE '^[[:space:]]*auth-user-pass[[:space:]]*$' "${CONFIG_FILE}"; then
    bashio::exit.nok "The profile asks for a username and password: fill in 'username' and 'password' in the app configuration."
fi

if bashio::config.true 'ignore_pushed_routes'; then
    # drops every pushed route, including redirect-gateway; only the routes
    # below go through the tunnel
    args+=(--route-nopull)
fi

if bashio::config.true 'ignore_pushed_dns'; then
    args+=(--pull-filter ignore "dhcp-option" --pull-filter ignore "block-outside-dns")
fi

for cidr in $(bashio::config 'routes'); do
    net="${cidr%/*}"
    mask="$(prefix_to_mask "${cidr#*/}")"
    bashio::log.info "Route through the tunnel: ${net} ${mask}"
    args+=(--route "${net}" "${mask}")
done

bashio::log.info "Starting OpenVPN with profile $(bashio::config 'config_file')"
exec openvpn "${args[@]}"
