# Terminal tab titles from tmux

`t c` and `t tw` name their tmux sessions after the Turva
folder they are run from:

- **`turva`, `turva-2`** - the Claude session for the main
  checkout and for each worktree.
- **`tmux-turva-1`, `tmux-turva-1-2`, `tmux-turva-2`** - the plain shells,
  numbered by worktree and then by shell.

These lines in `~/.tmux.conf` turn those names into terminal tab titles:
"Claude" and the conversation's topic for a Claude session, and "Tmux
turva-1-2" for a shell. The topic is the `@topic` session option, which the
tab-topic hook (`claude/hooks/tab-topic.sh`) keeps. Until it is set, Claude
Code's own pane title stands in.

```tmux
set -g set-titles on
set -g set-titles-string "#{?#{m/r:^turva(-[0-9]+)?$,#{session_name}},Claude#{?#{@topic}, #{@topic},#{?#{m:*Claude Code,#{pane_title}},, #{s/^[^ ]* //:pane_title}}},#{?#{m:tmux-turva*,#{session_name}},Tmux #{s/^tmux-//:session_name},#{session_name}}}"
```

The final `#{session_name}` is the fallback for every other session. On a
machine with other rules, put the two Turva conditions in front of them
instead, before any rule matching `t*`, since that would also catch
`turva` and `tmux-turva`.
