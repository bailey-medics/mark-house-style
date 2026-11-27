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

    # A checkout to pull, with its own pretend GitHub, so the real one is
    # never touched.
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
    ORIGIN="${BATS_TEST_TMPDIR}/origin.git"
    export TURVA_NOTIFY_HOUSE="${BATS_TEST_TMPDIR}/house"
    git init -q --bare -b main "${ORIGIN}"
    git clone -q "${ORIGIN}" "${TURVA_NOTIFY_HOUSE}" 2>/dev/null
    echo one >"${TURVA_NOTIFY_HOUSE}/file"
    git -C "${TURVA_NOTIFY_HOUSE}" add file
    git -C "${TURVA_NOTIFY_HOUSE}" commit -q -m one
    git -C "${TURVA_NOTIFY_HOUSE}" push -q -u origin main 2>/dev/null
}

# A commit on the pretend GitHub that the checkout hasn't got.
commit_on_github() {
    local other="${BATS_TEST_TMPDIR}/other"

    git clone -q "${ORIGIN}" "${other}" 2>/dev/null
    echo "$1" >"${other}/file"
    git -C "${other}" commit -q -am "$1"
    git -C "${other}" push -q 2>/dev/null
}

@test "it pulls first, then rebuilds from the new copy" {
    commit_on_github two

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(cat "${TURVA_NOTIFY_HOUSE}/file")" = "two" ]
    [[ "$output" == *"mark-house-style is at: "*" two"* ]]
    grep -qx "build quill" "$CALLS"
}

@test "with changes made here, nothing is pulled or rebuilt" {
    commit_on_github two
    echo mine >"${TURVA_NOTIFY_HOUSE}/file"

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"changes here that aren't committed"* ]]
    [ "$(cat "${TURVA_NOTIFY_HOUSE}/file")" = "mine" ]
    [ ! -e "$CALLS" ]
}

@test "gone a different way from GitHub, nothing is pulled or rebuilt" {
    commit_on_github two
    echo local >"${TURVA_NOTIFY_HOUSE}/file"
    git -C "${TURVA_NOTIFY_HOUSE}" commit -q -am local

    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"gone a different way from GitHub"* ]]
    [ ! -e "$CALLS" ]
}

@test "with GitHub out of reach, it rebuilds from the copy it has" {
    git -C "${TURVA_NOTIFY_HOUSE}" remote set-url origin "${BATS_TEST_TMPDIR}/nowhere.git"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Couldn't reach GitHub"* ]]
    grep -qx "build quill" "$CALLS"
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

@test "off a Mac it fails and says to run it on the Mac" {
    FAKE_SYSTEM=Linux run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"not the Mac"* ]]
    [[ "$output" == *"just -g rfb"* ]]
    [ ! -e "$CALLS" ]
}
