#!/usr/bin/env bats
# Tests for install.sh, which packs the checkout name extension and installs
# or removes it.
#
# HOME is the test's own folder, and VS Code's command line tools are
# stand-ins that record what they were asked and keep a copy of any package
# they were handed. So no test reaches a real VS Code.

bats_require_minimum_version 1.5.0

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../install.sh"
    export HOME="${BATS_TEST_TMPDIR}/home"
    CALLS="${BATS_TEST_TMPDIR}/calls"
    KEPT="${BATS_TEST_TMPDIR}/kept.vsix"
    BIN="${BATS_TEST_TMPDIR}/bin"
    SERVER="${HOME}/.vscode-server/cli/servers/Stable-abc/server/bin/code-server"

    mkdir -p "${HOME}" "${BIN}"
}

# Writes a stand-in for one of VS Code's command line tools at a path. It
# records its arguments under a name, so a test can tell which tool ran.
fake_tool() {
    local path="$1"
    local name="$2"

    mkdir -p "$(dirname "${path}")"
    cat >"${path}" <<EOF
#!/usr/bin/env bash
echo "${name} \$*" >>"${CALLS}"
if [ "\$1" = "--install-extension" ]; then
    cp "\$2" "${KEPT}"
fi
EOF
    chmod +x "${path}"
}

# Makes a folder holding only the named tools, for a PATH with nothing else
# on it, and prints the folder.
only_tools() {
    local tools="${BATS_TEST_TMPDIR}/tools"
    local tool

    mkdir -p "${tools}"

    for tool in "$@"; do
        ln -s "$(command -v "${tool}")" "${tools}/${tool}"
    done

    echo "${tools}"
}

@test "with a VS Code server, the extension goes into the server" {
    fake_tool "${SERVER}" server
    fake_tool "${BIN}/code" code

    PATH="${BIN}:${PATH}" run "$SCRIPT"

    [ "$status" -eq 0 ]
    grep -q "^server --install-extension .*/checkout-name.vsix --force$" "$CALLS"
    run ! grep -q "^code " "$CALLS"
}

@test "the newest of several servers is used" {
    local older="${HOME}/.vscode-server/cli/servers/Stable-old/server/bin/code-server"

    fake_tool "${older}" older
    fake_tool "${SERVER}" newer
    touch -d "2020-01-01" "${older}"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    grep -q "^newer --install-extension " "$CALLS"
    run ! grep -q "^older " "$CALLS"
}

@test "a server VS Code reaches over SSH counts too" {
    fake_tool "${HOME}/.vscode-server/bin/abc/bin/code-server" ssh-server

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    grep -q "^ssh-server --install-extension " "$CALLS"
}

@test "without a server, the code command is used" {
    fake_tool "${BIN}/code" code

    PATH="${BIN}:${PATH}" run "$SCRIPT"

    [ "$status" -eq 0 ]
    grep -q "^code --install-extension .*/checkout-name.vsix --force$" "$CALLS"
}

@test "the package holds the extension's files and both manifests" {
    fake_tool "${SERVER}" server

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    run unzip -Z1 "${KEPT}"
    [[ "$output" == *"[Content_Types].xml"* ]]
    [[ "$output" == *"extension.vsixmanifest"* ]]
    [[ "$output" == *"extension/package.json"* ]]
    [[ "$output" == *"extension/extension.js"* ]]
    [[ "$output" == *"extension/names.js"* ]]
    [[ "$output" == *"extension/terminals.js"* ]]
}

@test "the package carries the version package.json gives" {
    local version

    version="$(sed -n 's/^ *"version": *"\([^"]*\)".*$/\1/p' "${BATS_TEST_DIRNAME}/../package.json")"
    fake_tool "${SERVER}" server

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ -n "${version}" ]
    run unzip -p "${KEPT}" extension.vsixmanifest
    [[ "$output" == *"Id=\"checkout-name\" Version=\"${version}\""* ]]
}

@test "installing says which version went in, and to reload the window" {
    fake_tool "${SERVER}" server

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installed local.checkout-name "* ]]
    [[ "$output" == *"Reload Window"* ]]
}

@test "no package is left beside the extension" {
    fake_tool "${SERVER}" server

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ -z "$(find "${BATS_TEST_DIRNAME}/.." -name '*.vsix')" ]
}

@test "remove uninstalls the extension, and packs nothing" {
    fake_tool "${SERVER}" server

    run "$SCRIPT" remove

    [ "$status" -eq 0 ]
    grep -qx "server --uninstall-extension local.checkout-name" "$CALLS"
    [ ! -e "${KEPT}" ]
}

@test "an unknown action is refused, and nothing is installed" {
    fake_tool "${SERVER}" server

    run "$SCRIPT" sideways

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: install.sh [remove]"* ]]
    [ ! -e "${CALLS}" ]
}

@test "with no VS Code at all, it says so and installs nothing" {
    local tools

    tools="$(only_tools bash dirname zip)"

    PATH="${tools}" run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"VS Code was not found"* ]]
    [ ! -e "${CALLS}" ]
}

@test "without zip, it says so and installs nothing" {
    local tools

    tools="$(only_tools bash dirname)"
    fake_tool "${SERVER}" server

    PATH="${tools}" run "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"'zip' command was not found"* ]]
    [ ! -e "${CALLS}" ]
}
