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
    run title_for q12
    [ "$output" = "Quill-12" ]
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
    run title_for juttu
    [ "$output" = "Juttu" ]
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

@test "Arnie's shell is Tmux arnie" {
    run title_for t-arnie
    [ "$output" = "Tmux arnie" ]
}

@test "with no topic, Claude Code's working title stands in" {
    tmux -L "${SOCKET}" new-session -d -s q6
    tmux -L "${SOCKET}" select-pane -t q6 -T "⠂ Fixing the tests"

    run tmux -L "${SOCKET}" display-message -p -t q6 '#{T:set-titles-string}'

    [ "$output" = "Quill-6 Fixing the tests" ]
}

@test "a plain t shell keeps its Tmux name" {
    run title_for t3
    [ "$output" = "Tmux T3" ]
}

@test "a tmux- shell drops the prefix" {
    run title_for tmux-turva-1-2
    [ "$output" = "Tmux turva-1-2" ]
}

@test "Owl's shell is Tmux Owl" {
    run title_for towl
    [ "$output" = "Tmux Owl" ]
}

@test "a turva lookalike is not a Claude tab" {
    run title_for turvax
    [ "$output" = "turvax" ]
}

@test "any other session shows its own name" {
    run title_for voice-test
    [ "$output" = "voice-test" ]
}
