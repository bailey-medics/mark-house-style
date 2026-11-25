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

On the Mac, run **`just -g notify-relay-install`** (`just -g nri`). It copies the
banner scripts the relay calls into `~/Library/Application Support/banner-relay`,
then builds the extension and installs it in VS Code, which must be 1.90 or
newer. Reload the windows connected to
the box to start it. Its settings, under "Banner relay" in VS Code, are
needed only when it cannot work out the box or the queue itself. Run its
tests with `just -g notify-relay-test` (`just -g nrt`).

## Icons

A banner's icon comes from the app that posts it, so each icon is its own
copy of terminal-notifier. `build-notifier-app.sh <name>` makes
`~/Applications/<name>-notifier.app` from `icons/<name>.png`. A logo with a
solid background is used as the whole icon; one with a see-through
background is set on white, inset so the rounded corners do not clip it.

**After any banner change, run `just rfb` on the Mac**, in mark-house-style
or a repository that imports its recipes, or `just -g rfb` anywhere. It
pulls mark-house-style first, forward only, and stops without building if
the Mac's copy has changes or has gone a different way from GitHub. Then it
rebuilds every icon's app, copies the current banner scripts into the
relay's and the listener's installed folders, and restarts macOS's
notification services. `just -g nap <name>` rebuilds one app on its own.

- **Pillow is set up for you.** The builder needs it to prepare an icon.
  When the Mac's `python3` lacks it, the builder makes a private
  environment in `~/.venvs/notifier` once and uses that, since Homebrew's
  Python refuses `pip` installs. `TURVA_NOTIFY_VENV` puts it elsewhere.
- **A changed picture gets a new app identifier.** macOS keeps a
  notification app's icon under its identifier and keeps showing the old
  one even after a rebuild and a restart. So the identifier ends in a
  checksum of the picture: a new picture is a new app to macOS, which may
  ask once to allow it. The same picture keeps the same identifier.

The folder a banner came from picks its icon:

- **`quillmedical` and `quillmedical-<anything>`** - Quill.
- **`turva` and `turva-<anything>`** - Turva.
- **`juttu-messaging` and `juttu-messaging-<anything>`** - Juttu.
- **Any other folder with a picture in `icons/` named after it** - that
  picture, a worktree's number aside: `arnie` and `arnie-2` get Arnie's
  bulb, `digest` a bold D and `mark-house-style` a bold MHS.
- **Every other folder** - the general notifier, a bell, as is a project
  whose app has not been built yet.
- **Before any notifier is built** - the plain banner, macOS's own. It
  can't run anything when clicked, so a click only brings some application
  forward, such as Finder, rather than the folder's window. Run
  `just -g rfb` once to build the notifiers.

`arnie.png`, `digest.png`, `mark-house-style.png` and `general.png` are drawn
at 1024 by 1024, solid to the edges so they are used whole; Arnie's matches
its phone icon.

To give another project an icon, add `icons/<folder>.png`: its logo, or
bold white initials on a solid colour, 1024 by 1024 and solid to the edges.
Then run `just -g rfb` on the Mac. Only a project whose folders don't carry
its name, like Juttu's, needs a line in `notification-show.sh`.

`juttu.png` is rendered from `juttu.svg`, the original, at 1024 by 1024. The
builder reads PNG, so after changing the SVG, render it again, for example
with headless Chrome:
`google-chrome --headless=new --window-size=512,512 --force-device-scale-factor=2 --screenshot=juttu.png juttu.svg`.

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
- **`TURVA_NOTIFY_QUIET_HOURS=22-7`** - on the box, in a repository's hook command: from 22:00 until 07:00 the banner shows but nothing is spoken. Digest sets it for its nightly runs.

A click on the banner needs Accessibility permission for the notifier, under System Settings, Privacy and Security, Accessibility.

## Tests

`tests/notification.bats` covers both sides, with every Mac tool replaced by a stand-in, so it runs on Linux too. It needs [bats](https://github.com/bats-core/bats-core):

```bash
bats scripts/notification/tests
```

<!-- cspell:words devbox worktrees -->
