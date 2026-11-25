# Terminal tab titles from tmux

`just -g cc` and `just -g tw` name their tmux sessions after the Turva or Juttu
folder they are run from. Juttu's folder is `juttu-messaging`, and its
sessions use the short name `juttu`:

- **`turva`, `turva-2`, `juttu`, `juttu-2`** - the Claude session for the
  main checkout and for each worktree.
- **`turva-tmux`, `turva-tmux-2`, `turva-2-tmux`, `juttu-tmux`** - the
  plain shells: the checkout, then `-tmux`, then a number for a second
  shell.

Quill Medical's `just cc` names its sessions `q1` to `q99`, where `q1` is
the main checkout, and Owl's session is `owl`. Their shells are
`quill-tmux` for the main checkout, `quill-6-tmux` for a worktree and
`owl-tmux` for Owl.

Arnie and Digest have one checkout each, so their sessions are `arnie` and
`digest`, and their shells `arnie-tmux` and `digest-tmux`. Each has its own
`scripts/<session>-session`, which starts its session at boot, so
`just cc` starts a missing session with it too. Digest's starter gives
the session `DIGEST_SESSION=true`, which its nightly runner needs, and
its Claude starts a fresh conversation rather than carrying on the last.

## The tmux server has a service of its own

Every session on the box lives in one tmux server. When `just cc` or
`just tw` is the first to ask for a session, `start-tmux.sh` starts that
server as its own systemd service, `tmux-server`. Otherwise the
server would belong to whichever service the terminal came from, and
stopping that service would close every session on the box. The boot
scripts in the other repositories do the same. `just -g sest` runs the
tests.

## Tab titles

`titles.conf`, beside this file, turns those names into terminal tab
titles. A Claude tab reads the project, the worktree number and the
conversation's topic: "Quill-6 Passport sign-off page", "Turva-2 Hazard
log", "Juttu-3 Inbox". The main checkout has no number, so it reads
"Quill", "Turva" or "Juttu". Owl's reads "Owl", Arnie's "Arnie" and
Digest's "Digest".

A shell reads the same label, then "Tmux", and its number when it is not
the checkout's first: "Quill-6 Tmux" for `just tw`, "Quill-6 Tmux-2" for
`just tw 2`, and "Turva Tmux" or "Owl Tmux-3" likewise. `just tw next`
goes to the first shell from 2 up that no terminal is showing, and starts
it when there is none. Any other session
shows its own name.

The topic is the `@topic` session option, which the tab-topic hook
(`claude/hooks/tab-topic.sh`) keeps. Until it is set, a Quill, Turva or
Juttu tab reads "---" in its place, such as "Quill-6 ---". Owl, Arnie and
Digest never get a topic from the hook, so Claude Code's own pane title
stands in for theirs.

`install.sh` loads the file with one line at the end of `~/.tmux.conf`,
so it wins over any older title rule above it:

```tmux
source-file ~/github/mark-house-style/scripts/tmux/titles.conf
```

A tmux server already running picks it up with
`tmux source-file ~/.tmux.conf`. The tests in `tests/titles.bats` run
the rule on a tmux server of their own.
