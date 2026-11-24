#!/usr/bin/env bats
# Tests for start-tmux.sh, which starts the tmux server in a service of its
# own when a command is the first to ask for a session.
#
# tmux is a stub that records what it was asked, so no tmux server is
# touched. A server is running when SERVER_RUNNING=1, or once the server-up
# file exists.
#
# systemd-run is a stub too: it records its options and runs the command
# after them. With NAME_TAKEN=1 it acts as if another starter took the
# service's name a moment before: it refuses, and that starter's server
# comes up, unless NO_OTHER_SERVER=1.

setup() {
    CALLS="${BATS_TEST_TMPDIR}/tmux-calls"
    SYSTEMD_RUN_CALLS="${BATS_TEST_TMPDIR}/systemd-run-calls"
    SERVER_UP="${BATS_TEST_TMPDIR}/server-up"
    STARTER="${BATS_TEST_TMPDIR}/starter"
    export TMUX_WAIT_TRIES=2
    unset SERVER_RUNNING NAME_TAKEN NO_OTHER_SERVER

    mkdir -p "${BATS_TEST_TMPDIR}/bin"

    cat > "${BATS_TEST_TMPDIR}/bin/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${CALLS}"
if [ "\$1" = "list-sessions" ]; then
    [ "\${SERVER_RUNNING:-}" = "1" ] || [ -e "${SERVER_UP}" ]
fi
EOF

    cat > "${BATS_TEST_TMPDIR}/bin/systemd-run" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${SYSTEMD_RUN_CALLS}"
if [ "\${NAME_TAKEN:-}" = "1" ]; then
    [ "\${NO_OTHER_SERVER:-}" = "1" ] || touch "${SERVER_UP}"
    echo "Unit tmux-server.service was already loaded" >&2
    exit 1
fi
while [ "\$#" -gt 0 ] && [ "\${1#--}" != "\$1" ]; do
    shift
done
exec "\$@"
EOF

    cat > "${STARTER}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "${BATS_TEST_DIRNAME}/../start-tmux.sh"
start_tmux "\$@"
EOF

    chmod +x "${BATS_TEST_TMPDIR}"/bin/* "${STARTER}"
    export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "with no server, the command starts the server in a service of its own" {
    run "$STARTER" new-session -d -s q3

    [ "$status" -eq 0 ]
    grep -qx -- "--user --quiet --collect --unit=tmux-server --property=Type=forking tmux new-session -d -s q3" "$SYSTEMD_RUN_CALLS"
    grep -qx "new-session -d -s q3" "$CALLS"
}

@test "a server already running is asked directly, with no service" {
    SERVER_RUNNING=1 run "$STARTER" new-session -d -s q3

    [ "$status" -eq 0 ]
    [ ! -e "$SYSTEMD_RUN_CALLS" ]
    grep -qx "new-session -d -s q3" "$CALLS"
}

@test "when another starter took the service's name, its server is waited for, then asked" {
    NAME_TAKEN=1 run "$STARTER" new-session -d -s q3

    [ "$status" -eq 0 ]
    grep -qx "new-session -d -s q3" "$CALLS"
}

@test "when no server comes up at all, it fails and says so" {
    NAME_TAKEN=1 NO_OTHER_SERVER=1 run "$STARTER" new-session -d -s q3

    [ "$status" -eq 1 ]
    [[ "$output" == *"No tmux server came up"* ]]
    [ "$(grep -c new-session "$CALLS")" -eq 0 ]
}
