#!/usr/bin/env bats
# Tests for titles.conf, run against a tmux server of their own, so no
# session the developer has open is touched.

CONF="${BATS_TEST_DIRNAME}/../titles.conf"

setup() {
    SOCKET="titles-test-$$-${BATS_TEST_NUMBER}"
    tmux -L "${SOCKET}" -f /dev/null start-server \; set -g exit-empty off
    tmux -L "${SOCKET}" source-file "${CONF}"
}

teardown() {
    tmux -L "${SOCKET}" kill-server 2>/dev/null || true
}

# Prints the tab title tmux would show for a new session with this name,
# with Claude Code's idle pane title, and the topic if one is given.
title_for() {
    local session="$1"
    local topic="${2:-}"

    tmux -L "${SOCKET}" new-session -d -s "${session}"
    tmux -L "${SOCKET}" select-pane -t "${session}" -T "✳ Claude Code"

    if [ -n "${topic}" ]; then
        tmux -L "${SOCKET}" set-option -t "${session}" @topic "${topic}"
    fi

    tmux -L "${SOCKET}" display-message -p -t "${session}" \
        '#{T:set-titles-string}'
}

@test "Quill's main checkout is the bare name" {
    run title_for q1 "Tab names"
    [ "$output" = "Quill Tab names" ]
}

@test "a Quill worktree carries its number" {
    run title_for q6 "Tab names"
    [ "$output" = "Quill-6 Tab names" ]
}

@test "a two-digit Quill worktree keeps both digits" {
    run title_for q12 "Tab names"
    [ "$output" = "Quill-12 Tab names" ]
}

@test "Turva's main checkout is the bare name" {
    run title_for turva "Hazard log"
    [ "$output" = "Turva Hazard log" ]
}

@test "a Turva worktree carries its number" {
    run title_for turva-2 "Hazard log"
    [ "$output" = "Turva-2 Hazard log" ]
}

@test "Juttu's main checkout is the bare name" {
    run title_for juttu "Inbox"
    [ "$output" = "Juttu Inbox" ]
}

@test "a Juttu worktree carries its number" {
    run title_for juttu-3 "Inbox"
    [ "$output" = "Juttu-3 Inbox" ]
}

@test "Owl's tab is Owl and its topic" {
    run title_for owl "Alert 42"
    [ "$output" = "Owl Alert 42" ]
}

@test "Arnie's and Digest's tabs are their names and the topic" {
    run title_for arnie "Boiler timer"
    [ "$output" = "Arnie Boiler timer" ]
    run title_for digest "Nightly run"
    [ "$output" = "Digest Nightly run" ]
}

@test "with no topic, a Quill, Turva or Juttu tab shows ---" {
    tmux -L "${SOCKET}" new-session -d -s q6
    tmux -L "${SOCKET}" select-pane -t q6 -T "✳ quill-6"

    run tmux -L "${SOCKET}" display-message -p -t q6 '#{T:set-titles-string}'
    [ "$output" = "Quill-6 ---" ]

    run title_for turva-2
    [ "$output" = "Turva-2 ---" ]

    run title_for juttu
    [ "$output" = "Juttu ---" ]
}

@test "with no topic, Owl's working title stands in" {
    tmux -L "${SOCKET}" new-session -d -s owl
    tmux -L "${SOCKET}" select-pane -t owl -T "⠂ Fixing the tests"

    run tmux -L "${SOCKET}" display-message -p -t owl '#{T:set-titles-string}'

    [ "$output" = "Owl Fixing the tests" ]
}

@test "with no topic, an idle Owl, Arnie or Digest is the label alone" {
    run title_for owl
    [ "$output" = "Owl" ]

    run title_for arnie
    [ "$output" = "Arnie" ]

    run title_for digest
    [ "$output" = "Digest" ]
}

@test "a checkout's first shell is its label and Tmux, with no number" {
    run title_for quill-6-tmux
    [ "$output" = "Quill-6 Tmux" ]

    run title_for turva-2-tmux
    [ "$output" = "Turva-2 Tmux" ]

    run title_for juttu-3-tmux
    [ "$output" = "Juttu-3 Tmux" ]
}

@test "a later shell carries its number" {
    run title_for quill-6-tmux-2
    [ "$output" = "Quill-6 Tmux-2" ]

    run title_for turva-2-tmux-3
    [ "$output" = "Turva-2 Tmux-3" ]

    run title_for juttu-3-tmux-12
    [ "$output" = "Juttu-3 Tmux-12" ]
}

@test "a main checkout's shell has the bare label" {
    run title_for quill-tmux
    [ "$output" = "Quill Tmux" ]

    run title_for quill-tmux-2
    [ "$output" = "Quill Tmux-2" ]

    run title_for turva-tmux
    [ "$output" = "Turva Tmux" ]

    run title_for turva-tmux-2
    [ "$output" = "Turva Tmux-2" ]

    run title_for juttu-tmux
    [ "$output" = "Juttu Tmux" ]
}

@test "a two-digit worktree's shell keeps both digits" {
    run title_for quill-12-tmux
    [ "$output" = "Quill-12 Tmux" ]

    run title_for quill-12-tmux-2
    [ "$output" = "Quill-12 Tmux-2" ]

    run title_for turva-12-tmux
    [ "$output" = "Turva-12 Tmux" ]
}

@test "Owl's, Arnie's and Digest's shells read the same way" {
    run title_for owl-tmux
    [ "$output" = "Owl Tmux" ]

    run title_for owl-tmux-2
    [ "$output" = "Owl Tmux-2" ]

    run title_for arnie-tmux
    [ "$output" = "Arnie Tmux" ]

    run title_for arnie-tmux-2
    [ "$output" = "Arnie Tmux-2" ]

    run title_for digest-tmux
    [ "$output" = "Digest Tmux" ]
}

@test "a shell's tab ignores what runs in it" {
    tmux -L "${SOCKET}" new-session -d -s quill-6-tmux
    tmux -L "${SOCKET}" select-pane -t quill-6-tmux -T "vim README.md"

    run tmux -L "${SOCKET}" display-message -p -t quill-6-tmux '#{T:set-titles-string}'

    [ "$output" = "Quill-6 Tmux" ]
}

@test "a shell lookalike shows its own name" {
    run title_for arnie-tmuxer
    [ "$output" = "arnie-tmuxer" ]

    run title_for quill-six-tmux
    [ "$output" = "quill-six-tmux" ]

    run title_for quill-6-tmux-two
    [ "$output" = "quill-6-tmux-two" ]

    run title_for owl-2-tmux
    [ "$output" = "owl-2-tmux" ]
}

@test "a turva lookalike is not a Claude tab" {
    run title_for turvax
    [ "$output" = "turvax" ]
}

@test "any other session shows its own name" {
    run title_for voice-test
    [ "$output" = "voice-test" ]
}
