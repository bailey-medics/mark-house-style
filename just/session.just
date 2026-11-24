# Claude and shell sessions in tmux
#
# One tmux session per checkout, for Claude and for a plain shell, in Quill
# Medical, Turva and Juttu alike. The names come from
# scripts/tmux/checkout-names.sh. Kept in a file of its own so other
# repositories can load it with `import?` and run `just cc` or `just tw`,
# while mark-house-style's own justfile loads it for `just -g`. The short
# name is cc, not c, which Turva uses for clean.

session_scripts := source_directory() / ".." / "scripts" / "tmux"


alias cc := claude-session
# Go to this checkout's Claude session in tmux, starting it or Claude again if needed
[no-cd]
claude-session:
    @bash "{{session_scripts}}/claude-session.sh"


alias sest := session-test
# Run the tmux session scripts' tests
[no-cd]
session-test:
    bats "{{session_scripts}}/tests"


alias tw := tmux-window
# Go to a plain shell in tmux for this checkout, starting it if needed; `just tw 2` for a second
[no-cd]
tmux-window NUMBER="":
    @bash "{{session_scripts}}/tmux-window.sh" {{quote(NUMBER)}}
