#!/bin/bash
# Build the banner relay and install it in the Mac's VS Code.
#
# The relay is a VS Code extension that brings the box's banners to the Mac
# over VS Code's own connection, for when the Mac cannot reach the box by
# SSH, such as on a network that blocks Tailscale. It hands each banner to
# its own copy of the banner scripts, put in ~/Library/Application
# Support/banner-relay here, so it never depends on which listener the Mac
# has installed, this repository's or Quill Medical's, or on an older copy.
# Run this again after the relay or the banner scripts change.
#
# Off a Mac it fails, saying so, since a terminal in a VS Code window
# connected to the box runs on the box and is easy to take for the Mac's.
#
# The Mac's bash is 3.2, so nothing newer than that is used here.

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
    echo "✗ This machine is not the Mac, so nothing was built or installed." >&2
    echo "  Run \`just -g nri\` in a terminal on the Mac itself: a terminal in a VS Code window connected to the box runs on the box." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELAY="$SCRIPT_DIR/vscode-relay"
DEST="$HOME/Library/Application Support/banner-relay"
CODE="${TURVA_NOTIFY_CODE:-/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code}"

if [ ! -x "$CODE" ]; then
    CODE="$(command -v code || true)"
fi

if [ -z "$CODE" ]; then
    echo "VS Code's code command was not found; install VS Code first." >&2
    exit 1
fi

mkdir -p "$DEST"
for file in notification-queue.py notification-show.sh notification-focus.sh \
    notification-dismiss.sh \
    level-completed.mp3; do
    cp "$SCRIPT_DIR/$file" "$DEST/$file"
done
chmod +x "$DEST/notification-show.sh" "$DEST/notification-focus.sh" \
    "$DEST/notification-dismiss.sh"

(cd "$RELAY" && npm ci --no-audit --no-fund --loglevel=error && npm run package)
"$CODE" --install-extension "$RELAY/banner-relay.vsix" --force

echo "Installed. Reload each VS Code window connected to the box to start it."
