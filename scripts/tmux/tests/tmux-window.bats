#!/usr/bin/env bats
# Tests for tmux-window.sh, which takes the terminal to a plain shell in
# tmux for the worktree, starting the session when it is missing.
#
# tmux is a stub that records what it was asked, so no tmux server is
# touched. Its answers come from SESSION_EXISTS and CURRENT_SESSION, and a
# server is running unless NO_SERVER=1. SESSIONS is what it lists: a line
# for each session, its name and how many terminals are attached to it. systemd-run is a stub too: it
# records its options and runs the command after them.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../tmux-window.sh"
    CALLS="${BATS_TEST_TMPDIR}/calls"
    WORKTREE="${BATS_TEST_TMPDIR}/quillmedical-3"
    unset TMUX TMUX_PANE SESSION_EXISTS CURRENT_SESSION NO_SERVER SESSIONS

    git init -q "${WORKTREE}"
    mkdir -p "${BATS_TEST_TMPDIR}/bin"

    cat > "${BATS_TEST_TMPDIR}/bin/tmux" <<EOF
#!/usr/bin/env bash
printf 'tmux %s\n' "\$*" >> "${CALLS}"
case "\$1" in
    has-session) [ "\${SESSION_EXISTS:-}" = "1" ] ;;
    list-sessions) [ "\${NO_SERVER:-}" != "1" ] && printf '%s' "\${SESSIONS:-}" ;;
    display-message) echo "\${CURRENT_SESSION:-other}" ;;
esac
EOF

    cat > "${BATS_TEST_TMPDIR}/bin/systemd-run" <<EOF
#!/usr/bin/env bash
printf 'systemd-run %s\n' "\$*" >> "${CALLS}"
while [ "\$#" -gt 0 ] && [ "\${1#--}" != "\$1" ]; do
    shift
done
exec "\$@"
EOF

    chmod +x "${BATS_TEST_TMPDIR}"/bin/*
    export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

run_in() {
    cd "$1"
    shift
    run "$SCRIPT" "$@"
}

@test "a missing session is started with a login shell in the worktree, then attached to" {
    run_in "$WORKTREE"
    [ "$status" -eq 0 ]
    grep -q "^tmux new-session -d -s quill-3-tmux -c .*quillmedical-3 bash -l$" "$CALLS"
    grep -qx "tmux attach -t =quill-3-tmux" "$CALLS"
}

@test "with no tmux server, the session starts the server in a service of its own" {
    NO_SERVER=1 run_in "$WORKTREE"
    [ "$status" -eq 0 ]
    grep -q "^systemd-run --user --quiet --collect --unit=tmux-server --property=Type=forking tmux new-session -d -s quill-3-tmux " "$CALLS"
}

@test "with a tmux server running, the session is started with no service" {
    run_in "$WORKTREE"
    [ "$status" -eq 0 ]
    [ "$(grep -c systemd-run "$CALLS")" -eq 0 ]
}

@test "outside tmux, an existing session is attached to and not started again" {
    SESSION_EXISTS=1 run_in "$WORKTREE"
    [ "$status" -eq 0 ]
    grep -qx "tmux attach -t =quill-3-tmux" "$CALLS"
    [ "$(grep -c new-session "$CALLS")" -eq 0 ]
}

@test "nothing is typed into a running shell" {
    SESSION_EXISTS=1 run_in "$WORKTREE"
    [ "$(grep -c send-keys "$CALLS")" -eq 0 ]
}

@test "a new session has the backend's virtual environment switched on, when the worktree has one" {
    mkdir -p "${WORKTREE}/backend/.venv/bin"
    touch "${WORKTREE}/backend/.venv/bin/activate"

    run_in "$WORKTREE"
    [ "$status" -eq 0 ]
    grep -q "^tmux send-keys -t =quill-3-tmux: source .*quillmedical-3/backend/.venv/bin/activate Enter$" "$CALLS"
    # Typed into the new, empty shell, before anybody is attached to it.
    [ "$(grep -n send-keys "$CALLS" | cut -d: -f1)" -lt "$(grep -n attach "$CALLS" | cut -d: -f1)" ]
}

@test "a new session in a worktree with no virtual environment is left as a plain shell" {
    run_in "$WORKTREE"
    [ "$status" -eq 0 ]
    [ "$(grep -c send-keys "$CALLS")" -eq 0 ]
}

@test "a running session is never typed into, even with a virtual environment" {
    mkdir -p "${WORKTREE}/backend/.venv/bin"
    touch "${WORKTREE}/backend/.venv/bin/activate"

    SESSION_EXISTS=1 run_in "$WORKTREE"
    [ "$(grep -c send-keys "$CALLS")" -eq 0 ]
}

@test "a subdirectory of the worktree finds the same session" {
    mkdir -p "${WORKTREE}/frontend/src"

    SESSION_EXISTS=1 run_in "${WORKTREE}/frontend/src"
    grep -qx "tmux attach -t =quill-3-tmux" "$CALLS"
}

@test "the main checkout is quill-tmux" {
    git init -q "${BATS_TEST_TMPDIR}/quillmedical"

    SESSION_EXISTS=1 run_in "${BATS_TEST_TMPDIR}/quillmedical"
    grep -qx "tmux attach -t =quill-tmux" "$CALLS"
}

@test "quillmedical-owl is owl-tmux" {
    git init -q "${BATS_TEST_TMPDIR}/quillmedical-owl"

    run_in "${BATS_TEST_TMPDIR}/quillmedical-owl"
    [ "$status" -eq 0 ]
    grep -q "^tmux new-session -d -s owl-tmux " "$CALLS"
}

@test "worktree 5 is quill-5-tmux, with no refusal for Owl" {
    git init -q "${BATS_TEST_TMPDIR}/quillmedical-5"

    run_in "${BATS_TEST_TMPDIR}/quillmedical-5"
    [ "$status" -eq 0 ]
    grep -q "^tmux new-session -d -s quill-5-tmux " "$CALLS"
}

@test "worktrees past 5 get their own session" {
    git init -q "${BATS_TEST_TMPDIR}/quillmedical-6"
    git init -q "${BATS_TEST_TMPDIR}/quillmedical-12"

    SESSION_EXISTS=1 run_in "${BATS_TEST_TMPDIR}/quillmedical-6"
    [ "$status" -eq 0 ]
    SESSION_EXISTS=1 run_in "${BATS_TEST_TMPDIR}/quillmedical-12"
    [ "$status" -eq 0 ]

    grep -qx "tmux attach -t =quill-6-tmux" "$CALLS"
    grep -qx "tmux attach -t =quill-12-tmux" "$CALLS"
}

@test "a number starts another session for the same worktree, beside the first" {
    run_in "$WORKTREE" 2
    [ "$status" -eq 0 ]
    grep -q "^tmux new-session -d -s quill-3-tmux-2 -c .*quillmedical-3 bash -l$" "$CALLS"
    grep -qx "tmux attach -t =quill-3-tmux-2" "$CALLS"
}

@test "a number comes back to its session when it is running" {
    SESSION_EXISTS=1 run_in "$WORKTREE" 12
    [ "$status" -eq 0 ]
    grep -qx "tmux attach -t =quill-3-tmux-12" "$CALLS"
    [ "$(grep -c new-session "$CALLS")" -eq 0 ]
}

@test "from another tmux session, a numbered one is switched to" {
    export TMUX=/tmp/tmux-test TMUX_PANE=%1 CURRENT_SESSION=quill-3-tmux

    SESSION_EXISTS=1 run_in "$WORKTREE" 2
    [ "$status" -eq 0 ]
    grep -qx "tmux switch-client -t =quill-3-tmux-2" "$CALLS"
}

@test "next is the second shell when no other is running" {
    run_in "$WORKTREE" next
    [ "$status" -eq 0 ]
    grep -q "^tmux new-session -d -s quill-3-tmux-2 -c .*quillmedical-3 bash -l$" "$CALLS"
    grep -qx "tmux attach -t =quill-3-tmux-2" "$CALLS"
}

@test "next passes over a shell a terminal is showing" {
    export SESSIONS=$'quill-3-tmux 1\nquill-3-tmux-2 1\n'

    run_in "$WORKTREE" next
    [ "$status" -eq 0 ]
    grep -q "^tmux new-session -d -s quill-3-tmux-3 " "$CALLS"
}

@test "next comes back to a running shell nobody is attached to, and starts no other" {
    export SESSIONS=$'quill-3-tmux-2 0\nquill-3-tmux-3 1\n'

    SESSION_EXISTS=1 run_in "$WORKTREE" next
    [ "$status" -eq 0 ]
    grep -qx "tmux attach -t =quill-3-tmux-2" "$CALLS"
    [ "$(grep -c new-session "$CALLS")" -eq 0 ]
}

@test "next fills a gap before going past the last shell showing" {
    export SESSIONS=$'quill-3-tmux-2 1\nquill-3-tmux-4 2\n'

    run_in "$WORKTREE" next
    [ "$status" -eq 0 ]
    grep -q "^tmux new-session -d -s quill-3-tmux-3 " "$CALLS"
}

@test "next counts only this checkout's shells" {
    export SESSIONS=$'quill-30-tmux-2 1\nquill-3-tmux-22 1\nq3 1\nturva-tmux-2 1\n'

    run_in "$WORKTREE" next
    [ "$status" -eq 0 ]
    grep -q "^tmux new-session -d -s quill-3-tmux-2 " "$CALLS"
}

@test "next with no tmux server is the second shell" {
    NO_SERVER=1 run_in "$WORKTREE" next
    [ "$status" -eq 0 ]
    grep -q "tmux new-session -d -s quill-3-tmux-2 " "$CALLS"
}

@test "next is refused when every shell is showing" {
    SESSIONS="$(for number in $(seq 2 99); do echo "quill-3-tmux-${number} 1"; done)"
    export SESSIONS

    run_in "$WORKTREE" next
    [ "$status" -eq 1 ]
    [[ "$output" == *"up to quill-3-tmux-99, is showing in a terminal"* ]]
    [ "$(grep -c -e "tmux new-session" -e "tmux attach" "$CALLS")" -eq 0 ]
}

@test "a number outside 2 to 99 is refused before tmux is asked anything" {
    for number in 0 1 100 02 two "2;ls" -2 Next; do
        run_in "$WORKTREE" "$number"
        [ "$status" -eq 1 ]
        [[ "$output" == *"runs from 2 to 99"* ]]
    done

    [ ! -e "$CALLS" ]
}

@test "from another tmux session, it switches rather than nesting" {
    export TMUX=/tmp/tmux-test TMUX_PANE=%1

    SESSION_EXISTS=1 run_in "$WORKTREE"
    [ "$status" -eq 0 ]
    grep -qx "tmux switch-client -t =quill-3-tmux" "$CALLS"
    [ "$(grep -c attach "$CALLS")" -eq 0 ]
}

@test "inside the session already, nothing is done" {
    export TMUX=/tmp/tmux-test TMUX_PANE=%1 CURRENT_SESSION=quill-3-tmux

    SESSION_EXISTS=1 run_in "$WORKTREE"
    [ "$status" -eq 0 ]
    [ "$(grep -c -e switch-client -e attach -e new-session "$CALLS")" -eq 0 ]
}

@test "a folder that is none of the projects is refused" {
    git init -q "${BATS_TEST_TMPDIR}/elsewhere"

    run_in "${BATS_TEST_TMPDIR}/elsewhere"
    [ "$status" -eq 1 ]
    [[ "$output" == *"is not a Quill Medical, Turva, Juttu, Arnie or Digest checkout"* ]]
    [ ! -e "$CALLS" ] || [ "$(grep -c -e new-session -e attach "$CALLS")" -eq 0 ]
}

@test "outside a git repository it is refused" {
    run_in "$BATS_TEST_TMPDIR"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Run this from a Quill Medical, Turva, Juttu, Arnie or Digest checkout"* ]]
}

@test "Turva's main checkout has no number" {
    git init -q "${BATS_TEST_TMPDIR}/turva"

    run_in "${BATS_TEST_TMPDIR}/turva"
    grep -q "^tmux new-session -d -s turva-tmux " "$CALLS"
}

@test "a Turva main checkout's second shell is kept apart from turva-2's first" {
    git init -q "${BATS_TEST_TMPDIR}/turva"

    run_in "${BATS_TEST_TMPDIR}/turva" 2
    grep -q "^tmux new-session -d -s turva-tmux-2 " "$CALLS"
}

@test "a Turva worktree's shell carries its number before -tmux" {
    git init -q "${BATS_TEST_TMPDIR}/turva-2"

    run_in "${BATS_TEST_TMPDIR}/turva-2"
    grep -q "^tmux new-session -d -s turva-2-tmux " "$CALLS"
}

@test "Juttu's shells use the short name juttu" {
    git init -q "${BATS_TEST_TMPDIR}/juttu-messaging"
    git init -q "${BATS_TEST_TMPDIR}/juttu-messaging-3"

    run_in "${BATS_TEST_TMPDIR}/juttu-messaging"
    run_in "${BATS_TEST_TMPDIR}/juttu-messaging-3"

    grep -q "^tmux new-session -d -s juttu-tmux " "$CALLS"
    grep -q "^tmux new-session -d -s juttu-3-tmux " "$CALLS"
}

@test "Arnie's and Digest's shells are arnie-tmux and digest-tmux" {
    git init -q "${BATS_TEST_TMPDIR}/arnie"
    git init -q "${BATS_TEST_TMPDIR}/digest"

    run_in "${BATS_TEST_TMPDIR}/arnie"
    run_in "${BATS_TEST_TMPDIR}/digest" 2

    grep -q "^tmux new-session -d -s arnie-tmux " "$CALLS"
    grep -q "^tmux new-session -d -s digest-tmux-2 " "$CALLS"
}
