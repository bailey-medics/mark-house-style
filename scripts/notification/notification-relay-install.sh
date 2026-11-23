#!/bin/bash
# Build the banner relay and install it in the Mac's VS Code.
#
# The relay is a VS Code extension that brings the box's banners to the Mac
# over VS Code's own connection, for when the Mac cannot reach the box by
# SSH, such as on a network that blocks Tailscale. It hands each banner to
# the scripts notification-listen-install.sh copies to the Mac, so that runs
# first, which also picks up any change to them. Run this again after the
# relay or the banner scripts change.
#
# The Mac's bash is 3.2, so nothing newer than that is used here.

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
    echo "The banner relay runs in VS Code on the Mac; nothing to install here."
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELAY="$SCRIPT_DIR/vscode-relay"
CODE="${TURVA_NOTIFY_CODE:-/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code}"

if [ ! -x "$CODE" ]; then
    CODE="$(command -v code || true)"
fi

if [ -z "$CODE" ]; then
    echo "VS Code's code command was not found; install VS Code first." >&2
    exit 1
fi

bash "$SCRIPT_DIR/notification-listen-install.sh"

(cd "$RELAY" && npm ci --no-audit --no-fund --loglevel=error && npm run package)
"$CODE" --install-extension "$RELAY/banner-relay.vsix" --force

echo "Installed. Reload each VS Code window connected to the box to start it."
