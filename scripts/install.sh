#!/usr/bin/env bash
# Links mark-house-style into the home folder, so Claude Code and just use it
# in every repository. Safe to run again: it only replaces links, never real
# files, and adds each setting once.
set -euo pipefail

house="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Link one path to a file or folder here, refusing to replace anything real.
link() {
    local target="$1" path="$2"

    mkdir -p "$(dirname "${path}")"

    if [ -e "${path}" ] && [ ! -L "${path}" ]; then
        echo "✗ ${path} is a real file or folder, not a link. Move it aside and run this again." >&2
        return 1
    fi

    ln -sfn "${target}" "${path}"
    echo "${path} -> ${target}"
}

# Claude Code reads these in every repository.
link "${house}/claude/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"
link "${house}/claude/rules" "${HOME}/.claude/rules"

# Skills one by one, so other folders in ~/.claude/skills are left alone.
for skill in "${house}"/claude/skills/*/; do
    name="$(basename "${skill}")"
    link "${house}/claude/skills/${name}" "${HOME}/.claude/skills/${name}"
done

# The global justfile, for `just -g`.
link "${house}/just/justfile" "${HOME}/.config/just/justfile"

# Pull the latest version at the start of every Claude session. A failed pull
# never stops the session.
python3 - "${HOME}/.claude/settings.json" "${house}" <<'PY'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
house = sys.argv[2]
command = f"git -C {house} pull --ff-only --quiet >/dev/null 2>&1 || true"

settings = json.loads(path.read_text()) if path.exists() else {}
groups = settings.setdefault("hooks", {}).setdefault("SessionStart", [])
present = any(h.get("command") == command for g in groups for h in g.get("hooks", []))

if not present:
    groups.append({"hooks": [{"type": "command", "command": command, "timeout": 15, "async": True}]})
    path.write_text(json.dumps(settings, indent=2) + "\n")
    print(f"{path}: added the pull at session start")
else:
    print(f"{path}: the pull at session start is already there")
PY

# CLAUDE.local.md holds per-repository personal lines, so git ignores it everywhere.
ignore="${XDG_CONFIG_HOME:-${HOME}/.config}/git/ignore"
mkdir -p "$(dirname "${ignore}")"
grep -qxF 'CLAUDE.local.md' "${ignore}" 2>/dev/null || { echo 'CLAUDE.local.md' >> "${ignore}"; echo "${ignore}: CLAUDE.local.md added"; }

# `t` runs the global recipes. `j` is left alone: it is plain `just`.
# `jg` was the earlier name, so it is taken out.
for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    [ -f "${rc}" ] || continue
    if grep -qxF "alias jg='just -g'" "${rc}"; then
        sed -i "\\|^alias jg='just -g'\$|d" "${rc}"
        echo "${rc}: alias jg removed"
    fi
    grep -qxF "alias t='just -g'" "${rc}" || { echo "alias t='just -g'" >> "${rc}"; echo "${rc}: alias t added"; }
done

echo "✓ Installed."
echo "  A shell reads its aliases only when it starts, so terminals and tmux"
echo "  shells already open will not know t. Open a new one, or run:"
echo "    source ~/.bashrc"
