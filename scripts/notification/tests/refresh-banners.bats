#!/usr/bin/env bats
# Tests for refresh-banners.sh, which rebuilds the icon apps and refreshes
# the Mac's copies of the banner scripts. uname, killall and the builder are
# stand-ins, and HOME is the test's own folder.

bats_require_minimum_version 1.5.0

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../refresh-banners.sh"
    STUBS="${BATS_TEST_TMPDIR}/stubs"
    SUPPORT="${BATS_TEST_TMPDIR}/home/Library/Application Support"
    export CALLS="${BATS_TEST_TMPDIR}/calls"
    export HOME="${BATS_TEST_TMPDIR}/home"
    export FAKE_SYSTEM=Darwin
    export TURVA_NOTIFY_BUILDER="${STUBS}/builder"

    mkdir -p "${STUBS}" "${SUPPORT}"

    cat >"${STUBS}/uname" <<'EOF'
#!/bin/sh
echo "$FAKE_SYSTEM"
EOF
    cat >"${STUBS}/killall" <<'EOF'
#!/bin/sh
echo "killall $*" >>"$CALLS"
EOF
    cat >"${STUBS}/builder" <<'EOF'
#!/bin/sh
echo "build $1" >>"$CALLS"
EOF
    chmod +x "${STUBS}"/*

    export PATH="${STUBS}:${PATH}"
}

@test "every icon in the repository is rebuilt" {
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    grep -qx "build quill" "$CALLS"
    grep -qx "build turva" "$CALLS"
    grep -qx "build juttu" "$CALLS"
}

@test "the notification services are restarted after the rebuild" {
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(tail -n 1 "$CALLS")" = "killall NotificationCenter usernoted" ]
}

@test "an installed relay gets fresh copies of the banner scripts" {
    mkdir -p "${SUPPORT}/banner-relay"
    echo old >"${SUPPORT}/banner-relay/notification-show.sh"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    cmp -s "${BATS_TEST_DIRNAME}/../notification-show.sh" "${SUPPORT}/banner-relay/notification-show.sh"
    [ -x "${SUPPORT}/banner-relay/notification-show.sh" ]
}

@test "a copy that is not installed is not created" {
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ ! -e "${SUPPORT}/banner-relay" ]
    [ ! -e "${SUPPORT}/turva-notify" ]
}

@test "the listener's own script is refreshed only where the listener is installed" {
    mkdir -p "${SUPPORT}/turva-notify"
    echo old >"${SUPPORT}/turva-notify/notification-listen.sh"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    cmp -s "${BATS_TEST_DIRNAME}/../notification-listen.sh" "${SUPPORT}/turva-notify/notification-listen.sh"
}

@test "off a Mac it does nothing" {
    FAKE_SYSTEM=Linux run "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to refresh"* ]]
    [ ! -e "$CALLS" ]
}
