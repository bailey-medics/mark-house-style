# mark-house-style

Mark's own set-up for coding agents: working instructions, skills, rules,
hooks, just recipes and helper scripts. It is cloned once and linked into the
home folder, so it applies in every repository and every worktree, with no
copies to keep in step.

## Install

```bash
git clone https://github.com/bailey-medics/mark-house-style.git ~/github/mark-house-style
~/github/mark-house-style/scripts/install.sh
```

The install script links:

- **`~/.claude/CLAUDE.md`** to `claude/CLAUDE.md`, the general working
  instructions.
- **`~/.claude/rules`** to `claude/rules`, the path-scoped rules.
- **Each skill** into `~/.claude/skills/`, one by one.
- **`~/.config/just/justfile`** to `just/justfile`, the personal recipes.

It also adds a session-start hook that pulls this repository, and ignores
`CLAUDE.local.md` everywhere. It is safe to run again.

The personal recipes run as plain `just <recipe>` in any repository whose
justfile loads them with one line:

```just
import? '~/.config/just/justfile'
```

Elsewhere, run them with `just -g <recipe>`. The install script takes out
the old `t` and `jg` shell aliases for `just -g`; a shell already open
keeps knowing `t` until it starts again, or until `unalias t`.

## In a Turva checkout or worktree

```bash
just -g turva-link
```

That copies the Turva rules in `projects/turva/rules/` into `.claude/rules`,
read-only, adds a session-start hook that refreshes the copies,
writes a git-ignored `CLAUDE.local.md` importing Turva's `AGENTS.md`, and
points the tab-topic and notification hooks at the scripts here.

## Layout

- **`claude/`** - what Claude Code reads in every repository.
- **`projects/`** - additions for one repository, such as `projects/turva/`.
- **`just/justfile`** - personal recipes; each runs in the repository it is
  called from. Topics another repository may want, the banners and the
  remote desktop, the tmux sessions and stacked pull requests, are in files
  of their own: `just/banners.just`, `just/remote-desktop.just`,
  `just/session.just` and `just/stack.just`. The main justfile loads them.
  A repository usually loads the whole global justfile with one `import?`
  line; one whose own recipes clash, such as Quill Medical's, loads just
  the files it needs instead.
- **`scripts/`** - the helper scripts the recipes and hooks call, with their
  tests.
- **`vscode/`** - VS Code extensions of Mark's own. `vscode/checkout-name/`
  shows a short name for each checkout, such as `Quill-2`, in the title
  bar; `just -g checkout-name-install` installs it.
- **`plans/`** - plans for this repository.

## Remote desktop

A Linux dev box can show its desktop two ways, and `just -g rdp` switches between
them or turns both off. Only one runs at a time, because both start XFCE for
the same user. Nothing starts at boot, so after a restart both are off, and
whichever is on turns itself off after `AUTO_OFF_HOURS`, 12 unless the
settings file says otherwise. Switching on again restarts that clock.

- **`just -g rdp google`** - Chrome Remote Desktop. It works in a browser through
  most filters, but gives one window, so two screens means stretching it.
- **`just -g rdp windows`** - RDP through a Microsoft dev tunnel, with true full
  screen on each display in Windows App. On the Mac, run
  `~/bin/devtunnel connect <tunnel>` and leave it open, then connect Windows
  App to `localhost:3389`. The switch prints the command with the name filled
  in.
- **`just -g rdp off`** - stop both, so no remote desktop is reachable. The RDP
  desktop stays open on the box, and the automatic off does this. Use VS
  Code's tunnel or Tailscale to get back in and turn one on.
- **`just -g rdp kill`** - stop every remote desktop process, closing the RDP
  desktop and stopping the RDP server too, to free their memory. Anything
  unsaved in either desktop is lost. VS Code's tunnel, Tailscale and SSH are
  left running.
- **`just -g rdp status`** - which one is running.

Set it up once with `just -g rdi`, and again after the switch changes. It installs
the switch owned by root, lets your account run its five modes through sudo
with no password, and installs the tunnel host as a user service. The tunnel's name goes in
`~/.config/remote-desktop/config`, outside this repository; see
`scripts/remote-desktop/config.example`. `just -g rdtune 10000 30` sets RDP's video
cap per screen and frame rate, and `just -g rdt` runs the tests.

## Skills

The skills, such as `/crpd`, `/f`, `/g` and `/p`, serve every repository.
What is particular to one, such as its test commands or its plans folder,
comes from that repository's "For the shared skills" section, in its
`CLAUDE.md`, its `AGENTS.md`, or a rule here such as
`projects/turva/rules/turva.md`.

`/m` commits and pushes this repository to `main` in the background, from
any session, after reading the diff for secrets and home details.

`/cp` commits and pushes the checkout it is run from straight to `main`,
for the repositories that take direct commits, such as Arnie, Digest and
this one. It checks the repository's own `CLAUDE.md` or `AGENTS.md` says
so, that `main` is not behind GitHub, that the diff holds no secrets or
home details, and that the tests pass; anywhere else it points to `/crpd`.

A personal skill hides a repository's own skill of the same name, so a
repository keeps no copy of these. `install.sh` links each one into
`~/.claude/skills/`, and takes out any link left pointing at a skill that
has gone, such as the old `t-crpd`.
