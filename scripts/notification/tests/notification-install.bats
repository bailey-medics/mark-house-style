#!/usr/bin/env bats
# Tests for the Mac's two installers: notification-listen-install.sh, which
# sets up the SSH listener and retires Quill Medical's old one, and
# notification-relay-install.sh, which builds the banner relay. uname,
# launchctl, id, sleep, npm and code are stand-ins, and HOME is the test's
# own folder, so nothing on the real machine is touched.

bats_require_minimum_version 1.5.0

setup() {
    LISTEN="${BATS_TEST_DIRNAME}/../notification-listen-install.sh"
    RELAY="${BATS_TEST_DIRNAME}/../notification-relay-install.sh"
    STUBS="${BATS_TEST_TMPDIR}/stubs"
    SUPPORT="${BATS_TEST_TMPDIR}/home/Library/Application Support"
    AGENTS="${BATS_TEST_TMPDIR}/home/Library/LaunchAgents"
    QUILL="com.quill-medical.notify-listen"
    export CALLS="${BATS_TEST_TMPDIR}/calls"
    export LOADED="${BATS_TEST_TMPDIR}/loaded"
    export HOME="${BATS_TEST_TMPDIR}/home"
    export FAKE_SYSTEM=Darwin
    export TURVA_NOTIFY_CODE="${STUBS}/code"

    mkdir -p "${STUBS}" "${SUPPORT}" "${AGENTS}" "${LOADED}"

    cat >"${STUBS}/uname" <<'EOF'
#!/bin/sh
echo "$FAKE_SYSTEM"
EOF
    cat >"${STUBS}/id" <<'EOF'
#!/bin/sh
echo 501
EOF
    cat >"${STUBS}/sleep" <<'EOF'
#!/bin/sh
exit 0
EOF
    # An agent is loaded while a file of its name is in $LOADED. bootout
    # unloads it, unless FAKE_BOOTOUT_STUCK is 1.
    cat >"${STUBS}/launchctl" <<'EOF'
#!/bin/sh
echo "launchctl $*" >>"$CALLS"
case "$1" in
    print) [ -e "$LOADED/$(basename "$2")" ] ;;
    bootout)
        [ "${FAKE_BOOTOUT_STUCK:-0}" = 1 ] && exit 1
        rm -f "$LOADED/$(basename "$2")"
        ;;
esac
EOF
    cat >"${STUBS}/npm" <<'EOF'
#!/bin/sh
echo "npm $*" >>"$CALLS"
EOF
    cat >"${STUBS}/code" <<'EOF'
#!/bin/sh
echo "code $*" >>"$CALLS"
EOF
    chmod +x "${STUBS}"/*

    export PATH="${STUBS}:${PATH}"
}

# What Quill Medical's installer left on the Mac: its agent file and its
# folder of scripts.
quill_files() {
    mkdir -p "${SUPPORT}/quill-notify"
    echo old >"${SUPPORT}/quill-notify/notification-show.sh"
    echo old >"${AGENTS}/${QUILL}.plist"
}

@test "off a Mac the listener install fails and says to run it on the Mac" {
    FAKE_SYSTEM=Linux run "$LISTEN"

    [ "$status" -eq 1 ]
    [[ "$output" == *"not the Mac"* ]]
    [[ "$output" == *"just -g nli"* ]]
    [ ! -e "$CALLS" ]
    [ ! -e "${SUPPORT}/turva-notify" ]
}

@test "with no Quill listener, this repository's is installed and started" {
    run "$LISTEN"

    [ "$status" -eq 0 ]
    [ -x "${SUPPORT}/turva-notify/notification-listen.sh" ]
    [ -x "${SUPPORT}/turva-notify/notification-dismiss.sh" ]
    grep -qF "${SUPPORT}/turva-notify/notification-listen.sh" "${AGENTS}/com.turva.notify-listen.plist"
    grep -qxF "launchctl bootstrap gui/501 ${AGENTS}/com.turva.notify-listen.plist" "$CALLS"
    [[ "$output" != *"Retired"* ]]
}

@test "Quill's running listener is stopped and its files deleted before this one starts" {
    quill_files
    touch "${LOADED}/${QUILL}"

    run "$LISTEN"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Retired Quill Medical's old banner listener"* ]]
    [ ! -e "${LOADED}/${QUILL}" ]
    [ ! -e "${AGENTS}/${QUILL}.plist" ]
    [ ! -e "${SUPPORT}/quill-notify" ]
    [ -e "${AGENTS}/com.turva.notify-listen.plist" ]
    [ "$(grep -nxF "launchctl bootout gui/501/${QUILL}" "$CALLS" | cut -d: -f1)" -lt "$(grep -n "^launchctl bootstrap " "$CALLS" | cut -d: -f1)" ]
}

@test "Quill's leftover files are deleted when its listener is not loaded" {
    quill_files

    run "$LISTEN"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Retired Quill Medical's old banner listener"* ]]
    [ ! -e "${AGENTS}/${QUILL}.plist" ]
    [ ! -e "${SUPPORT}/quill-notify" ]
    run ! grep -qF "launchctl bootout gui/501/${QUILL}" "$CALLS"
}

@test "a Quill listener that will not stop leaves everything as it was" {
    quill_files
    touch "${LOADED}/${QUILL}"

    FAKE_BOOTOUT_STUCK=1 run "$LISTEN"

    [ "$status" -eq 1 ]
    [[ "$output" == *"would not stop"* ]]
    [ -e "${AGENTS}/${QUILL}.plist" ]
    [ -e "${SUPPORT}/quill-notify/notification-show.sh" ]
    [ ! -e "${SUPPORT}/turva-notify" ]
    run ! grep -q "^launchctl bootstrap " "$CALLS"
}

@test "off a Mac the relay install fails and says to run it on the Mac" {
    FAKE_SYSTEM=Linux run "$RELAY"

    [ "$status" -eq 1 ]
    [[ "$output" == *"not the Mac"* ]]
    [[ "$output" == *"just -g nri"* ]]
    [ ! -e "$CALLS" ]
    [ ! -e "${SUPPORT}/banner-relay" ]
}

@test "on the Mac the relay's scripts are copied and its extension built and installed" {
    local relay_dir

    relay_dir="$(cd "${BATS_TEST_DIRNAME}/../vscode-relay" && pwd)"

    run "$RELAY"

    [ "$status" -eq 0 ]
    [ -x "${SUPPORT}/banner-relay/notification-dismiss.sh" ]
    cmp -s "${BATS_TEST_DIRNAME}/../notification-show.sh" "${SUPPORT}/banner-relay/notification-show.sh"
    grep -qxF "npm run package" "$CALLS"
    grep -qxF "code --install-extension ${relay_dir}/banner-relay.vsix --force" "$CALLS"
}
