#!/usr/bin/env bash
# Packs this folder as a VS Code extension and installs it, or removes it.
#
# Usage: install.sh [remove]
#
# Run through `just -g checkout-name-install` and `just -g
# checkout-name-remove`. Afterwards, run "Developer: Reload Window" in each
# VS Code window that is open. Safe to run again: installing replaces the
# copy installed before.
#
# A .vsix is a zip holding the extension's files and two small manifests, so
# the package is built here by hand, in a scratch folder that is removed
# afterwards. Nothing is left in the repository. Installing needs `zip`.
#
# On a machine VS Code reaches from elsewhere, through a tunnel or SSH, the
# extension goes into VS Code's server there, because that is where the
# extensions for those windows run. Anywhere else it goes into VS Code
# itself, through its `code` command.
set -euo pipefail

readonly EXTENSION_ID="local.checkout-name"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prints the newest VS Code server's command line tool, or nothing. A tunnel
# keeps its servers under cli/servers, and SSH keeps them under bin. Every
# server shares one extensions folder, so the newest serves them all.
newest_server() {
    local candidate
    local newest=""

    for candidate in "${HOME}"/.vscode-server/cli/servers/*/server/bin/code-server "${HOME}"/.vscode-server/bin/*/bin/code-server; do
        if [ ! -x "${candidate}" ]; then
            continue
        fi

        if [ -z "${newest}" ] || [ "${candidate}" -nt "${newest}" ]; then
            newest="${candidate}"
        fi
    done

    echo "${newest}"
}

# Prints the tool that installs extensions on this machine, or nothing.
find_installer() {
    local mac_app="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    local server

    server="$(newest_server)"

    if [ -n "${server}" ]; then
        echo "${server}"
    elif command -v code >/dev/null 2>&1; then
        command -v code
    elif [ -x "${mac_app}" ]; then
        echo "${mac_app}"
    fi
}

# Succeeds when `zip`, which packs the extension, is installed. Otherwise
# says so and fails.
require_zip() {
    if command -v zip >/dev/null 2>&1; then
        return 0
    fi

    echo "✗ The 'zip' command was not found. It packs the extension. Install it, such as with 'sudo apt install zip', then run this again." >&2
    return 1
}

# Prints the version package.json gives the extension.
extension_version() {
    sed -n 's/^ *"version": *"\([^"]*\)".*$/\1/p' "${here}/package.json"
}

# Writes the two manifests a .vsix needs beside the extension's files.
write_manifests() {
    local build="$1"
    local version="$2"

    cat >"${build}/[Content_Types].xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".vsixmanifest" ContentType="text/xml"/></Types>
EOF

    cat >"${build}/extension.vsixmanifest" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="checkout-name" Version="${version}" Publisher="local"/>
    <DisplayName>Checkout name</DisplayName>
    <Description xml:space="preserve">Shows a short name for the checkout a window has open.</Description>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.95.0"/>
      <Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="workspace"/>
    </Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>
EOF
}

# Packs the extension in the scratch folder, and prints the package's path.
build_package() {
    local build="$1"
    local version="$2"

    mkdir "${build}/extension"
    cp "${here}/package.json" "${here}/extension.js" "${here}/names.js" "${build}/extension/"
    write_manifests "${build}" "${version}"

    (cd "${build}" && zip -q -r checkout-name.vsix "[Content_Types].xml" extension.vsixmanifest extension)

    echo "${build}/checkout-name.vsix"
}

main() {
    local action="${1:-install}"

    if [ "${action}" != "install" ] && [ "${action}" != "remove" ]; then
        echo "✗ Unknown action '${action}'. Usage: install.sh [remove]" >&2
        exit 1
    fi

    if [ "${action}" = "install" ]; then
        require_zip || exit 1
    fi

    local installer

    installer="$(find_installer)"

    if [ -z "${installer}" ]; then
        echo "✗ VS Code was not found: no server under ~/.vscode-server, and no 'code' command. In VS Code, run 'Shell Command: Install code command in PATH', then run this again." >&2
        exit 1
    fi

    if [ "${action}" = "remove" ]; then
        "${installer}" --uninstall-extension "${EXTENSION_ID}"
        echo "Removed ${EXTENSION_ID}. Run 'Developer: Reload Window' in each VS Code window."
        return 0
    fi

    local version
    local build
    local package

    version="$(extension_version)"
    build="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${build}'" EXIT

    package="$(build_package "${build}" "${version}")"

    "${installer}" --install-extension "${package}" --force
    echo "Installed ${EXTENSION_ID} ${version}. Run 'Developer: Reload Window' in each VS Code window."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
