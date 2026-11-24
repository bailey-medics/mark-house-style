#!/usr/bin/env bash
# Names a checkout's tmux sessions, for claude-session.sh and tmux-window.sh.
# Sourced, not run, so the names it sets are used by the script that sources it.
# shellcheck disable=SC2034
#
# checkout_names <folder> sets three names from the checkout's folder, or
# returns 1 for a folder that is none of these:
#
#   folder              CLAUDE_SESSION  SHELL_SESSION   REMOTE_NAME
#   quillmedical        q1              t1              quillmedical
#   quillmedical-6      q6              t6              quillmedical-6
#   quillmedical-owl    owl             towl            quillmedical-owl
#   turva               turva           tmux-turva-1    turva
#   turva-2             turva-2         tmux-turva-2    turva-2
#   juttu-messaging     juttu           tmux-juttu-1    juttu
#   juttu-messaging-3   juttu-3         tmux-juttu-3    juttu-3
#
# REMOTE_NAME is the name Claude's remote control shows on claude.ai. Quill
# Medical's keeps the folder name it has always had. Juttu's folder is
# juttu-messaging, after its GitHub repository, but its names keep the short
# name juttu. A Turva or Juttu main checkout's shell counts as 1, so its
# second shell, tmux-turva-1-2, cannot be taken for turva-2's first.

checkout_names() {
    local folder="$1"

    case "${folder}" in
        quillmedical)
            CLAUDE_SESSION="q1"
            SHELL_SESSION="t1"
            ;;
        quillmedical-[2-9] | quillmedical-[1-9][0-9])
            CLAUDE_SESSION="q${folder#quillmedical-}"
            SHELL_SESSION="t${folder#quillmedical-}"
            ;;
        quillmedical-owl)
            CLAUDE_SESSION="owl"
            SHELL_SESSION="towl"
            ;;
        turva)
            CLAUDE_SESSION="turva"
            SHELL_SESSION="tmux-turva-1"
            ;;
        turva-[2-9] | turva-[1-9][0-9])
            CLAUDE_SESSION="${folder}"
            SHELL_SESSION="tmux-${folder}"
            ;;
        juttu-messaging)
            CLAUDE_SESSION="juttu"
            SHELL_SESSION="tmux-juttu-1"
            ;;
        juttu-messaging-[2-9] | juttu-messaging-[1-9][0-9])
            CLAUDE_SESSION="juttu-${folder#juttu-messaging-}"
            SHELL_SESSION="tmux-${CLAUDE_SESSION}"
            ;;
        *)
            return 1
            ;;
    esac

    case "${folder}" in
        quillmedical*) REMOTE_NAME="${folder}" ;;
        *) REMOTE_NAME="${CLAUDE_SESSION}" ;;
    esac

    return 0
}

readonly CHECKOUT_REFUSAL="is not a Quill Medical, Turva or Juttu checkout. Sessions are named after quillmedical, turva or juttu-messaging, or any of them with -<number>."
