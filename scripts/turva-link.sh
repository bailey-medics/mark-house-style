#!/usr/bin/env bash
# Points one Turva checkout or worktree at mark-house-style: the Turva-only
# instructions through CLAUDE.local.md, the Turva-only rules in .claude/rules,
# and the hooks at the scripts here. Replaces the old links into
# .claude-personal/mark/. Safe to run again.
set -euo pipefail

house="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
top="$(git rev-parse --show-toplevel)"

# --quiet, for the session-start hook, says nothing unless something fails.
quiet=""
[ "${1:-}" = "--quiet" ] && quiet=1
say() { [ -n "${quiet}" ] || echo "$@"; }
folder="$(basename "${top}")"

case "${folder}" in
    turva | turva-[2-9] | turva-[1-9][0-9]) ;;
    *) echo "✗ This folder is ${folder}, not a Turva checkout (turva or turva-<number>)." >&2; exit 1 ;;
esac

cd "${top}"
mkdir -p .claude

# The old links into .claude-personal/mark/ would load everything twice.
for item in CLAUDE.md skills rules; do
    path=".claude/${item}"
    if [ -L "${path}" ]; then
        case "$(readlink "${path}")" in
            *.claude-personal/*) rm "${path}"; say "removed ${path} (pointed into .claude-personal)" ;;
        esac
    fi
done

# The Turva rules: turva.md has no paths, so it always loads, and the others
# are path-scoped. Claude Code will not load a project rule that is a link to
# a file outside the project, so these are copies, made read-only so a change
# is made here instead. The session-start hook below refreshes them.
[ -L .claude/rules ] && rm .claude/rules
mkdir -p .claude/rules
for rule in "${house}"/projects/turva/rules/*.md; do
    copy=".claude/rules/$(basename "${rule}")"
    if [ -L "${copy}" ] || ! cmp -s "${rule}" "${copy}"; then
        rm -f "${copy}"
        install -m 444 "${rule}" "${copy}"
        say "${copy} copied from ${rule}"
    fi
done

# Turva's own CLAUDE.md only links to AGENTS.md, so import it.
if [ "$(cat CLAUDE.local.md 2>/dev/null)" != "@AGENTS.md" ]; then
    printf '%s\n' '@AGENTS.md' > CLAUDE.local.md
    say "CLAUDE.local.md written"
fi

# The hooks now run the copies here, so they work on any branch.
if [ -f .claude/settings.json ]; then
    python3 - .claude/settings.json "${house}" "${quiet}" <<'PY'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
house, quiet = sys.argv[2], sys.argv[3]
text = path.read_text()
text = (text
    .replace("$CLAUDE_PROJECT_DIR/s/notification/notification.sh", f"{house}/scripts/notification/notification.sh")
    .replace("$CLAUDE_PROJECT_DIR/.claude/hooks/tab-topic.sh", f"{house}/claude/hooks/tab-topic.sh"))

# Refresh the rule copies at the start of every session.
settings = json.loads(text)
refresh = f"{house}/scripts/turva-link.sh --quiet"
groups = settings.setdefault("hooks", {}).setdefault("SessionStart", [])
if not any(h.get("command") == refresh for g in groups for h in g.get("hooks", [])):
    groups.insert(0, {"hooks": [{"type": "command", "command": refresh, "timeout": 15}]})
new = json.dumps(settings, indent=2) + "\n"

if new != path.read_text():
    path.write_text(new)
    if not quiet:
        print(f"{path}: hooks now run from {house}")
PY
fi

say "✓ ${folder} now uses mark-house-style."
