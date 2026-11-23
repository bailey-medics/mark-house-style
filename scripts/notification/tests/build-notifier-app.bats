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

# A python3 that has Pillow when FAKE_SYSTEM_PIL is 1, and that makes a
# stand-in private environment on `-m venv`, whose pip records the install
# and whose python then has Pillow.
stub_python() {
    cat >"${STUBS}/python3" <<'EOF'
#!/bin/bash
if [ "$1" = "-m" ] && [ "$2" = "venv" ]; then
    mkdir -p "$3/bin"
    cat >"$3/bin/python" <<'EOF2'
#!/bin/bash
[ -e "$(dirname "$0")/../pillow-installed" ]
EOF2
    cat >"$3/bin/pip" <<'EOF2'
#!/bin/bash
echo "pip $*" >>"$CALLS"
touch "$(dirname "$0")/../pillow-installed"
EOF2
    chmod +x "$3/bin/python" "$3/bin/pip"
    exit 0
fi
[ "${FAKE_SYSTEM_PIL:-0}" = 1 ]
EOF
    chmod +x "${STUBS}/python3"

    export TURVA_NOTIFY_VENV="${BATS_TEST_TMPDIR}/venv"
}

@test "an icon's identifier names the project and changes with the picture" {
    local picture="${BATS_TEST_TMPDIR}/icon.png"
    local first
    local second

    source "$SCRIPT"
    echo one >"${picture}"
    first="$(icon_identifier juttu "${picture}")"
    echo two >"${picture}"
    second="$(icon_identifier juttu "${picture}")"

    [[ "${first}" == fr.julienxx.oss.terminal-notifier.juttu.* ]]
    [ "${first}" != "${second}" ]
    [ "$(icon_identifier juttu "${picture}")" = "${second}" ]
}

@test "the Mac's own python3 is used when it has Pillow" {
    stub_python
    export FAKE_SYSTEM_PIL=1
    source "$SCRIPT"

    run pillow_python

    [ "$status" -eq 0 ]
    [ "$output" = "python3" ]
    [ ! -e "${TURVA_NOTIFY_VENV}" ]
}

@test "without Pillow, a private environment is made once and used" {
    stub_python
    source "$SCRIPT"

    run --separate-stderr pillow_python

    [ "$status" -eq 0 ]
    [ "$output" = "${TURVA_NOTIFY_VENV}/bin/python" ]
    grep -qx "pip install --quiet Pillow" "$CALLS"

    run --separate-stderr pillow_python

    [ "$output" = "${TURVA_NOTIFY_VENV}/bin/python" ]
    [ "$(grep -c "pip install" "$CALLS")" -eq 1 ]
}

@test "a build that stops early still cleans up, without an unbound variable" {
    stub_python
    export FAKE_SYSTEM_PIL=1
    export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
    mkdir -p "${TMPDIR}"

    run "$SCRIPT" quill

    [ "$status" -ne 0 ]
    [[ "$output" != *"unbound variable"* ]]
    [ -z "$(ls -A "${TMPDIR}")" ]
}
