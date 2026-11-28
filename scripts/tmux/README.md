# tmux sessions, their config and their tab titles

Long jobs on the dev box run inside tmux, not in a VS Code terminal. A
VS Code terminal dies when its window disconnects; a tmux session keeps
running, and you attach to it again from wherever you are.

Two recipes take you into tmux for the checkout you are standing in:

- **`just cc`** - the Claude session. It starts the session when it is
  missing, starts Claude again when it has exited, and attaches or
  switches to it.
- **`just tw`** - a plain shell that runs nothing itself. `just tw 2`
  gives a second one, and `just tw next` the first that no terminal is
  showing.

## Session names

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

Arnie, Digest and Kaiku have one checkout each, so their sessions are
`arnie`, `digest` and `kaiku`, and their shells `arnie-tmux`, `digest-tmux`
and `kaiku-tmux`. Arnie and Digest each have their own
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
"Quill", "Turva" or "Juttu". Owl's reads "Owl", Arnie's "Arnie",
Digest's "Digest" and Kaiku's "Kaiku".

A shell reads the same label, then "Tmux", and its number when it is not
the checkout's first: "Quill-6 Tmux" for `just tw`, "Quill-6 Tmux-2" for
`just tw 2`, and "Turva Tmux" or "Owl Tmux-3" likewise. `just tw next`
goes to the first shell from 2 up that no terminal is showing, and starts
it when there is none. Any other session
shows its own name.

The topic is the `@topic` session option, which the tab-topic hook
(`claude/hooks/tab-topic.sh`) keeps. Until it is set, a Quill, Turva or
Juttu tab reads "---" in its place, such as "Quill-6 ---". Owl, Arnie,
Digest and Kaiku never get a topic from the hook, so Claude Code's own pane title
stands in for theirs.

`install.sh` loads the file with one line at the end of `~/.tmux.conf`,
so it wins over any older title rule above it:

```tmux
source-file ~/github/mark-house-style/scripts/tmux/titles.conf
```

A tmux server already running picks it up with
`tmux source-file ~/.tmux.conf`. The tests in `tests/titles.bats` run
the rule on a tmux server of their own.

## Tab titles that follow the conversation

Each project's Claude Code settings run the tab-topic hook,
`claude/hooks/tab-topic.sh`, after every message you send. It works only
in a Quill, Turva or Juttu Claude session, the ones `just cc` makes, and
in Owl's `owl` session. It does nothing anywhere else.

1. It sends the current title, your previous message and your newest
   one to a small Claude model, Haiku. The title already sums up what
   came before, and older messages would hold it back from noticing a
   new goal.
2. The model is asked: "If this conversation were starting now, would
   you name it differently?"
3. On the first message it names the conversation in three to six
   words.
4. After that, a next step towards the same goal keeps the name: a
   follow-up, a fix, docs, tests or a pull request for the same work.
   A new goal, one you would have started a fresh chat for, renames it.

**A one-message aside never renames the tab.** A new name is held back
until the next message agrees with it. A quick question about
something else, followed by a return to the work, leaves the title
alone.

**The title lives in tmux, not in Claude.** The hook stores it in the
session's `@topic` option, and `titles.conf` shows it. Starting Claude
again or running `/clear` clears it, and the next message names the
conversation afresh. Until then the tab reads "---" where the topic goes.

**What it costs.** One small model call per message, which takes about
two seconds. It runs in the background, so you never wait for it.
Your messages go to the same Claude service the session already uses.

To see or set the title by hand:

```bash
tmux show -t q3 -qv @topic
tmux set -t q3 @topic "My own title"
```

The hook may rename a title you set by hand when the conversation moves
on.

## The tmux config

tmux reads `~/.tmux.conf` when its server starts. It lives outside the
repository, so each developer keeps their own. This is the one the dev
box uses, if you want the same behaviour:

```tmux
set -g mouse on
set -g history-limit 50000

# No status line: the terminal tab already names the session
set -g status off

# Copy on mouse release, and keep the selection on screen. A click that
# moves a little reads as a drag of a character or two, and copying that
# would replace the clipboard: so a selection on one line of two
# characters or fewer is dropped, and copy mode left, instead of copied
bind -T copy-mode    MouseDragEnd1Pane if -F "#{||:#{!=:#{selection_start_y},#{selection_end_y}},#{||:#{e|>|:#{e|-|:#{selection_end_x},#{selection_start_x}},2},#{e|<|:#{e|-|:#{selection_end_x},#{selection_start_x}},-2}}}" { send -X copy-pipe-no-clear } { send -X cancel }
bind -T copy-mode-vi MouseDragEnd1Pane if -F "#{||:#{!=:#{selection_start_y},#{selection_end_y}},#{||:#{e|>|:#{e|-|:#{selection_end_x},#{selection_start_x}},2},#{e|<|:#{e|-|:#{selection_end_x},#{selection_start_x}},-2}}}" { send -X copy-pipe-no-clear } { send -X cancel }

# In copy mode, a key with no copy-mode job leaves copy mode and is typed
# at the prompt, so there is no need to press q first
bind -T copy-mode Any send -X cancel \; send-keys

# Free the plain keys copy mode claims, so they reach the prompt too
unbind -T copy-mode Space
unbind -T copy-mode ,
unbind -T copy-mode \;
unbind -T copy-mode F
unbind -T copy-mode N
unbind -T copy-mode P
unbind -T copy-mode R
unbind -T copy-mode T
unbind -T copy-mode X
unbind -T copy-mode f
unbind -T copy-mode g
unbind -T copy-mode n
unbind -T copy-mode q
unbind -T copy-mode r
unbind -T copy-mode t

# Name the terminal tab after the session. install.sh adds this line
source-file ~/github/mark-house-style/scripts/tmux/titles.conf
```

To load a change without restarting anything:

```bash
tmux source ~/.tmux.conf
```

Key bindings belong to the tmux server, not to a session, so one reload
reaches every session at once.

### What each part does

- **Mouse and history** - the mouse wheel scrolls back through output,
  and tmux keeps the last 50,000 lines of it.

- **No status line** - tmux's green bar along the bottom, reading
  something like `[q4] 0:bash*`, is switched off. It gave the session
  name, the window number and name, and a clock, and the terminal tab
  already says which session it is. tmux messages still show briefly at
  the bottom of the pane.

- **Copy on release** - dragging over text copies it when you let go of
  the mouse button, and the text stays highlighted. A click is not a
  copy: when the mouse moves slightly during a click, tmux reads it as a
  drag over a character or two, and without the size check that tiny
  selection replaced whatever was already on the clipboard. A selection
  of two characters or fewer, on one line, is dropped instead.

- **Type straight out of copy mode** - scrolling up or selecting text
  puts tmux into copy mode, where keys normally move around the history
  rather than reaching the prompt. With these lines, any ordinary key
  leaves copy mode and is typed at the prompt as well. The binding is on
  tmux's `Any` key, which fires for every key with no more specific
  binding in copy mode, and `send-keys` with no keys sends on the key
  that was pressed.

- **Tab titles** - the last line loads `titles.conf`, so the terminal
  tab says which session it is showing, as set out above.

### What typing out of copy mode costs

Copy mode's single-letter shortcuts are given up so that the letters
reach the prompt: `n` and `N` for the next and previous search match,
`f`, `F`, `t` and `T` for jumping to a character, `g` for going to a
line, `q` for quitting and Space for starting a keyboard selection.

What still works in copy mode:

- **Scrolling** - the mouse wheel, the arrow keys, Page Up, Page Down,
  Home and End.
- **Leaving without typing** - Escape.
- **The Ctrl and Alt shortcuts** - searching with Ctrl+r and Ctrl+s,
  for example, is unchanged.

The lines are written for the emacs-style copy-mode keys, which are
tmux's default. If your `mode-keys` is set to `vi`, the table is
`copy-mode-vi` and the keys it claims are different: run
`tmux list-keys -T copy-mode-vi` to see them.

### Selecting without tmux

Holding Shift while dragging hands the selection to the terminal itself,
and tmux never enters copy mode. It works with no config at all, but a
selection can then run across split panes.
