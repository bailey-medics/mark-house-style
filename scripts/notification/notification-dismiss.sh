#!/bin/bash

# Take back one worktree's banner, from the screen and Notification Centre.
#
#   notification-dismiss.sh <group>
#
# The banner relay in VS Code runs this once a worktree's window has been in
# front for a few seconds, and the banner has been up as long, so a banner
# for the session you are already looking at clears itself.
#
# notification-show.sh leaves a note per group, in the banners folder,
# naming the notifier app that posted the banner. macOS lets only the app
# that posted a notification remove it, so the note says which one to ask.
# No note means no banner to clear, and this does nothing.
#
# The note goes first, then the banner, so a banner that arrives in between
# is cleared with it rather than left with no note. That is right: its
# window is the one in front.
#
# The Mac's bash is 3.2, so nothing newer than that is used here. Every step
# is best-effort and this always exits 0.

set -u

group="${1:-}"
BANNERS_DIR="${TURVA_NOTIFY_BANNERS:-$HOME/Library/Caches/turva-notifier/banners}"

case "$group" in
    "" | -* | .* | *[!A-Za-z0-9._-]*) exit 0 ;;
esac

note="$BANNERS_DIR/$group"
[ -f "$note" ] || exit 0

app="$(head -n 1 "$note" 2>/dev/null || true)"
rm -f "$note"

case "$app" in
    /*.app) ;;
    *) exit 0 ;;
esac

bin="$app/Contents/MacOS/terminal-notifier"
[ -x "$bin" ] || exit 0

"$bin" -remove "$group" >/dev/null 2>&1 || true

exit 0
