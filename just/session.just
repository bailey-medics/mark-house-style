# Claude and shell sessions in tmux
#
# One tmux session per checkout, for Claude and for a plain shell. Kept in a
# file of its own so other repositories can load it with `import?` and run
# `just cc` or `just tw`, while mark-house-style's own justfile loads it for
# `just -g`. The short name is cc, not c, which Turva uses for clean.


alias cc := claude-session
# Go to this checkout's Claude session in tmux, starting it or Claude again if needed
[no-cd]
claude-session:
    #!/usr/bin/env bash
    # Opens this checkout's Claude session in this terminal, and makes sure
    # Claude is running in it.
    #
    # The session is named after the folder: turva, or juttu for the
    # juttu-messaging folder, for a main checkout, and turva-2 or juttu-2 for
    # the worktree in turva-2 or juttu-messaging-2.
    #
    # - If there is no claude tmux session, it starts one with Claude in it.
    # - If Claude has stopped but the tmux session exists, it starts Claude
    # again.
    # - You can run it from outside tmux, or from another tmux session.
    #
    # Claude started here is linked to the VS Code window. If Claude was
    # already running, type /ide in it to link it.

    set -euo pipefail

    if ! command -v tmux > /dev/null; then
        echo "✗ tmux is not installed." >&2
        exit 1
    fi

    top="$(git rev-parse --show-toplevel)"
    folder="$(basename "${top}")"

    # A main checkout's sessions are named after its project, turva or
    # juttu, and a worktree adds a number: turva-2, juttu-3. The number keeps
    # each one's sessions apart. Juttu's folder is juttu-messaging, after its
    # GitHub repository, but its sessions keep the short name juttu.
    case "${folder}" in
        turva)
            project="turva"
            worktree=""
            ;;
        juttu-messaging)
            project="juttu"
            worktree=""
            ;;
        turva-[2-9] | turva-[1-9][0-9])
            project="turva"
            worktree="${folder##*-}"
            ;;
        juttu-messaging-[2-9] | juttu-messaging-[1-9][0-9])
            project="juttu"
            worktree="${folder##*-}"
            ;;
        *)
            echo "✗ This folder is ${folder}. Sessions are named after turva, juttu-messaging, or either with -<number>, so rename the folder to one of those." >&2
            exit 1
            ;;
    esac

    name="${project}${worktree:+-${worktree}}"
    start_claude="claude --continue --ide --remote-control ${name} || claude --ide --remote-control ${name}"

    if ! tmux has-session -t "=${name}" 2> /dev/null; then
        tmux new-session -d -s "${name}" -c "${top}" "bash -lc '${start_claude}; exec bash'"
        echo "Started ${name} in ${top}"
    else
        pane_id="$(tmux display-message -p -t "=${name}:" "#{pane_id}")"
        pane_pid="$(tmux display-message -p -t "=${name}:" "#{pane_pid}")"

        # The pane is its process session's leader, so its pid is the session id.
        if ! pgrep -x -s "${pane_pid}" claude > /dev/null; then

            # This terminal is the pane, so start Claude here.
            if [ "${TMUX_PANE:-}" = "${pane_id}" ]; then
                cd "${top}"
                bash -c "${start_claude}"
                exit 0
            fi

            tmux send-keys -t "${pane_id}" "${start_claude}" Enter
            echo "Started Claude again in ${name}"
        fi
    fi

    if [ -n "${TMUX:-}" ]; then
        if [ "$(tmux display-message -p "#{session_name}")" = "${name}" ]; then
            exit 0
        fi

        exec tmux switch-client -t "=${name}"
    fi

    exec tmux attach -t "=${name}"


alias tw := tmux-window
# Go to a plain shell in tmux for this checkout, starting it if needed; `just -g tw 2` for a second
[no-cd]
tmux-window NUMBER="":
    #!/usr/bin/env bash
    # Opens a plain shell in tmux for this checkout, so a command run there
    # keeps going after this terminal closes.
    #
    # The session is tmux-turva-1 or tmux-juttu-1 for a main checkout, and
    # tmux-turva-2 for the worktree in turva-2. A number gives another shell beside the
    # first: `just -g tw 2` is tmux-turva-1-2 in the main checkout, and running
    # it again comes back to it.
    #
    # It starts the session, with a login shell in the checkout, if there
    # is none. Then it attaches from outside tmux, or switches from another
    # tmux session.

    set -euo pipefail

    number={{quote(NUMBER)}}

    case "${number}" in
        "" | [2-9] | [1-9][0-9]) ;;
        *)
            echo "✗ The number names another shell beside the first, so it runs from 2 to 99: just -g tw 2" >&2
            exit 1
            ;;
    esac

    if ! command -v tmux > /dev/null; then
        echo "✗ tmux is not installed." >&2
        exit 1
    fi

    top="$(git rev-parse --show-toplevel)"
    folder="$(basename "${top}")"

    # A main checkout's sessions are named after its project, turva or
    # juttu, and a worktree adds a number: turva-2, juttu-3. The number keeps
    # each one's sessions apart. Juttu's folder is juttu-messaging, after its
    # GitHub repository, but its sessions keep the short name juttu.
    case "${folder}" in
        turva)
            project="turva"
            worktree=""
            ;;
        juttu-messaging)
            project="juttu"
            worktree=""
            ;;
        turva-[2-9] | turva-[1-9][0-9])
            project="turva"
            worktree="${folder##*-}"
            ;;
        juttu-messaging-[2-9] | juttu-messaging-[1-9][0-9])
            project="juttu"
            worktree="${folder##*-}"
            ;;
        *)
            echo "✗ This folder is ${folder}. Sessions are named after turva, juttu-messaging, or either with -<number>, so rename the folder to one of those." >&2
            exit 1
            ;;
    esac

    # The main checkout counts as 1 here, so its second shell,
    # tmux-turva-1-2, cannot be mistaken for the first shell of turva-2,
    # which is tmux-turva-2.
    name="tmux-${project}-${worktree:-1}${number:+-${number}}"

    if ! tmux has-session -t "=${name}" 2> /dev/null; then
        tmux new-session -d -s "${name}" -c "${top}" "bash -l"
        echo "Started ${name} in ${top}"
    fi

    if [ -n "${TMUX:-}" ]; then
        if [ "$(tmux display-message -p "#{session_name}")" = "${name}" ]; then
            exit 0
        fi

        exec tmux switch-client -t "=${name}"
    fi

    exec tmux attach -t "=${name}"
