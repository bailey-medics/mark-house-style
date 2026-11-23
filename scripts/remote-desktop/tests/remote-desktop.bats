#!/usr/bin/env bats
# Tests for remote-desktop, the switch between Chrome Remote Desktop and RDP.
#
# systemctl, systemd-run, pkill, pgrep, id, sleep and getent are stubs on PATH that record
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

    for tool in systemctl systemd-run pkill pgrep sleep; do
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
    [[ "$output" == *"usage: remote-desktop google|windows|off|kill|status"* ]]
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

@test "google stops the tunnel, ends the RDP desktop, then starts Chrome Remote Desktop" {
    run "$SCRIPT" google

    [ "$status" -eq 0 ]
    grep -q "^systemctl --user -M dev@ stop devtunnel-desktop.service$" "$CALLS"
    grep -q "^pkill -u dev -f ^/usr/lib/xorg/Xorg :1\[0-9\] .*xrdp/xorg" "$CALLS"
    grep -q "^systemctl start chrome-remote-desktop@dev$" "$CALLS"
    [ "$(grep -n pkill "$CALLS" | cut -d: -f1)" -lt "$(grep -n 'start chrome-remote-desktop' "$CALLS" | cut -d: -f1)" ]
}

@test "windows stops Chrome Remote Desktop and starts RDP and the tunnel host" {
    run "$SCRIPT" windows

    [ "$status" -eq 0 ]
    grep -q "^systemctl disable --quiet --now chrome-remote-desktop@dev$" "$CALLS"
    grep -q "^systemctl start xrdp-sesman xrdp$" "$CALLS"
    grep -q "^systemctl --user -M dev@ start devtunnel-desktop.service$" "$CALLS"
    ! grep -q "^pkill" "$CALLS"
}

@test "off stops the tunnel and Chrome Remote Desktop, and leaves the RDP desktop" {
    run "$SCRIPT" off

    [ "$status" -eq 0 ]
    grep -q "^systemctl --user -M dev@ stop devtunnel-desktop.service$" "$CALLS"
    grep -q "^systemctl disable --quiet --now chrome-remote-desktop@dev$" "$CALLS"
    ! grep -q "^pkill" "$CALLS"
    ! grep -qE " start " "$CALLS"
}

@test "no mode makes anything start at boot" {
    for mode in google windows off kill status; do
        run "$SCRIPT" "$mode"
        [ "$status" -eq 0 ]
    done

    ! grep -qE "(^| )enable( |$)" "$CALLS"
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

@test "windows sets the automatic off for 12 hours by default" {
    run "$SCRIPT" windows

    [ "$status" -eq 0 ]
    grep -q "^systemd-run --quiet --collect --unit=remote-desktop-auto-off --on-active=12h --setenv=SUDO_USER=dev /usr/local/sbin/remote-desktop off$" "$CALLS"
    [[ "$output" == *"Automatic off: in 12 hours"* ]]
}

@test "google sets the automatic off too" {
    run "$SCRIPT" google

    [ "$status" -eq 0 ]
    grep -q "^systemd-run .*--on-active=12h .*/usr/local/sbin/remote-desktop off$" "$CALLS"
}

@test "switching on again cancels the old automatic off before setting a new one" {
    run "$SCRIPT" windows

    [ "$(grep -n 'stop remote-desktop-auto-off.timer' "$CALLS" | cut -d: -f1)" -lt "$(grep -n '^systemd-run' "$CALLS" | cut -d: -f1)" ]
}

@test "the hours come from the settings file" {
    echo "AUTO_OFF_HOURS=4" > "${FAKE_HOME}/.config/remote-desktop/config"

    run "$SCRIPT" windows

    grep -q -- "--on-active=4h " "$CALLS"
}

@test "AUTO_OFF_HOURS=0 means never, so no timer is set" {
    echo "AUTO_OFF_HOURS=0" > "${FAKE_HOME}/.config/remote-desktop/config"

    run "$SCRIPT" windows

    [ "$status" -eq 0 ]
    ! grep -q "^systemd-run" "$CALLS"
    [[ "$output" == *"Automatic off: never"* ]]
}

@test "hours that are not a whole number from 0 to 168 fall back to 12" {
    for bad in '200' '-1' '1.5' '12; reboot' 'twelve'; do
        : > "$CALLS"
        printf 'AUTO_OFF_HOURS=%s\n' "$bad" > "${FAKE_HOME}/.config/remote-desktop/config"

        run "$SCRIPT" windows

        [ "$status" -eq 0 ]
        grep -q -- "--on-active=12h " "$CALLS"
        ! grep -q "reboot" "$CALLS"
    done
}

@test "off cancels the automatic off" {
    run "$SCRIPT" off

    [ "$status" -eq 0 ]
    grep -q "^systemctl stop remote-desktop-auto-off.timer$" "$CALLS"
    ! grep -q "^systemd-run" "$CALLS"
}

@test "kill stops the tunnel, both desktops and the RDP server, and cancels the automatic off" {
    run "$SCRIPT" kill

    [ "$status" -eq 0 ]
    grep -q "^systemctl stop remote-desktop-auto-off.timer$" "$CALLS"
    grep -q "^systemctl --user -M dev@ stop devtunnel-desktop.service$" "$CALLS"
    grep -q "^systemctl disable --quiet --now chrome-remote-desktop@dev$" "$CALLS"
    grep -q "^pkill -u dev -f ^/usr/lib/xorg/Xorg :1\[0-9\] .*xrdp/xorg" "$CALLS"
    grep -q "^systemctl disable --quiet --now xrdp xrdp-sesman$" "$CALLS"
    ! grep -q "^systemd-run" "$CALLS"
}

@test "kill ends the RDP desktop before stopping the RDP server" {
    run "$SCRIPT" kill

    [ "$(grep -n '^pkill' "$CALLS" | cut -d: -f1)" -lt "$(grep -n 'now xrdp xrdp-sesman' "$CALLS" | cut -d: -f1)" ]
}

@test "kill leaves the VS Code tunnel, Tailscale and SSH alone" {
    run "$SCRIPT" kill

    [ "$status" -eq 0 ]
    ! grep -qE "code-tunnel|tailscale|ssh" "$CALLS"
}

@test "off still leaves the RDP server and its desktop running" {
    run "$SCRIPT" off

    ! grep -qE "(stop|disable).*xrdp|^pkill" "$CALLS"
}
