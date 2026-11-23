#!/usr/bin/env bash
# Opens a 10 minute test window: starts the bridge on loopback, and the
# named Cloudflare tunnel in front of it, then prints the address to add
# in claude.ai as a custom connector. Both stop after 10 minutes, or on
# Ctrl+C. The bridge needs the login that scripts/voice-init.ts makes, and
# will not start without one. See the voice bridge build plan.
#
# The tunnel's host name is read from a file outside the repository, so
# it is never in a commit. The name stays in DNS when the window closes,
# but nothing answers at it.
#
# VOICE_WINDOW_NO_SESSION=1 opens the window with no voice session
# running. That is for checking what reaches the bridge's log; ask then
# answers with an error.

set -euo pipefail

readonly WINDOW_SECONDS="${VOICE_WINDOW_SECONDS:-600}"
readonly PORT="${VOICE_BRIDGE_PORT:-8787}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly HERE
readonly SOCKET="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/voice-channel/channel.sock"
readonly TUNNEL_NAME="voice"
readonly HOST_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/voice-bridge/host"

if [ "${VOICE_WINDOW_NO_SESSION:-0}" != "1" ] && [ ! -S "${SOCKET}" ]; then
    echo "No voice channel is running (no ${SOCKET}). Start the test session first." >&2
    exit 1
fi

if [ ! -r "${HOST_FILE}" ]; then
    echo "No tunnel host name (no ${HOST_FILE}). Set up the named tunnel first." >&2
    exit 1
fi

host="$(head -n 1 "${HOST_FILE}" | tr -d '[:space:]')"
if [[ ! "${host}" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]]; then
    echo "${HOST_FILE} does not hold a host name." >&2
    exit 1
fi

if ! command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared is not installed." >&2
    exit 1
fi

work="$(mktemp -d "${XDG_RUNTIME_DIR}/voice-window.XXXXXX")"
bridge_pid=""
tunnel_pid=""

stop() {
    [ -n "${tunnel_pid}" ] && kill "${tunnel_pid}" 2>/dev/null || true
    [ -n "${bridge_pid}" ] && kill "${bridge_pid}" 2>/dev/null || true
    wait 2>/dev/null || true
    rm -rf "${work}"
    echo "Window closed: the tunnel and the bridge have stopped."
}
trap stop EXIT
trap 'exit 130' INT TERM HUP QUIT

# The bridge runs under timeout as well as the tunnel, a minute longer, so
# neither can outlive the window even if this script is killed outright.
VOICE_BRIDGE_PORT="${PORT}" timeout "$((WINDOW_SECONDS + 60))" node "${HERE}/src/bridge-main.ts" \
    2> >(tee "${work}/bridge.log" >&2) &
bridge_pid=$!

# The bridge stops at once when there is no usable login, and says why.
# The tunnel must not open in front of nothing.
listening=""
for _ in $(seq 1 20); do
    if grep -q "bridge listening" "${work}/bridge.log" 2>/dev/null; then
        listening="yes"
        break
    fi

    if ! kill -0 "${bridge_pid}" 2>/dev/null; then
        break
    fi
    sleep 0.5
done

if [ -z "${listening}" ]; then
    echo "The bridge did not start, so the window stays shut." >&2
    exit 1
fi

timeout "${WINDOW_SECONDS}" cloudflared tunnel --no-autoupdate run --url "http://127.0.0.1:${PORT}" "${TUNNEL_NAME}" \
    > "${work}/tunnel.log" 2>&1 &
tunnel_pid=$!

connected=""
for _ in $(seq 1 60); do
    if grep -q "Registered tunnel connection" "${work}/tunnel.log"; then
        connected="yes"
        break
    fi

    if ! kill -0 "${tunnel_pid}" 2>/dev/null; then
        echo "cloudflared stopped before the tunnel connected:" >&2
        cat "${work}/tunnel.log" >&2
        exit 1
    fi

    if ! kill -0 "${bridge_pid}" 2>/dev/null; then
        echo "The bridge stopped, so the window is closing." >&2
        exit 1
    fi
    sleep 1
done

if [ -z "${connected}" ]; then
    echo "The tunnel did not connect within a minute." >&2
    exit 1
fi

echo ""
echo "Connector address, open for $((WINDOW_SECONDS / 60)) minutes:"
echo ""
echo "    https://${host}/mcp"
echo ""
echo "Add it in claude.ai as a custom connector: choose No sign-in, and give it the"
echo "request header that voice-init printed. Ctrl+C closes the window early."
echo ""

wait "${tunnel_pid}" || true
