#!/usr/bin/env bash
# Take this terminal to the checkout's Claude Code session on the dev box,
# with Claude running in it, whatever state either is in. Run by `just cc`.
#
# Each checkout has one tmux session, named by checkout-names.sh: q1 for
# Quill Medical's main checkout and q6 for quillmedical-6, owl for Owl's
# quillmedical-owl, turva and turva-2 for Turva, and juttu and juttu-3 for
# Juttu, and arnie, digest and kaiku. This:
#
#   - starts the session, with Claude in it, when there is none, through
#     the checkout's own scripts/<session>-session when it has one, as
#     Arnie and Digest do, since that is what starts it at boot;
#   - starts Claude again in it when Claude has exited and left the shell;
#   - attaches from outside tmux, or switches from another session.
#
# Run from the session's own shell after Claude has exited, it starts
# Claude right there, in the foreground, since the shell is the pane.
#
# Claude carries on its last conversation, or starts a fresh one in
# Digest, which checkout-names.sh says through CONTINUE_CLAUDE.
#
# Claude starts with --ide, which links it to the VS Code window open on
# the devbox when there is exactly one, so it sees the file and lines
# highlighted there. A Claude already running cannot be linked from
# outside, so attaching to one from VS Code's terminal shows a note to
# type /ide instead. Nothing is typed into it: keys sent to a busy
# session land in whatever is half written there.
#
# Whether Claude is running is read from the processes in the pane's
# session, not from tmux's pane_current_command: a pane started with
# `bash -lc 'claude ...'` reports bash while Claude runs as its child.
#
# If this is the first session on the box, start-tmux.sh starts the tmux
# server in a service of its own, so it does not belong to the terminal's.
#
# The owl session belongs to Owl while quill-owl.service is enabled. Its
# Claude needs Owl's environment and allowlist, which only Quill Medical's
# scripts/owl/start-session.sh gives it, so a missing
# session or a stopped Claude there is refused and the fix named.

set -euo pipefail

if ! command -v tmux > /dev/null; then
    echo "✗ tmux is not installed. This is for the dev box." >&2
    exit 1
fi

if ! top="$(git rev-parse --show-toplevel 2> /dev/null)"; then
    echo "✗ Run this from a Quill Medical, Turva, Juttu, Arnie, Digest or Kaiku checkout." >&2
    exit 1
fi

# shellcheck source=checkout-names.sh
source "$(dirname "${BASH_SOURCE[0]}")/checkout-names.sh"
# shellcheck source=start-tmux.sh
source "$(dirname "${BASH_SOURCE[0]}")/start-tmux.sh"

if ! checkout_names "$(basename "${top}")"; then
    echo "✗ ${top} ${CHECKOUT_REFUSAL}" >&2
    exit 1
fi

name="${CLAUDE_SESSION}"
starter="${top}/scripts/${name}-session"

if [ "${CONTINUE_CLAUDE}" = true ]; then
    start_claude="claude --continue --ide --remote-control ${REMOTE_NAME} || claude --ide --remote-control ${REMOTE_NAME}"
else
    start_claude="claude --ide --remote-control ${REMOTE_NAME}"
fi

watcher_owns_it=false
claude_was_running=false

if [ "${name}" = "owl" ] && systemctl --user is-enabled --quiet quill-owl.service 2> /dev/null; then
    watcher_owns_it=true
fi

refuse_for_watcher() {
    echo "✗ The owl session belongs to Owl, and its Claude needs Owl's flags. Start it again from quillmedical-owl with:" >&2
    echo "    just owl-restart" >&2
    exit 1
}

if ! tmux has-session -t "=${name}" 2> /dev/null; then
    [ "${watcher_owns_it}" = false ] || refuse_for_watcher

    if [ -x "${starter}" ]; then
        "${starter}"
    else
        start_tmux new-session -d -s "${name}" -c "${top}" "bash -lc '${start_claude}; exec bash'"
        echo "Started ${name} in ${top}"
    fi
else
    pane_id="$(tmux display-message -p -t "=${name}:" '#{pane_id}')"
    pane_pid="$(tmux display-message -p -t "=${name}:" '#{pane_pid}')"

    # The pane is its process session's leader, so its pid is the session id.
    if ! pgrep -x -s "${pane_pid}" claude > /dev/null; then
        [ "${watcher_owns_it}" = false ] || refuse_for_watcher

        # This terminal is the pane, so start Claude here. Typing it in
        # with send-keys would land behind this script, at the same prompt.
        if [ "${TMUX_PANE:-}" = "${pane_id}" ]; then
            cd "${top}"
            bash -c "${start_claude}"
            exit 0
        fi

        tmux send-keys -t "${pane_id}" "${start_claude}" Enter
        echo "Started Claude again in ${name}"
    else
        claude_was_running=true
    fi
fi

if [ -n "${TMUX:-}" ]; then
    if [ "$(tmux display-message -p '#{session_name}')" = "${name}" ]; then
        exit 0
    fi

    exec tmux switch-client -t "=${name}"
fi

# Inside tmux, TERM_PROGRAM names tmux rather than the terminal, so VS
# Code's terminal is only recognised from outside, which is where the
# link is wanted. VS Code moves to a new port each time it restarts, so
# a Claude already running may hold a link that no longer answers. The
# note says to type /ide rather than typing it: VS Code reattaches its
# terminal itself after the connection drops, and /ide typed then landed
# in Claude's input, among whatever was half written there.
if [ "${claude_was_running}" = true ] && [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    exec tmux attach -t "=${name}" \; display-message -d 5000 "Type /ide to link Claude to VS Code again"
fi

exec tmux attach -t "=${name}"
