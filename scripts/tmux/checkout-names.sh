#!/usr/bin/env bash
# Names a checkout's tmux sessions, for claude-session.sh and tmux-window.sh.
# Sourced, not run, so the names it sets are used by the script that sources it.
# shellcheck disable=SC2034
#
# checkout_names <folder> sets three names from the checkout's folder, and
# CONTINUE_CLAUDE, or returns 1 for a folder that is none of these:
#
#   folder              CLAUDE_SESSION  SHELL_SESSION   REMOTE_NAME
#   quillmedical        q1              quill-tmux      quillmedical
#   quillmedical-6      q6              quill-6-tmux    quillmedical-6
#   quillmedical-owl    owl             owl-tmux        quillmedical-owl
#   turva               turva           turva-tmux      turva
#   turva-2             turva-2         turva-2-tmux    turva-2
#   juttu-messaging     juttu           juttu-tmux      juttu
#   juttu-messaging-3   juttu-3         juttu-3-tmux    juttu-3
#   arnie               arnie           arnie-tmux      arnie
#   digest              digest          digest-tmux     digest
#
# REMOTE_NAME is the name Claude's remote control shows on claude.ai. Quill
# Medical's keeps the folder name it has always had. Juttu's folder is
# juttu-messaging, after its GitHub repository, but its names keep the short
# name juttu.
#
# SHELL_SESSION is the checkout's short name, then "-tmux". tmux-window.sh
# adds a number for a second shell, after "-tmux", so a main checkout's
# second shell, turva-tmux-2, cannot be taken for turva-2's first,
# turva-2-tmux. scripts/tmux/titles.conf turns the name into the tab's
# title, such as "Turva Tmux-2".
#
# CONTINUE_CLAUDE is false for Digest, whose Claude starts a fresh
# conversation each time, as its own scripts/digest-session does, so a
# restart never picks up a nightly run's conversation.

checkout_names() {
    local folder="$1"

    case "${folder}" in
        quillmedical)
            CLAUDE_SESSION="q1"
            SHELL_SESSION="quill-tmux"
            ;;
        quillmedical-[2-9] | quillmedical-[1-9][0-9])
            CLAUDE_SESSION="q${folder#quillmedical-}"
            SHELL_SESSION="quill-${folder#quillmedical-}-tmux"
            ;;
        quillmedical-owl)
            CLAUDE_SESSION="owl"
            SHELL_SESSION="owl-tmux"
            ;;
        turva)
            CLAUDE_SESSION="turva"
            SHELL_SESSION="turva-tmux"
            ;;
        turva-[2-9] | turva-[1-9][0-9])
            CLAUDE_SESSION="${folder}"
            SHELL_SESSION="${folder}-tmux"
            ;;
        juttu-messaging)
            CLAUDE_SESSION="juttu"
            SHELL_SESSION="juttu-tmux"
            ;;
        juttu-messaging-[2-9] | juttu-messaging-[1-9][0-9])
            CLAUDE_SESSION="juttu-${folder#juttu-messaging-}"
            SHELL_SESSION="${CLAUDE_SESSION}-tmux"
            ;;
        arnie | digest)
            CLAUDE_SESSION="${folder}"
            SHELL_SESSION="${folder}-tmux"
            ;;
        *)
            return 1
            ;;
    esac

    case "${folder}" in
        quillmedical*) REMOTE_NAME="${folder}" ;;
        *) REMOTE_NAME="${CLAUDE_SESSION}" ;;
    esac

    CONTINUE_CLAUDE=true
    if [ "${folder}" = "digest" ]; then
        CONTINUE_CLAUDE=false
    fi

    return 0
}

readonly CHECKOUT_REFUSAL="is not a Quill Medical, Turva, Juttu, Arnie or Digest checkout. Sessions are named after quillmedical, turva or juttu-messaging, or any of them with -<number>, and arnie or digest."
