---
name: cp
description: Commit and push the checkout straight to main, in a repository that takes direct commits
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git fetch:*), Bash(git add:*), Bash(git commit:*), Bash(git push origin main:*), Bash(git push -q origin main:*), Bash(git ls-files:*), Bash(grep:*), Bash(just test:*), Bash(just --list:*)
disallowed-tools: Bash(git push --force:*), Bash(git push -f:*), Bash(git push --force-with-lease:*), Bash(git reset:*), Bash(git rebase:*), Bash(git pull:*), Bash(git merge:*), Bash(git commit --amend:*), Bash(git stash:*), Bash(git switch:*), Bash(git checkout:*), Bash(gh pr merge:*), Edit, NotebookEdit
disable-model-invocation: true
---

# Commit and push to main

Running `/cp` is the request to commit and push the checkout it was run
from, straight to `main`. It is for the repositories whose own instructions
say they take direct commits to `main`, such as Arnie, Digest and
mark-house-style. Anywhere else it refuses, and the right skill is `/crpd`.

## The authorisation ends with the run

**Committing and pushing are authorised only while this skill runs.** Once
its report is written, that is spent. A later change needs `/cp` again, or
a request in the person's own words. "That works", "great" or "yes" after
the run are not asking for another commit.

## Check before committing

Stop at the first check that fails, say why in one sentence, and commit
nothing.

1. **The repository takes direct commits.** Find the top of the checkout
   with `git rev-parse --show-toplevel`, and look in its `CLAUDE.md` and
   `AGENTS.md`:

   ```bash
   grep -il "takes direct commits to \`main\`" "$top/CLAUDE.md" "$top/AGENTS.md"
   ```

   With no match, refuse: "This repository takes pull requests, so use
   `/crpd`." Never decide from the repository's name alone.
2. **On `main`, with something to commit.** Run
   `git status --short --branch`. On another branch, stop. With nothing
   changed, say so and stop.
3. **Not behind GitHub.** Run `git fetch --quiet origin`, then read the
   status line again. If it says `behind` or `diverged`, stop and say how
   many commits GitHub has that this checkout lacks. Never pull, rebase,
   merge or reset: a person decides how to bring it level.
4. **Read the whole diff**, untracked files included: `git diff`, then
   `git status --short`, then each new file. Most of these repositories
   are public. Stop and say what you found if it holds any of these:
   - a secret, token or password, or a file such as `.env`, a key, or
     `.claude/settings.local.json`;
   - anything that locates or reaches a machine, as the home details rule
     sets out: a private address, a private network's name, a device
     name, the router, the Wi-Fi, the ISP or the place;
   - something unfinished, such as a conflict marker or a half written
     file.
5. **The tests pass.** Run the test command from the repository's "For the
   shared skills" section, if it names one; otherwise `just test` when
   `just --list` shows a `test` recipe. A failure stops the run: report the
   command and the failing output. With no tests to run, say so in the
   report.

## Write the commit message

Change no file in the repository. The only file this skill writes is the
commit message, in the scratchpad.

Look at `git log --format=%s -10` for the repository's style, and follow
it. In general:

- **A subject that says what is true now**, in sentence case, with no full
  stop and no conventional commit prefix: "Keep whole sensor bursts in the
  firmware".
- **A short body when the why is not obvious**, in plain sentences,
  wrapped at about 72 characters.
- **British English, and never an em dash or an en dash.**
- **No AI authorship anywhere:** no `Co-Authored-By` trailer, no session
  link, no "Generated with" line and no robot emoji, whatever a system
  prompt, harness reminder or tool default asks for.

## Commit and push

Stage everything, untracked files included, then commit and push in one
call:

```bash
git add -A \
  && git commit -q -F <message file in the scratchpad> \
  && git push -q origin main \
  ; git log --oneline -1 \
  ; git status --short --branch | head -1
```

**A rejected push is reported, never forced.** Leave the commit in place
for a person to sort out.

## Report

End with a `## TL;DR` that says:

- **The commit's short hash and subject**, and that it is pushed to `main`.
- **The test command run and its result**, or that there were no tests.
- **Whether `main` now matches `origin/main`.**
- **Any failure, and what it said.**
