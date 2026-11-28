#!/usr/bin/env bats
# Tests for notification.sh, which offers a banner saying which worktree
# has finished a response, or is waiting on a reply, and for the queue it
# writes the banner to.
#
# Ported from Quill Medical's tests, which cover the same scripts.
# Every Mac tool they reach (the notifier, osascript, ssh, code) is a stub.
#
# Each test builds a throwaway repository with one extra worktree, and
# writes to a queue in its own temporary folder, so nothing here touches
# the real repository or the real queue.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../notification.sh"
    QUEUE="${BATS_TEST_DIRNAME}/../notification-queue.py"
    MAIN="${BATS_TEST_TMPDIR}/turva"
    OTHER="${BATS_TEST_TMPDIR}/turva-4"

    export TURVA_NOTIFY_QUEUE="${BATS_TEST_TMPDIR}/queue/banners.jsonl"
    export TURVA_NOTIFY_BANNERS="${BATS_TEST_TMPDIR}/banners"

    git init -q "$MAIN"
    git -C "$MAIN" -c user.name=t -c user.email=t@example.com \
        commit -q --allow-empty -m "start"
    git -C "$MAIN" worktree add -q "$OTHER" -b other
}

# What the script would offer for a hook payload naming this directory.
# TURVA_NOTIFY_DEBUG makes it print the banner and stop.
shown_for() {
    local cwd="$1"
    shift

    printf '{"cwd": "%s"}' "$cwd" | TURVA_NOTIFY_DEBUG=1 "$SCRIPT" "$@"
}

group_of() {
    printf '%s\n' "$1" | sed -n 's/^group=//p'
}

@test "a finished banner is grouped by its worktree" {
    run shown_for "$OTHER"

    [ "$status" -eq 0 ]
    [ "$(group_of "$output")" = "turva-claude-turva-4" ]
}

@test "two worktrees do not share a group, so neither banner replaces the other" {
    run shown_for "$MAIN"
    main_group="$(group_of "$output")"

    run shown_for "$OTHER"
    other_group="$(group_of "$output")"

    [ -n "$main_group" ]
    [ "$main_group" != "$other_group" ]
}

@test "a subdirectory of a worktree is grouped with that worktree" {
    mkdir -p "${OTHER}/frontend"

    run shown_for "${OTHER}/frontend"

    [ "$status" -eq 0 ]
    [ "$(group_of "$output")" = "turva-claude-turva-4" ]
}

@test "a separate repository inside the project is titled as the project" {
    local subject="${MAIN}/subjects/news"
    git init -q "$subject"

    run env CLAUDE_PROJECT_DIR="$MAIN" bash -c "printf '{\"cwd\": \"%s\"}' '$subject' | TURVA_NOTIFY_DEBUG=1 '$SCRIPT'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"title=Turva"$'\n'* ]]
}

@test "a worktree inside the project keeps its own name" {
    local inner="${MAIN}/.claude/worktrees/inner-2"
    git -C "$MAIN" worktree add -q "$inner" -b inner

    run env CLAUDE_PROJECT_DIR="$MAIN" bash -c "printf '{\"cwd\": \"%s\"}' '$inner' | TURVA_NOTIFY_DEBUG=1 '$SCRIPT'"

    [ "$status" -eq 0 ]
    [[ "$output" == *"title=Inner 2"$'\n'* ]]
}

@test "quiet hours keep the banner but say nothing, across midnight" {
    for hour in 22 23 00 06; do
        run env TURVA_NOTIFY_QUIET_HOURS=22-7 TURVA_NOTIFY_HOUR="$hour" bash -c "printf '{\"cwd\": \"%s\"}' '$MAIN' | TURVA_NOTIFY_DEBUG=1 '$SCRIPT'"
        [[ "$output" == *"title=Turva"* ]]
        [[ "$output" == *"spoken=" ]]
    done

    for hour in 07 12 21; do
        run env TURVA_NOTIFY_QUIET_HOURS=22-7 TURVA_NOTIFY_HOUR="$hour" bash -c "printf '{\"cwd\": \"%s\"}' '$MAIN' | TURVA_NOTIFY_DEBUG=1 '$SCRIPT'"
        [[ "$output" == *"spoken=Turva" ]]
    done
}

@test "without quiet hours, a banner is spoken at any hour" {
    run env TURVA_NOTIFY_HOUR=03 bash -c "printf '{\"cwd\": \"%s\"}' '$MAIN' | TURVA_NOTIFY_DEBUG=1 '$SCRIPT'"

    [[ "$output" == *"spoken=Turva" ]]
}

@test "a question shares its worktree's group, so it replaces a finished banner" {
    run shown_for "$OTHER"
    finished_group="$(group_of "$output")"

    run shown_for "$OTHER" needs-input

    [ "$status" -eq 0 ]
    [ "$(group_of "$output")" = "$finished_group" ]
}

@test "the banner is titled with the worktree" {
    run shown_for "$OTHER"

    [ "$status" -eq 0 ]
    [[ "$output" == *"title=Turva 4"* ]]
}

@test "a numbered worktree is spoken by its number, and the main checkout by name alone" {
    run shown_for "$OTHER"
    [[ "$output" == *"spoken=Turva 4"* ]]

    run shown_for "$MAIN"
    printf "%s\n" "$output" | grep -qx "spoken=Turva"
}

# Quill Medical's checkout, a numbered worktree and Owl's, named as on the box.
make_quill() {
    QUILL="${BATS_TEST_TMPDIR}/quillmedical"

    git init -q "$QUILL"
    git -C "$QUILL" -c user.name=t -c user.email=t@example.com \
        commit -q --allow-empty -m "start"
    git -C "$QUILL" worktree add -q "${QUILL}-6" -b sixth
    git -C "$QUILL" worktree add -q "${QUILL}-owl" -b owl
}

@test "Quill Medical's worktrees are spoken and titled as Quill, by number" {
    make_quill

    run shown_for "${QUILL}-6"

    [[ "$output" == *"spoken=Quill 6"* ]]
    printf "%s\n" "$output" | grep -qx "title=Quill 6"
}

@test "Quill Medical's main checkout and Owl's are titled Quill and Quill Owl" {
    make_quill

    run shown_for "$QUILL"

    printf "%s\n" "$output" | grep -qx "title=Quill"

    run shown_for "${QUILL}-owl"

    printf "%s\n" "$output" | grep -qx "title=Quill Owl"
}

@test "Arnie, Digest, Kaiku and Mark House Style are titled and spoken by their proper names" {
    local folder expected

    for pair in "arnie:Arnie" "arnie-2:Arnie 2" "digest:Digest" "digest-3:Digest 3" "kaiku:Kaiku" "kaiku-2:Kaiku 2" "mark-house-style:Mark House Style"; do
        folder="${BATS_TEST_TMPDIR}/${pair%%:*}"
        expected="${pair#*:}"
        mkdir -p "$folder"

        run shown_for "$folder"

        printf "%s\n" "$output" | grep -qx "title=${expected}"
        printf "%s\n" "$output" | grep -qx "spoken=${expected}"
    done
}

@test "other projects are titled by their session name as capitalised words" {
    local folder

    for pair in "turva-4:Turva 4" "ledger:Ledger" "big-old-thing-12:Big Old Thing 12"; do
        folder="${BATS_TEST_TMPDIR}/${pair%%:*}"
        mkdir -p "$folder"

        run shown_for "$folder"

        printf "%s\n" "$output" | grep -qx "title=${pair#*:}"
    done
}

@test "Quill Medical's main checkout is Quill alone, and Owl's Quill Owl" {
    make_quill

    run shown_for "$QUILL"

    printf "%s\n" "$output" | grep -qx "spoken=Quill"

    run shown_for "${QUILL}-owl"

    [[ "$output" == *"spoken=Quill Owl"* ]]
}

# A Juttu checkout and two worktrees, named as on the box: the folders
# carry the repository's full name, juttu-messaging.
make_juttu() {
    JUTTU="${BATS_TEST_TMPDIR}/juttu-messaging"

    git init -q "$JUTTU"
    git -C "$JUTTU" -c user.name=t -c user.email=t@example.com \
        commit -q --allow-empty -m "start"
    git -C "$JUTTU" worktree add -q "${JUTTU}-2" -b second
    git -C "$JUTTU" worktree add -q "${JUTTU}-3" -b third
}

@test "a Juttu banner is titled with the short session name, not the folder" {
    make_juttu

    run shown_for "$JUTTU"
    [ "$status" -eq 0 ]
    [[ "$output" == *"title=Juttu"$'\n'* ]]

    run shown_for "${JUTTU}-2"
    [[ "$output" == *"title=Juttu 2"$'\n'* ]]

    run shown_for "${JUTTU}-3" needs-input
    [[ "$output" == *"title=Juttu 3"$'\n'* ]]
}

@test "a Juttu worktree is spoken as Juttu and its number, never as Turva" {
    make_juttu

    run shown_for "$JUTTU"
    printf "%s\n" "$output" | grep -qx "spoken=Juttu"

    run shown_for "${JUTTU}-2"
    [[ "$output" == *"spoken=Juttu 2"* ]]
    [[ "$output" != *"Turva"* ]]
}

@test "each Juttu worktree keeps a banner group of its own" {
    make_juttu

    run shown_for "$JUTTU"
    [ "$(group_of "$output")" = "turva-claude-juttu" ]

    run shown_for "${JUTTU}-2"
    [ "$(group_of "$output")" = "turva-claude-juttu-2" ]
}

@test "another numbered folder is spoken by its own name, not as Turva" {
    other="${BATS_TEST_TMPDIR}/ledger-2"
    mkdir -p "$other"

    run shown_for "$other"

    [ "$status" -eq 0 ]
    [[ "$output" == *"spoken=ledger 2"* ]]
}

@test "the banner carries the bold lead of the closing TL;DR" {
    payload='{"cwd": "'"$OTHER"'", "last_assistant_message": "Done.\n\n## TL;DR\n\n- **Moved the scripts.** Details follow."}'

    run bash -c 'printf "%s" "$1" | TURVA_NOTIFY_DEBUG=1 "$2"' _ "$payload" "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"body=Moved the scripts."* ]]
}

@test "on Linux, a banner is offered as one line in the queue" {
    [ "$(uname -s)" = "Linux" ] || skip "the queue is written on the Linux dev box"

    printf '{"cwd": "%s"}' "$OTHER" | "$SCRIPT"

    [ "$(wc -l <"$TURVA_NOTIFY_QUEUE")" -eq 1 ]
    line="$(cat "$TURVA_NOTIFY_QUEUE")"
    [[ "$line" == *'"title": "Turva 4"'* ]]
    [[ "$line" == *'"group": "turva-claude-turva-4"'* ]]
    [[ "$line" == *"\"cwd\": \"${OTHER}\""* ]]
}

@test "the queue is cut back once it grows long, keeping the latest banners" {
    queue="${BATS_TEST_TMPDIR}/banners.jsonl"

    for i in $(seq 1 201); do
        python3 "$QUEUE" write --queue "$queue" -- "t" "banner $i" "g" "s" "/x"
    done

    [ "$(wc -l <"$queue")" -eq 50 ]
    [[ "$(tail -n 1 "$queue")" == *'"banner 201"'* ]]
}

@test "a body starting with a dash is still written as the body" {
    queue="${BATS_TEST_TMPDIR}/banners.jsonl"

    python3 "$QUEUE" write --queue "$queue" -- "t" "-- not an option" "g" "s" "/x"

    [[ "$(cat "$queue")" == *'"body": "-- not an option"'* ]]
}

# The Mac side: showing a banner, fetching the queue, and a click.

# A stand-in for the branded notifier that records its arguments, one a line,
# so notification-show.sh can be run on any machine without posting a banner.
stub_notifier() {
    local bin="${BATS_TEST_TMPDIR}/notifier.app/Contents/MacOS"

    mkdir -p "$bin"
    cat >"${bin}/terminal-notifier" <<STUB
#!/bin/bash
printf '%s\n' "\$@" >"${BATS_TEST_TMPDIR}/notifier-args"
STUB
    chmod +x "${bin}/terminal-notifier"

    export TURVA_NOTIFY_APP="${BATS_TEST_TMPDIR}/notifier.app"
    export TURVA_NOTIFY_SPEAK=0
}

@test "the show script posts the title, body and group it is given" {
    stub_notifier
    SHOW="${BATS_TEST_DIRNAME}/../notification-show.sh"

    run "$SHOW" "turva-4" "Did the thing" "grp" "Turva 4" "$OTHER"
    [ "$status" -eq 0 ]

    args="$(cat "${BATS_TEST_TMPDIR}/notifier-args")"
    [[ "$args" == *$'-title\nturva-4'* ]]
    [[ "$args" == *$'-message\nDid the thing'* ]]
    [[ "$args" == *$'-group\ngrp'* ]]
    [[ "$args" == *"-execute"* ]]
}

@test "a posted banner leaves a note naming the app that posted it" {
    stub_notifier
    SHOW="${BATS_TEST_DIRNAME}/../notification-show.sh"

    run "$SHOW" "turva-4" "Done" "turva-claude-turva-4" "Turva 4" "$OTHER"

    [ "$status" -eq 0 ]
    [ "$(cat "${TURVA_NOTIFY_BANNERS}/turva-claude-turva-4")" = "${TURVA_NOTIFY_APP}" ]
}

@test "a group that could not be a file name leaves no note" {
    stub_notifier
    SHOW="${BATS_TEST_DIRNAME}/../notification-show.sh"

    run "$SHOW" "t" "Done" "../escape" "s" "$OTHER"

    [ "$status" -eq 0 ]
    [ ! -e "${BATS_TEST_TMPDIR}/escape" ]
    [ -z "$(ls -A "${TURVA_NOTIFY_BANNERS}" 2>/dev/null)" ]
}

@test "a banner that failed to post leaves no note" {
    stub_notifier
    printf '#!/bin/bash\nexit 1\n' >"${TURVA_NOTIFY_APP}/Contents/MacOS/terminal-notifier"
    SHOW="${BATS_TEST_DIRNAME}/../notification-show.sh"

    run "$SHOW" "t" "Done" "turva-claude-turva-4" "s" "$OTHER"

    [ "$status" -eq 0 ]
    [ ! -e "${TURVA_NOTIFY_BANNERS}/turva-claude-turva-4" ]
}

@test "dismissing asks the app that posted the banner to remove it, and drops the note" {
    stub_notifier
    DISMISS="${BATS_TEST_DIRNAME}/../notification-dismiss.sh"
    mkdir -p "${TURVA_NOTIFY_BANNERS}"
    printf '%s\n' "${TURVA_NOTIFY_APP}" >"${TURVA_NOTIFY_BANNERS}/turva-claude-turva-4"

    run "$DISMISS" "turva-claude-turva-4"

    [ "$status" -eq 0 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/notifier-args")" = $'-remove\nturva-claude-turva-4' ]
    [ ! -e "${TURVA_NOTIFY_BANNERS}/turva-claude-turva-4" ]
}

@test "dismissing with no note removes nothing" {
    stub_notifier
    DISMISS="${BATS_TEST_DIRNAME}/../notification-dismiss.sh"

    run "$DISMISS" "turva-claude-turva-4"

    [ "$status" -eq 0 ]
    [ ! -e "${BATS_TEST_TMPDIR}/notifier-args" ]
}

@test "dismissing refuses a group that could reach outside the banners folder or be an option" {
    stub_notifier
    DISMISS="${BATS_TEST_DIRNAME}/../notification-dismiss.sh"
    mkdir -p "${TURVA_NOTIFY_BANNERS}"
    printf '%s\n' "${TURVA_NOTIFY_APP}" >"${BATS_TEST_TMPDIR}/outside"
    printf '%s\n' "${TURVA_NOTIFY_APP}" >"${TURVA_NOTIFY_BANNERS}/-remove"

    run "$DISMISS" "../outside"
    run "$DISMISS" "-remove"

    [ "$status" -eq 0 ]
    [ ! -e "${BATS_TEST_TMPDIR}/notifier-args" ]
    [ -e "${BATS_TEST_TMPDIR}/outside" ]
}

@test "dismissing ignores a note that does not name an app" {
    stub_notifier
    DISMISS="${BATS_TEST_DIRNAME}/../notification-dismiss.sh"
    mkdir -p "${TURVA_NOTIFY_BANNERS}"
    printf 'rm\n' >"${TURVA_NOTIFY_BANNERS}/turva-claude-turva-4"

    run "$DISMISS" "turva-claude-turva-4"

    [ "$status" -eq 0 ]
    [ ! -e "${BATS_TEST_TMPDIR}/notifier-args" ]
    [ ! -e "${TURVA_NOTIFY_BANNERS}/turva-claude-turva-4" ]
}

# The listener's stream, as the box's tail would send it: one JSON line per
# banner, given here with the time to stamp each with.
banner_line() {
    printf '{"time": %s, "title": "%s", "body": "%s", "group": "%s", "spoken": "s", "cwd": "%s"}\n' \
        "$1" "$2" "$3" "${4:-turva-claude-turva-4}" "${5:-/home/mark/github/turva-4}"
}

# A stand-in for the show script that records each call's arguments, one a
# line, and a blank line between calls.
stub_show() {
    SHOWN="${BATS_TEST_TMPDIR}/shown"
    SHOW_STUB="${BATS_TEST_TMPDIR}/show-stub"

    cat >"$SHOW_STUB" <<STUB
#!/bin/bash
printf '%s\n' "\$@" >>"$SHOWN"
printf '\n' >>"$SHOWN"
STUB
    chmod +x "$SHOW_STUB"
}

listen() {
    python3 "${BATS_TEST_DIRNAME}/../notification-queue.py" show \
        --show-script "$SHOW_STUB" --box devbox \
        --state "${BATS_TEST_TMPDIR}/last-shown"
}

@test "the Mac shows a fresh banner, naming the box so a click finds its window" {
    stub_show
    now="$(date +%s)"

    banner_line "$now" "turva-4" "Did the thing" | listen

    [ "$(cat "$SHOWN")" = $'turva-4\nDid the thing\nturva-claude-turva-4\ns\n/home/mark/github/turva-4\ndevbox' ]
}

@test "the Mac skips a banner older than five minutes" {
    stub_show
    old="$(( $(date +%s) - 600 ))"

    banner_line "$old" "turva-4" "Long ago" | listen

    [ ! -e "$SHOWN" ]
}

@test "after a reconnect, the Mac does not show a banner twice" {
    stub_show
    now="$(date +%s)"

    banner_line "$now" "turva-4" "Once" | listen
    banner_line "$now" "turva-4" "Once" | listen

    [ "$(grep -c '^Once$' "$SHOWN")" -eq 1 ]
}

@test "the Mac ignores a line that is not a banner, and shows the next" {
    stub_show
    now="$(date +%s)"

    {
        printf 'not json at all\n'
        printf '{"time": %s, "title": ["a list"]}\n' "$now"
        banner_line "$now" "turva-4" "Bad group" 'bad; rm -rf ~'
        banner_line "$now" "turva-4" "Good one"
    } | listen

    [ "$(grep -c '^devbox$' "$SHOWN")" -eq 1 ]
    grep -q '^Good one$' "$SHOWN"
}

@test "the Mac drops a worktree path that does not look like one, but still shows the banner" {
    stub_show
    now="$(date +%s)"

    banner_line "$now" "turva-4" "Odd path" \
        turva-claude-turva-4 '/home/../etc$(touch x)' | listen

    grep -q '^Odd path$' "$SHOWN"
    [ "$(grep -c 'etc' "$SHOWN")" -eq 0 ]
}

@test "the Mac turns control characters in a banner into spaces" {
    stub_show
    now="$(date +%s)"

    printf '{"time": %s, "title": "a\\nb", "body": "c\\u001bd", "group": "g", "spoken": "s", "cwd": "/x"}\n' \
        "$now" | listen

    grep -q '^a b$' "$SHOWN"
    grep -q '^c d$' "$SHOWN"
}

# say, terminal-notifier and the like read an argument starting with a dash
# as an option, so `say -v Karen "-o ~/file"` would write over a file on the
# Mac. Text from the box must never reach them starting with one.
@test "the Mac never passes a text field that starts with a dash" {
    stub_show
    now="$(date +%s)"

    printf '{"time": %s, "title": "-title", "body": "--help", "group": "g", "spoken": "-o /tmp/x", "cwd": "/x"}\n' \
        "$now" | listen

    [ "$(grep -c '^-' "$SHOWN")" -eq 0 ]
    grep -q '^ -o /tmp/x$' "$SHOWN"
}

@test "the Mac ignores a banner whose group starts with a dash" {
    stub_show
    now="$(date +%s)"

    banner_line "$now" "turva-4" "Dash group" "-execute" | listen

    [ ! -e "$SHOWN" ]
}

# Stand-ins for ssh and setsid, first on PATH, which record that ssh was
# called, for the box's side, or replay a queue, for the Mac's.
stub_ssh() {
    local bin="${BATS_TEST_TMPDIR}/bin"

    mkdir -p "$bin"
    cat >"${bin}/ssh" <<STUB
#!/bin/bash
printf '%s\n' "\$@" >"${BATS_TEST_TMPDIR}/ssh-called"
cat "${BATS_TEST_TMPDIR}/remote-queue" 2>/dev/null
STUB
    cat >"${bin}/setsid" <<'STUB'
#!/bin/bash
[ "$1" = "-f" ] && shift
exec "$@"
STUB
    chmod +x "${bin}/ssh" "${bin}/setsid"

    export PATH="${bin}:${PATH}"
}

@test "the listener connects to the box, follows its queue, and shows what arrives" {
    stub_ssh
    stub_notifier
    banner_line "$(date +%s)" "turva-4" "From the box" \
        >"${BATS_TEST_TMPDIR}/remote-queue"
    export HOME="${BATS_TEST_TMPDIR}/home"

    TURVA_NOTIFY_ONCE=1 run "${BATS_TEST_DIRNAME}/../notification-listen.sh"
    [ "$status" -eq 0 ]

    ssh_args="$(cat "${BATS_TEST_TMPDIR}/ssh-called")"
    [[ "$ssh_args" == *$'BatchMode=yes'* ]]
    [[ "$ssh_args" == *$'\ndevbox\n'* ]]
    [[ "$ssh_args" == *'tail -n 20 -F "$HOME/.local/state/quill-notify/banners.jsonl"'* ]]

    args="$(cat "${BATS_TEST_TMPDIR}/notifier-args")"
    [[ "$args" == *$'-message\nFrom the box'* ]]
    [[ "$args" == *"'/home/mark/github/turva-4' 'devbox'"* ]]
}

# A stand-in for osascript that records the window title it was asked to
# find, and finds it only if told to.
stub_focus_tools() {
    local bin="${BATS_TEST_TMPDIR}/bin"

    mkdir -p "$bin"
    cat >"${bin}/osascript" <<STUB
#!/bin/bash
printf '%s\n' "\$2" >"${BATS_TEST_TMPDIR}/osascript-name"
exit "\${OSASCRIPT_STATUS:-1}"
STUB
    cat >"${bin}/code" <<STUB
#!/bin/bash
printf '%s\n' "\$@" >"${BATS_TEST_TMPDIR}/code-args"
STUB
    chmod +x "${bin}/osascript" "${bin}/code"

    export PATH="${bin}:${PATH}"
    export TURVA_NOTIFY_CODE="${bin}/code"
}

@test "for the box, the click looks for the window titled with [SSH: devbox]" {
    stub_focus_tools
    FOCUS="${BATS_TEST_DIRNAME}/../notification-focus.sh"

    OSASCRIPT_STATUS=0 run "$FOCUS" /home/mark/github/turva-5 devbox
    [ "$status" -eq 0 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/osascript-name")" = "turva-5 [SSH: devbox]" ]
    [ ! -e "${BATS_TEST_TMPDIR}/code-args" ]
}

@test "for the box, with no window in view, the click opens the folder over SSH" {
    stub_focus_tools
    FOCUS="${BATS_TEST_DIRNAME}/../notification-focus.sh"

    run "$FOCUS" /home/mark/github/turva-5 devbox
    [ "$status" -eq 0 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/code-args")" = $'--folder-uri\nvscode-remote://ssh-remote+devbox/home/mark/github/turva-5' ]
}

# The banner relay, a VS Code extension, reaches the box over VS Code's own
# connection, which may be a tunnel. It names such a box "tunnel+<name>".
listen_as() {
    python3 "${BATS_TEST_DIRNAME}/../notification-queue.py" show \
        --show-script "$SHOW_STUB" --box "$1" \
        --state "${BATS_TEST_TMPDIR}/last-shown"
}

@test "the Mac accepts a tunnel box from the relay and passes it on" {
    stub_show
    now="$(date +%s)"

    banner_line "$now" "turva-4" "Did the thing" | listen_as "tunnel+devbox-tunnel"

    [ "$(tail -n 2 "$SHOWN" | head -n 1)" = "tunnel+devbox-tunnel" ]
}

@test "the Mac refuses a tunnel box whose name starts with a dash" {
    stub_show
    now="$(date +%s)"

    banner_line "$now" "turva-4" "Did the thing" | listen_as "tunnel+-oProxyCommand=x"

    [ ! -e "$SHOWN" ]
}

@test "for a tunnel, the click looks for the window titled with [Tunnel: devbox-tunnel]" {
    stub_focus_tools
    FOCUS="${BATS_TEST_DIRNAME}/../notification-focus.sh"

    OSASCRIPT_STATUS=0 run "$FOCUS" /home/mark/github/turva-5 tunnel+devbox-tunnel
    [ "$status" -eq 0 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/osascript-name")" = "turva-5 [Tunnel: devbox-tunnel]" ]
    [ ! -e "${BATS_TEST_TMPDIR}/code-args" ]
}

@test "for a tunnel, with no window in view, the click opens the folder over the tunnel" {
    stub_focus_tools
    FOCUS="${BATS_TEST_DIRNAME}/../notification-focus.sh"

    run "$FOCUS" /home/mark/github/turva-5 tunnel+devbox-tunnel
    [ "$status" -eq 0 ]
    [ "$(cat "${BATS_TEST_TMPDIR}/code-args")" = $'--folder-uri\nvscode-remote://tunnel+devbox-tunnel/home/mark/github/turva-5' ]
}

# Branded notifier apps for the icon choice: each records that it was used,
# and so does osascript, the plain banner. HOME is the test's folder, so the
# apps are looked for there.
stub_branded_apps() {
    local name
    local bin="${BATS_TEST_TMPDIR}/plain-bin"

    export HOME="${BATS_TEST_TMPDIR}/home"
    export TURVA_NOTIFY_SPEAK=0
    unset TURVA_NOTIFY_APP

    for name in quill turva juttu arnie digest kaiku mark-house-style general; do
        mkdir -p "${HOME}/Applications/${name}-notifier.app/Contents/MacOS"
        cat >"${HOME}/Applications/${name}-notifier.app/Contents/MacOS/terminal-notifier" <<EOF
#!/bin/bash
echo "${name}" >>"${BATS_TEST_TMPDIR}/apps-used"
EOF
        chmod +x "${HOME}/Applications/${name}-notifier.app/Contents/MacOS/terminal-notifier"
    done

    mkdir -p "${bin}"
    cat >"${bin}/osascript" <<EOF
#!/bin/bash
echo "plain" >>"${BATS_TEST_TMPDIR}/apps-used"
EOF
    chmod +x "${bin}/osascript"
    export PATH="${bin}:${PATH}"
}

# The icon a banner from this folder is posted with.
icon_for() {
    local folder="$1"

    "${BATS_TEST_DIRNAME}/../notification-show.sh" "${folder}" "Done" "grp" "s" "/home/mark/github/${folder}"
    cat "${BATS_TEST_TMPDIR}/apps-used"
}

@test "Quill Medical's folders get the Quill icon" {
    stub_branded_apps

    run icon_for quillmedical-6

    [ "$status" -eq 0 ]
    [ "$output" = "quill" ]
}

@test "Turva's folders get the Turva icon" {
    stub_branded_apps

    run icon_for turva-2

    [ "$status" -eq 0 ]
    [ "$output" = "turva" ]
}

@test "Juttu's folders, named after its repository, get the Juttu icon" {
    stub_branded_apps

    run icon_for juttu-messaging-2

    [ "$status" -eq 0 ]
    [ "$output" = "juttu" ]
}

@test "Arnie's folder gets the Arnie icon" {
    stub_branded_apps

    run icon_for arnie

    [ "$status" -eq 0 ]
    [ "$output" = "arnie" ]
}

@test "a folder with its own app built uses it, a worktree's number aside" {
    stub_branded_apps

    run icon_for mark-house-style
    [ "$output" = "mark-house-style" ]

    rm -f "${BATS_TEST_TMPDIR}/apps-used"
    run icon_for digest-3
    [ "$output" = "digest" ]

    rm -f "${BATS_TEST_TMPDIR}/apps-used"
    run icon_for kaiku
    [ "$output" = "kaiku" ]
}

@test "any other folder gets the general notifier, so a click still focuses" {
    stub_branded_apps

    run icon_for ledger

    [ "$status" -eq 0 ]
    [ "$output" = "general" ]
}

@test "a folder that only starts with a project's word is not that project's" {
    stub_branded_apps

    run icon_for quilltest

    [ "$status" -eq 0 ]
    [ "$output" = "general" ]
}

@test "a project whose app is not built yet falls back to the general notifier" {
    stub_branded_apps
    rm -rf "${HOME}/Applications/juttu-notifier.app"

    run icon_for juttu-messaging

    [ "$status" -eq 0 ]
    [ "$output" = "general" ]
}

@test "with no notifier built at all, the plain banner is used" {
    stub_branded_apps
    rm -rf "${HOME}/Applications/juttu-notifier.app" "${HOME}/Applications/general-notifier.app"

    run icon_for juttu-messaging

    [ "$status" -eq 0 ]
    [ "$output" = "plain" ]
}

@test "an app named in TURVA_NOTIFY_APP wins for every folder" {
    stub_branded_apps
    stub_notifier

    run "${BATS_TEST_DIRNAME}/../notification-show.sh" "quillmedical-6" "Done" "grp" "s" /home/mark/github/quillmedical-6

    [ "$status" -eq 0 ]
    [ -e "${BATS_TEST_TMPDIR}/notifier-args" ]
    [ ! -e "${BATS_TEST_TMPDIR}/apps-used" ]
}

# A stand-in for say: it speaks only in the voices in FAKE_VOICES, failing
# for any other as the real one does, and records each thing spoken as
# "<voice>|<text>", one a line. A request for the list of voices is
# recorded in "listed", as it is what made the Finnish names slow.
stub_say() {
    local bin="${BATS_TEST_TMPDIR}/say-bin"

    mkdir -p "${bin}"
    cat >"${bin}/say" <<'EOF'
#!/bin/bash
if [ "$1" = "-v" ] && [ "$2" = "?" ]; then
    echo listed >>"${BATS_TEST_TMPDIR}/listed"
    exit 0
fi
case " ${FAKE_VOICES:-} " in
    *" $2 "*) echo "$2|$3" >>"${BATS_TEST_TMPDIR}/spoken" ;;
    *) echo "Voice \`$2' not found." >&2; exit 1 ;;
esac
EOF
    chmod +x "${bin}/say"

    export PATH="${bin}:${PATH}"
    export TURVA_NOTIFY_SPEAK=1
    export TURVA_NOTIFY_BANNER=0
}

# What was spoken for a banner with this spoken name.
spoken_for() {
    local name="$1"

    "${BATS_TEST_DIRNAME}/../notification-show.sh" "t" "b" "g" "${name}"
    cat "${BATS_TEST_TMPDIR}/spoken"
}

@test "with a Finnish voice, Juttu and its number are said by it in one go" {
    stub_say
    export FAKE_VOICES="Karen Satu"

    run spoken_for "Juttu 2"

    [ "$status" -eq 0 ]
    [ "$output" = "Satu|Juttu 2" ]
}

@test "with a Finnish voice, Turva's main checkout is said as Turva alone" {
    stub_say
    export FAKE_VOICES="Karen Satu"

    run spoken_for "Turva"

    [ "$status" -eq 0 ]
    [ "$output" = "Satu|Turva" ]
}

@test "without a Finnish voice, an English spelling close to the Finnish stands in" {
    stub_say
    export FAKE_VOICES="Karen"

    run spoken_for "Juttu 2"

    [ "$status" -eq 0 ]
    [ "$output" = "Karen|Yoot-too 2" ]
}

@test "another Finnish voice can be chosen" {
    stub_say
    export FAKE_VOICES="Karen Onni"
    export TURVA_NOTIFY_FINNISH_VOICE=Onni

    run spoken_for "Turva 3"

    [ "$status" -eq 0 ]
    [ "$output" = "Onni|Turva 3" ]
}

@test "the Finnish voice is tried at once, without listing every voice first" {
    stub_say
    export FAKE_VOICES="Karen Satu"

    run spoken_for "Turva"

    [ "$output" = "Satu|Turva" ]
    [ ! -e "${BATS_TEST_TMPDIR}/listed" ]
}

@test "Digest is said as the noun, by its spoken spelling" {
    stub_say
    export FAKE_VOICES="Karen Satu"

    run spoken_for "Digest 2"

    [ "$status" -eq 0 ]
    [ "$output" = "Karen|Dye-jest 2" ]
}

@test "any other name is said as it is, by the usual voice" {
    stub_say
    export FAKE_VOICES="Karen Satu"

    run spoken_for "mark-house-style"

    [ "$status" -eq 0 ]
    [ "$output" = "Karen|mark-house-style" ]
}

@test "a checkout whose committed settings still call its own banner hook is left to it" {
    mkdir -p "${MAIN}/scripts" "${MAIN}/.claude"
    printf '#!/bin/bash\n' >"${MAIN}/scripts/notification.sh"
    printf '{"hooks": {"Stop": [{"command": "scripts/notification.sh"}]}}\n' >"${MAIN}/.claude/settings.json"

    run shown_for "$MAIN"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "once the old hook is gone from the committed settings, this one takes over" {
    mkdir -p "${MAIN}/scripts" "${MAIN}/.claude"
    printf '#!/bin/bash\n' >"${MAIN}/scripts/notification.sh"
    printf '{"hooks": {}}\n' >"${MAIN}/.claude/settings.json"

    run shown_for "$MAIN"

    [ "$status" -eq 0 ]
    [[ "$output" == *"title=Turva"* ]]
}
