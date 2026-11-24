# Terminal tab titles from tmux

`just -g cc` and `just -g tw` name their tmux sessions after the Turva or Juttu
folder they are run from. Juttu's folder is `juttu-messaging`, and its
sessions use the short name `juttu`:

- **`turva`, `turva-2`, `juttu`, `juttu-2`** - the Claude session for the
  main checkout and for each worktree.
- **`tmux-turva-1`, `tmux-turva-1-2`, `tmux-turva-2`, `tmux-juttu-1`** - the
  plain shells, numbered by worktree and then by shell.

Quill Medical's `just cc` names its sessions `q1` to `q99`, where `q1` is
the main checkout, and Owl's session is `owl`.

`titles.conf`, beside this file, turns those names into terminal tab
titles. A Claude tab reads the project, the worktree number and the
conversation's topic: "Quill-6 Passport sign-off page", "Turva-2 Hazard
log", "Juttu-3 Inbox". The main checkout has no number, so it reads
"Quill", "Turva" or "Juttu". Owl's reads "Owl". A shell reads "Tmux
turva-1-2", "Tmux juttu-1" or "Tmux T3".

The topic is the `@topic` session option, which the tab-topic hook
(`claude/hooks/tab-topic.sh`) keeps. Until it is set, Claude Code's own
pane title stands in.

`install.sh` loads the file with one line at the end of `~/.tmux.conf`,
so it wins over any older title rule above it:

```tmux
source-file ~/github/mark-house-style/scripts/tmux/titles.conf
```

A tmux server already running picks it up with
`tmux source-file ~/.tmux.conf`. The tests in `tests/titles.bats` run
the rule on a tmux server of their own.
