#!/usr/bin/env bash
# Runs a tmux command that may start the server, for claude-session.sh and
# tmux-window.sh. Sourced, not run, so start_tmux is used by the script that
# sources it.
#
# Every session on the box lives in one tmux server, and the server belongs
# to whatever first asked it for a session. systemd ends everything a
# service started when that service stops. So a server first asked for from
# VS Code's terminal would belong to the tunnel's service, and a restart of
# the tunnel would close every session on the box, and every Claude in them.
#
# So when no server is running, start_tmux starts it as a transient systemd
# service of its own, tmux-server, as the boot scripts do. A service
# rather than a scope, because the user manager starts a service itself, so
# the server inherits nothing from the service that asked.

readonly TMUX_UNIT="tmux-server"

# How many fifths of a second to wait for another starter's server.
readonly TMUX_WAIT_TRIES="${TMUX_WAIT_TRIES:-25}"

# A server already running only needs asking, so tmux runs as it is. It
# does too where there is no systemd-run, as on a Mac.
#
# systemd refuses a unit name already in use. At boot several scripts start
# sessions at the same moment, so the starter that loses waits for the
# winner's server, then asks it.
start_tmux() {
    if ! command -v systemd-run > /dev/null 2>&1 || tmux list-sessions > /dev/null 2>&1; then
        tmux "$@"
        return
    fi

    if systemd-run --user --quiet --collect --unit="${TMUX_UNIT}" \
        --property=Type=forking tmux "$@"; then
        return
    fi

    local try

    for ((try = 0; try < TMUX_WAIT_TRIES; try++)); do
        sleep 0.2
        if tmux list-sessions > /dev/null 2>&1; then
            tmux "$@"
            return
        fi
    done

    echo "✗ No tmux server came up, in ${TMUX_UNIT}.service or out of it." >&2
    return 1
}
