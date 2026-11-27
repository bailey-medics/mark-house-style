#!/bin/bash

# Install the banner listener on the Mac, as a launchd agent.
#
# Copies the listener and the scripts it calls out of this checkout into
# ~/Library/Application Support/turva-notify, so the Mac's banners do not
# change with whichever branch the checkout happens to be on, then loads an
# agent that starts the listener at login and restarts it if it stops.
# Run it again to pick up a change to the scripts.
#
# TURVA_NOTIFY_BOX, if set, is written into the agent, for a box the Mac's
# ssh knows by a name other than "devbox".
#
# Quill Medical had the same listener, reading the same queue on the box,
# and two listeners would show every banner twice. Its scripts have since
# moved here, so its installed copy can never be brought up to date. This
# retires it first: it stops Quill's agent, then deletes its agent file and
# its folder of scripts. If the agent will not stop, nothing is deleted or
# installed.
#
# Off a Mac it fails, saying so, since a terminal in a VS Code window
# connected to the box runs on the box and is easy to take for the Mac's.

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
    echo "✗ This machine is not the Mac, so nothing was installed." >&2
    echo "  Run \`just -g nli\` in a terminal on the Mac itself: a terminal in a VS Code window connected to the box runs on the box." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="com.turva.notify-listen"
DEST="$HOME/Library/Application Support/turva-notify"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/turva-notify-listen.log"
QUILL_LABEL="com.quill-medical.notify-listen"
QUILL_DEST="$HOME/Library/Application Support/quill-notify"
QUILL_PLIST="$HOME/Library/LaunchAgents/$QUILL_LABEL.plist"
BOX="${TURVA_NOTIFY_BOX:-devbox}"

quill_listener_loaded() {
    launchctl print "gui/$(id -u)/$QUILL_LABEL" >/dev/null 2>&1
}

# Stop Quill Medical's listener and delete what it installed. bootout can
# hand back before the agent has gone, so it is given a few seconds.
retire_quill_listener() {
    local found=0
    local tries=0

    if quill_listener_loaded; then
        launchctl bootout "gui/$(id -u)/$QUILL_LABEL" >/dev/null 2>&1 || true

        while quill_listener_loaded && [ "$tries" -lt 10 ]; do
            sleep 0.5
            tries=$((tries + 1))
        done

        if quill_listener_loaded; then
            echo "✗ Quill Medical's old banner listener would not stop, so nothing was removed or installed." >&2
            echo "  Stop it by hand: launchctl bootout gui/$(id -u)/$QUILL_LABEL" >&2
            exit 1
        fi

        found=1
    fi

    if [ -e "$QUILL_PLIST" ] || [ -d "$QUILL_DEST" ]; then
        rm -f "$QUILL_PLIST"
        rm -rf "$QUILL_DEST"
        found=1
    fi

    if [ "$found" = "1" ]; then
        echo "Retired Quill Medical's old banner listener, with its agent file and $QUILL_DEST."
    fi
}

retire_quill_listener

mkdir -p "$DEST" "$(dirname "$PLIST")" "$(dirname "$LOG")"

for file in notification-listen.sh notification-queue.py \
    notification-show.sh notification-focus.sh notification-dismiss.sh \
    level-completed.mp3; do
    cp "$SCRIPT_DIR/$file" "$DEST/$file"
done

chmod +x "$DEST/notification-listen.sh" "$DEST/notification-show.sh" \
    "$DEST/notification-focus.sh" "$DEST/notification-dismiss.sh"

# launchd starts agents with almost no PATH; Homebrew's is added for a
# python3 or ssh installed there.
cat >"$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$DEST/notification-listen.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>TURVA_NOTIFY_BOX</key>
        <string>$BOX</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
PLIST

# bootout fails when the agent is not loaded yet, which is the first run.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Banner listener installed and running, fetching from $BOX."
echo "Its errors go to $LOG."
