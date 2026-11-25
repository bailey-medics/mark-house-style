#!/usr/bin/env bats
# Tests for install.sh, which links mark-house-style into the home folder.
# HOME is the test's own folder, so nothing real is linked or edited.

bats_require_minimum_version 1.5.0

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../install.sh"
    export HOME="${BATS_TEST_TMPDIR}/home"
    unset XDG_CONFIG_HOME

    mkdir -p "${HOME}"
}

@test "the t and jg aliases are taken out, and the rest of the file kept" {
    cat >"${HOME}/.bashrc" <<'EOF'
export EDITOR=vim
alias t='just -g'
alias jg='just -g'
alias j='just'
EOF

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(cat "${HOME}/.bashrc")" = $'export EDITOR=vim\nalias j=\'just\'' ]
    [[ "$output" == *"alias t='just -g' removed"* ]]
    [[ "$output" == *"alias jg='just -g' removed"* ]]
}

@test "no alias is added to a shell file that has none" {
    printf 'export EDITOR=vim\n' >"${HOME}/.zshrc"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(cat "${HOME}/.zshrc")" = "export EDITOR=vim" ]
}

@test "a missing shell file is left missing" {
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ ! -e "${HOME}/.bashrc" ]
    [ ! -e "${HOME}/.zshrc" ]
}

@test "running it twice changes nothing more" {
    printf "alias t='just -g'\n" >"${HOME}/.bashrc"
    "$SCRIPT" >/dev/null

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ ! -s "${HOME}/.bashrc" ]
    [[ "$output" != *"removed"* ]]
}

@test "the global justfile is linked for just -g and for imports" {
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ -L "${HOME}/.config/just/justfile" ]
    [ "$(readlink "${HOME}/.config/just/justfile")" = "$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)/just/justfile" ]
}

@test "tmux loads the tab titles, once, after what is already there" {
    printf 'set -g mouse on\n' >"${HOME}/.tmux.conf"
    titles_line="source-file $(cd "${BATS_TEST_DIRNAME}/../.." && pwd)/scripts/tmux/titles.conf"

    run "$SCRIPT"
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(head -1 "${HOME}/.tmux.conf")" = "set -g mouse on" ]
    [ "$(tail -1 "${HOME}/.tmux.conf")" = "${titles_line}" ]
    [ "$(grep -cxF "${titles_line}" "${HOME}/.tmux.conf")" -eq 1 ]
}

@test "a missing tmux config is made with the tab titles in it" {
    run "$SCRIPT"

    [ "$status" -eq 0 ]
    grep -q "scripts/tmux/titles.conf" "${HOME}/.tmux.conf"
}

@test "a link left pointing at a skill that has gone is taken out" {
    house="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    mkdir -p "${HOME}/.claude/skills"
    ln -s "${house}/claude/skills/t-crpd" "${HOME}/.claude/skills/t-crpd"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ ! -L "${HOME}/.claude/skills/t-crpd" ]
    [ -L "${HOME}/.claude/skills/crpd" ]
    [[ "$output" == *"t-crpd: removed"* ]]
}

@test "a broken link to somewhere else is left alone" {
    mkdir -p "${HOME}/.claude/skills"
    ln -s "${BATS_TEST_TMPDIR}/nowhere" "${HOME}/.claude/skills/somebody-else"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ -L "${HOME}/.claude/skills/somebody-else" ]
}

@test "the cp skill is linked, can only be run by hand and never force-pushes" {
    house="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

    run "$SCRIPT"

    [ "$status" -eq 0 ]
    [ "$(readlink "${HOME}/.claude/skills/cp")" = "${house}/claude/skills/cp" ]
    grep -qx "disable-model-invocation: true" "${house}/claude/skills/cp/SKILL.md"
    grep -q "^disallowed-tools:.*Bash(git push --force:\*)" "${house}/claude/skills/cp/SKILL.md"
}
