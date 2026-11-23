#!/usr/bin/env bats
# Tests for build-notifier-app.sh, which builds a branded notifier app on a
# Mac. uname and curl are stubs, so nothing here downloads or builds.

bats_require_minimum_version 1.5.0

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../build-notifier-app.sh"
    STUBS="${BATS_TEST_TMPDIR}/stubs"
    export CALLS="${BATS_TEST_TMPDIR}/calls"
    export FAKE_SYSTEM=Darwin

    mkdir -p "${STUBS}"

    cat >"${STUBS}/uname" <<'EOF'
#!/bin/sh
echo "$FAKE_SYSTEM"
EOF
    cat >"${STUBS}/curl" <<'EOF'
#!/bin/sh
echo "curl $*" >>"$CALLS"
exit 1
EOF
    chmod +x "${STUBS}"/*

    export PATH="${STUBS}:${PATH}"
}

@test "with no name it shows the usage and downloads nothing" {
    run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: build-notifier-app.sh <name>"* ]]
    [ ! -e "$CALLS" ]
}

@test "a name that could reach outside the icons folder is refused" {
    run "$SCRIPT" "../quill"

    [ "$status" -eq 1 ]
    [ ! -e "$CALLS" ]
}

@test "off a Mac it builds nothing and says why" {
    FAKE_SYSTEM=Linux run "$SCRIPT" quill

    [ "$status" -eq 0 ]
    [[ "$output" == *"for macOS"* ]]
    [ ! -e "$CALLS" ]
}

@test "a name with no icon is refused before anything is downloaded" {
    run "$SCRIPT" nosuchicon

    [ "$status" -eq 1 ]
    [[ "$output" == *"No icon at"*"icons/nosuchicon.png"* ]]
    [ ! -e "$CALLS" ]
}

@test "each project's icon is a square PNG in the repository" {
    local name

    for name in quill turva juttu; do
        run file "${BATS_TEST_DIRNAME}/../icons/${name}.png"

        [ "$status" -eq 0 ]
        [[ "$output" =~ PNG\ image\ data,\ ([0-9]+)\ x\ ([0-9]+) ]]
        [ "${BASH_REMATCH[1]}" = "${BASH_REMATCH[2]}" ]
    done
}
