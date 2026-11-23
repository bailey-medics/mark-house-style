#!/bin/bash

# Show one notification on a Mac: a banner, the worktree spoken aloud, and
# optionally a chime.
#
#   notification-show.sh <title> <body> <group> <spoken> [<worktree path>
#       [<remote name>]]
#
# notification.sh works out what to say and calls this to say it, on a Mac.
# For the Linux dev box, which has no screen, notification-listen.sh calls
# it on the Mac with each banner the box offers, and passes the remote name:
# what VS Code calls the box, "devbox" in a window titled
# "turva-5 [SSH: devbox]".
#
# The Mac's bash is 3.2, so nothing newer than that is used here.
#
# Every step is best-effort and this always exits 0.

set -u

title="${1:-}"
body="${2:-}"
group="${3:-}"
spoken="${4:-}"
cwd="${5:-}"
remote="${6:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
AUDIO_FILE="$SCRIPT_DIR/level-completed.mp3"

# Overridable from the environment: TURVA_NOTIFY_VOICE picks another installed
# voice, TURVA_NOTIFY_SPEAK=0 silences speech, TURVA_NOTIFY_BANNER=0 suppresses
# the macOS banner, TURVA_NOTIFY_APP points at the branded notifier if it is
# not in the default place, TURVA_NOTIFY_ACTIVATE="" stops a click on the
# banner focusing the editor, and
# TURVA_NOTIFY_CHIME=1 brings back the completion sound, which is off by
# default.
VOICE="${TURVA_NOTIFY_VOICE:-Karen}"
SPEAK="${TURVA_NOTIFY_SPEAK:-1}"
BANNER="${TURVA_NOTIFY_BANNER:-1}"
CHIME="${TURVA_NOTIFY_CHIME:-0}"

# A branded notifier gives the banner its project's icon. Each is a copy of
# terminal-notifier that build-notifier-app.sh makes from icons/<name>.png
# into ~/Applications, or TURVA_NOTIFY_APP_DIR. The folder the banner came
# from picks it: Quill Medical's, Turva's and Juttu's folders have one each,
# Juttu's folders carrying its repository's full name, juttu-messaging. Any
# other folder has none yet, so its banner keeps the plain icon. An app
# named in TURVA_NOTIFY_APP is used for every banner instead.
NOTIFIER_DIR="${TURVA_NOTIFY_APP_DIR:-$HOME/Applications}"

if [ -n "${TURVA_NOTIFY_APP:-}" ]; then
    NOTIFIER_APP="$TURVA_NOTIFY_APP"
else
    folder="$(basename "${cwd:-$title}")"

    case "$folder" in
        quillmedical | quillmedical-*) NOTIFIER_APP="$NOTIFIER_DIR/quill-notifier.app" ;;
        turva | turva-*) NOTIFIER_APP="$NOTIFIER_DIR/turva-notifier.app" ;;
        juttu-messaging | juttu-messaging-*) NOTIFIER_APP="$NOTIFIER_DIR/juttu-notifier.app" ;;
        *) NOTIFIER_APP="" ;;
    esac
fi

NOTIFIER_BIN="$NOTIFIER_APP/Contents/MacOS/terminal-notifier"

# A banner and speech answer different questions: the banner says which
# branch finished and survives on screen, speech says which worktree
# without needing the screen at all. Both, unless turned off.
#
# Two ways to post the banner, preferring the first:
#
#   1. $NOTIFIER_APP, a copy of terminal-notifier carrying its own
#      icon. macOS takes a notification's icon from the bundle that
#      sent it and offers no API to override it per notification, so
#      a custom icon means a custom bundle with its own identifier.
#      Turva has no recipe to build one yet, so this is absent unless
#      built by hand.
#
#   2. `display notification`, which always shows the osascript icon.
#      Addressing it to an application (System Events, Script Editor)
#      changes nothing except to break it: System Events returns exit
#      0 and shows nothing at all.
#
# Neither reports failure usefully. Exit status says only that the
# command ran, never that a banner appeared, so changes here have to
# be confirmed by eye.
if [ "$BANNER" = "1" ]; then
    if [ -x "$NOTIFIER_BIN" ]; then
        # Clicking the banner raises the editor window for the
        # worktree that finished. -activate cannot do that: a
        # bundle identifier names an application, so macOS raises
        # whichever window was last in front, which with several
        # worktrees open on separate Spaces is rarely the right
        # one. -execute stores a command with the notification and
        # runs it on the click, so notification-focus.sh can find
        # the one window holding this folder.
        #
        # The command is single-quoted for the shell -execute
        # spawns, with any quote in either path escaped. Empty
        # TURVA_NOTIFY_ACTIVATE leaves a click doing nothing.
        #
        # Clear old notifications before testing this
        # (`-remove <group>`). A banner still sitting in
        # Notification Centre carries its stored command, so a
        # click on a stale one fires that, which is easy to misread
        # as a new banner firing on delivery rather than on click.
        FOCUS_SCRIPT="$SCRIPT_DIR/notification-focus.sh"

        set -- -title "$title" -message "$body" -group "$group"
        if [ "${TURVA_NOTIFY_ACTIVATE-1}" != "" ] && [ -n "$cwd" ] \
            && [ -x "$FOCUS_SCRIPT" ]; then
            q() { printf "%s" "$1" | sed "s/'/'\\\\''/g"; }
            command="'$(q "$FOCUS_SCRIPT")' '$(q "$cwd")'"
            [ -n "$remote" ] && command="$command '$(q "$remote")'"
            set -- "$@" -execute "$command"
        fi
        "$NOTIFIER_BIN" "$@" >/dev/null 2>&1 || true
    elif command -v osascript >/dev/null 2>&1; then
        # Backslashes first, then quotes: reversing the order would
        # escape the backslashes this step introduces. A branch name
        # is free to contain either, and an unescaped one is an
        # AppleScript syntax error that `|| true` would hide.
        esc() {
            printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
        }
        osascript -e "display notification \"$(esc "$body")\" \
            with title \"$(esc "$title")\"" >/dev/null 2>&1 || true
    fi
fi

# The worktree spoken aloud. Turva and Juttu are Finnish words, so a Finnish
# voice says them, Satu unless TURVA_NOTIFY_FINNISH_VOICE names another, and
# the usual voice says the number after them. On a Mac without that voice,
# English spellings the usual voice says close to the Finnish stand in.
# notification.sh on the box works out the words; this only picks the voice.
FINNISH_VOICE="${TURVA_NOTIFY_FINNISH_VOICE:-Satu}"

has_voice() {
    local name="$1"

    say -v '?' 2>/dev/null | grep -q "^${name}[[:space:]]"
}

say_in() {
    local voice="$1"
    local text="$2"

    say -v "$voice" "$text" >/dev/null 2>&1 || true
}

say_finnish() {
    local word="$1"
    local english="$2"
    local rest="$3"

    if has_voice "$FINNISH_VOICE"; then
        say_in "$FINNISH_VOICE" "$word"
        if [ -n "$rest" ]; then
            say_in "$VOICE" "$rest"
        fi
    else
        say_in "$VOICE" "${english}${rest:+ $rest}"
    fi
}

speak() {
    local text="$1"
    local first="${text%% *}"
    local rest=""

    if [ "$first" != "$text" ]; then
        rest="${text#* }"
    fi

    case "$first" in
        Turva | turva) say_finnish "Turva" "Toor-vah" "$rest" ;;
        Juttu | juttu) say_finnish "Juttu" "Yoot-too" "$rest" ;;
        *) say_in "$VOICE" "$text" ;;
    esac
}

if [ "$SPEAK" = "1" ] && [ -n "$spoken" ] && command -v say >/dev/null 2>&1; then
    speak "$spoken"
fi

if [ "$CHIME" = "1" ] && [ -f "$AUDIO_FILE" ] \
    && command -v afplay >/dev/null 2>&1; then
    afplay "$AUDIO_FILE" >/dev/null 2>&1 || true
fi

exit 0
