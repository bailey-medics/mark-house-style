#!/usr/bin/env bats
# Tests for remote-desktop, the switch between Chrome Remote Desktop and RDP.
#
# systemctl, pkill, pgrep, id, sleep and getent are stubs on PATH that record
# each call, so nothing here touches the real services or desktops. getent
# gives the account "dev" a home in the test's own folder.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../remote-desktop"
    STUBS="${BATS_TEST_TMPDIR}/stubs"
    export CALLS="${BATS_TEST_TMPDIR}/calls"
    export FAKE_UID=0
    export SUDO_USER=dev

    mkdir -p "$STUBS"
    : > "$CALLS"

    for tool in systemctl pkill pgrep sleep; do
        printf '#!/bin/sh\necho "%s $*" >> "$CALLS"\n' "$tool" > "${STUBS}/${tool}"
    done

    export FAKE_HOME="${BATS_TEST_TMPDIR}/home"
    mkdir -p "${FAKE_HOME}/.config/remote-desktop"
    printf '#!/bin/sh\necho "dev:x:1000:1000::${FAKE_HOME}:/bin/bash"\n' > "${STUBS}/getent"

    # id -u gives the fake uid; id <name> knows only the account "dev".
    cat > "${STUBS}/id" <<'STUB'
#!/bin/sh
if [ "$1" = "-u" ]; then echo "$FAKE_UID"; exit 0; fi
[ "$1" = "dev" ]
STUB
    chmod +x "${STUBS}"/*

    export PATH="${STUBS}:${PATH}"
}

@test "an unknown mode prints the usage and changes nothing" {
    run "$SCRIPT" linux

    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: remote-desktop google|windows|status"* ]]
    [ ! -s "$CALLS" ]
}

@test "without root it asks for sudo and changes nothing" {
    FAKE_UID=1000 run "$SCRIPT" google

    [ "$status" -eq 1 ]
    [[ "$output" == *"Run with sudo: sudo remote-desktop google"* ]]
    [ ! -s "$CALLS" ]
}

@test "run as root directly, with no calling account, it refuses" {
    SUDO_USER= run "$SCRIPT" windows

    [ "$status" -eq 1 ]
    [[ "$output" == *"from your own account"* ]]
    [ ! -s "$CALLS" ]
}

@test "a calling account name that is not a plain user name is refused" {
    SUDO_USER='dev;reboot' run "$SCRIPT" google

    [ "$status" -eq 1 ]
    ! grep -q "systemctl enable" "$CALLS"
}

@test "google ends the RDP desktop, then starts Chrome Remote Desktop at boot and now" {
    run "$SCRIPT" google

    [ "$status" -eq 0 ]
    grep -q "^pkill -u dev -f ^/usr/lib/xorg/Xorg :1\[0-9\] .*xrdp/xorg" "$CALLS"
    grep -q "^systemctl enable --now chrome-remote-desktop@dev$" "$CALLS"
    [ "$(grep -n pkill "$CALLS" | cut -d: -f1)" -lt "$(grep -n 'enable --now' "$CALLS" | cut -d: -f1)" ]
}

@test "windows stops Chrome Remote Desktop and starts RDP and the tunnel host" {
    run "$SCRIPT" windows

    [ "$status" -eq 0 ]
    grep -q "^systemctl disable --now chrome-remote-desktop@dev$" "$CALLS"
    grep -q "^systemctl start xrdp-sesman xrdp$" "$CALLS"
    grep -q "^systemctl --user -M dev@ start devtunnel-desktop.service$" "$CALLS"
    ! grep -q "^pkill" "$CALLS"
}

@test "status only reads" {
    run "$SCRIPT" status

    [ "$status" -eq 0 ]
    [[ "$output" == *"Chrome Remote Desktop :"* ]]
    [[ "$output" == *"Dev tunnel host       :"* ]]
    ! grep -qE "enable --now|disable --now| start |^pkill" "$CALLS"
}

@test "windows prints the Mac's connect command with the tunnel's name" {
    echo "DEVTUNNEL_NAME=my-tunnel.1" > "${FAKE_HOME}/.config/remote-desktop/config"

    run "$SCRIPT" windows

    [ "$status" -eq 0 ]
    [[ "$output" == *"~/bin/devtunnel connect my-tunnel.1"* ]]
}

@test "a tunnel name that is not plain is never printed" {
    echo 'DEVTUNNEL_NAME=x; rm -rf ~' > "${FAKE_HOME}/.config/remote-desktop/config"

    run "$SCRIPT" windows

    [ "$status" -eq 0 ]
    [[ "$output" == *"~/bin/devtunnel connect <tunnel>"* ]]
    [[ "$output" != *"rm -rf"* ]]
}

@test "with no settings file the command shows a placeholder" {
    run "$SCRIPT" windows

    [ "$status" -eq 0 ]
    [[ "$output" == *"~/bin/devtunnel connect <tunnel>"* ]]
}
