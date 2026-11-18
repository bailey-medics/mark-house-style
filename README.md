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

It also adds a session-start hook that pulls this repository, ignores
`CLAUDE.local.md` everywhere, and adds the `jg` alias for `just -g`. It is
safe to run again.

## In a Turva checkout or worktree

```bash
jg turva-link
```

That copies the Turva rules in `projects/turva/rules/` into `.claude/rules`,
read-only, adds a session-start hook that refreshes the copies,
writes a git-ignored `CLAUDE.local.md` importing Turva's `AGENTS.md`, and
points the tab-topic and notification hooks at the scripts here.

## Layout

- **`claude/`** - what Claude Code reads in every repository.
- **`projects/`** - additions for one repository, such as `projects/turva/`.
- **`just/justfile`** - personal recipes; each runs in the repository it is
  called from.
- **`scripts/`** - the helper scripts the recipes and hooks call, with their
  tests.
- **`plans/`** - plans for this repository.

## Skills

Skills that came from Turva carry a `t-` prefix, such as `/t-crpd`, so none
shares a name with another repository's own skills.
