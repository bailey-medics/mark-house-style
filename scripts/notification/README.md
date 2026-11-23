# Finished-response notifications

When Claude Code finishes a response, or stops to ask something, these scripts show a banner saying which worktree it was, and speak the worktree's name. With several worktrees open at once, that tells you which one needs you. Clicking the banner brings that worktree's editor window to the front.

They are personal tooling, ported from Quill Medical, and do nothing until a Claude Code hook calls them.

## What each script does

- **`notification.sh`** - the hook. It works out the banner: the worktree as the title, and the first bullet of the reply's closing TL;DR as the text. On a Mac it shows the banner at once. On Linux it adds the banner to a queue file for a Mac to fetch.
- **`notification-summary.py`** - turns the reply into that one line of banner text.
- **`notification-queue.py`** - writes a banner to the queue on Linux, and on the Mac reads and checks each banner before showing it.
- **`notification-show.sh`** - shows one banner on a Mac, and speaks the worktree's name.
- **`notification-focus.sh`** - runs when a banner is clicked, and brings the right editor window forward.
- **`notification-listen.sh`** - runs on the Mac, fetching banners from the Linux box over SSH.
- **`notification-listen-install.sh`** - installs that listener on the Mac so it starts at login.

## Turning it on

Point the hooks in your own `.claude/settings.json` at `notification.sh`. That file is git-ignored, so this changes nothing for anybody else:

- **`Stop`** - `"$HOME/github/mark-house-style/scripts/notification/notification.sh"`
- **`Notification`, for `permission_prompt`** - the same, with `needs-input` after it.
- **`PreToolUse`, for `AskUserQuestion`** - the same, with `needs-input` after it.

## When Claude runs on a Linux box and you watch a Mac

The box has no screen, so it only adds each banner to `~/.local/state/quill-notify/banners.jsonl`. The Mac fetches them. **The box never connects to the Mac**, so a box that was taken over has no way onto the Mac, and the Mac treats each banner as text to show, never as a command to run.

On the Mac, once:

1. **Check that `ssh devbox` logs straight in**, with no password or question. Set `TURVA_NOTIFY_BOX` if the Mac knows the box by another name.
2. **Run `just -g notify-listen-install`.** It copies the listener into `~/Library/Application Support/turva-notify` and starts it at every login. Run it again after changing these scripts.

The queue is shared with Quill Medical on purpose, so one listener on the Mac shows both repositories' banners. If Quill Medical's listener is already installed, the install stops and says so, because two listeners would show every banner twice.

## When the Mac cannot reach the box by SSH

The listener needs `ssh devbox` to work, which on some networks it cannot,
such as hospital wifi that blocks Tailscale. VS Code can still reach the box
there, through a VS Code tunnel, so the banner relay brings the banners over
that connection instead.

- **`vscode-relay/`** - a small VS Code extension that runs on the Mac side
  of a window connected to the box. Every few seconds it reads the last lines
  of the queue through VS Code's own connection, and hands them to its own
  copy of `notification-queue.py` on the Mac, which checks them and shows
  each banner once. It shares the record of what was shown with whichever
  listener the Mac has, this repository's or Quill Medical's, so a banner
  never shows twice when both work. The box still never connects to the
  Mac.
- It only runs while a VS Code window on the Mac is connected to the box,
  with a folder on the box open. With several such windows, one relays.
- A click on a relayed banner finds the window titled `[Tunnel: <name>]`,
  or opens the folder over the tunnel.

On the Mac, run **`just -g notify-relay-install`** (`t nri`). It copies the
banner scripts the relay calls into `~/Library/Application Support/banner-relay`,
then builds the extension and installs it in VS Code, which must be 1.90 or
newer. Reload the windows connected to
the box to start it. Its settings, under "Banner relay" in VS Code, are
needed only when it cannot work out the box or the queue itself. Run its
tests with `just -g notify-relay-test` (`t nrt`).

## Settings

These are read from the environment, on the Mac unless it says otherwise:

- **`TURVA_NOTIFY_SPEAK=0`** - no speech.
- **`TURVA_NOTIFY_BANNER=0`** - no banner.
- **`TURVA_NOTIFY_CHIME=1`** - play a sound as well. Off by default.
- **`TURVA_NOTIFY_VOICE`** - another installed voice. The default is Karen.
- **`TURVA_NOTIFY_ACTIVATE=""`** - a click on the banner does nothing.
- **`TURVA_NOTIFY_BOX`** - the box's name, as `ssh` and VS Code know it. The default is `devbox`.
- **`TURVA_NOTIFY_QUEUE`** - a different queue file, on the box.
- **`TURVA_NOTIFY_DEBUG=1`** - on either machine, print the banner instead of showing it.

A click on the banner needs Accessibility permission for the notifier, under System Settings, Privacy and Security, Accessibility.

## Tests

`tests/notification.bats` covers both sides, with every Mac tool replaced by a stand-in, so it runs on Linux too. It needs [bats](https://github.com/bats-core/bats-core):

```bash
bats scripts/notification/tests
```

<!-- cspell:words devbox worktrees -->
