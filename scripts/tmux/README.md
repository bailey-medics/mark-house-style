# Terminal tab titles from tmux

`just -g cc` and `just -g tw` name their tmux sessions after the Turva or Juttu
folder they are run from. Juttu's folder is `juttu-messaging`, and its
sessions use the short name `juttu`:

- **`turva`, `turva-2`, `juttu`, `juttu-2`** - the Claude session for the
  main checkout and for each worktree.
- **`tmux-turva-1`, `tmux-turva-1-2`, `tmux-turva-2`, `tmux-juttu-1`** - the
  plain shells, numbered by worktree and then by shell.

These lines in `~/.tmux.conf` turn those names into terminal tab titles:
"Claude" and the conversation's topic for a Turva session, "Juttu" and the
topic for a Juttu session, and "Tmux turva-1-2" or "Tmux juttu-1" for a
shell. The topic is the `@topic` session option, which the tab-topic hook
(`claude/hooks/tab-topic.sh`) keeps. Until it is set, Claude Code's own
pane title stands in.

```tmux
set -g set-titles on
set -g set-titles-string "#{?#{m/r:^turva(-[0-9]+)?$,#{session_name}},Claude#{?#{@topic}, #{@topic},#{?#{m:*Claude Code,#{pane_title}},, #{s/^[^ ]* //:pane_title}}},#{?#{m/r:^juttu(-[0-9]+)?$,#{session_name}},Juttu#{?#{@topic}, #{@topic},#{?#{m:*Claude Code,#{pane_title}},, #{s/^[^ ]* //:pane_title}}},#{?#{m:tmux-*,#{session_name}},Tmux #{s/^tmux-//:session_name},#{session_name}}}}"
```

The final `#{session_name}` is the fallback for every other session. On a
machine with other rules, put the three conditions in front of them
instead, before any rule matching `t*`, since that would also catch
`turva` and every `tmux-` shell.
