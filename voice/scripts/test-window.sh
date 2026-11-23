#!/usr/bin/env bash
# Opens the 10 minute test window: starts the bridge on loopback with a
# fresh secret path, and the named Cloudflare tunnel in front of it, then
# prints the address to add in claude.ai as a custom connector. Both stop
# after 10 minutes, or on Ctrl+C. No login: this is for the Phase 3 test
# only. See the voice bridge build plan.
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
secret="$(node -e 'process.stdout.write(require("node:crypto").randomBytes(16).toString("hex"))')"
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
trap 'exit 130' INT TERM

VOICE_BRIDGE_PATH_SECRET="${secret}" VOICE_BRIDGE_PORT="${PORT}" \
    node "${HERE}/src/bridge-main.ts" 2> >(tee "${work}/bridge.log" >&2) &
bridge_pid=$!

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
    sleep 1
done

if [ -z "${connected}" ]; then
    echo "The tunnel did not connect within a minute." >&2
    exit 1
fi

echo ""
echo "Connector address, open for $((WINDOW_SECONDS / 60)) minutes:"
echo ""
echo "    https://${host}/${secret}/mcp"
echo ""
echo "Add it in claude.ai as a custom connector with no sign in. Ctrl+C closes the window early."
echo ""

wait "${tunnel_pid}" || true
