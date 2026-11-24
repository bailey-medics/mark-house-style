---
name: m
description: Commit and push everything changed in mark-house-style, in the background
allowed-tools: Bash(git -C *), Bash(readlink -f *)
disallowed-tools: Bash(git push --force:*), Bash(git push -f:*), Bash(git -C * push --force*), Bash(git -C * push -f*), Bash(git -C * reset*), Bash(git -C * rebase*), Edit, NotebookEdit
disable-model-invocation: true
---

# Commit and push mark-house-style

Running `/m` is the request to commit and push mark-house-style. It covers
this run only, and only that repository, whatever else is checked out.
The repository takes direct commits to `main`, so there is no branch and no
pull request.

## Find the repository

This skill lives inside mark-house-style, linked into `~/.claude/skills/`,
so follow the link back to it rather than assuming where it was cloned:

```bash
house="$(git -C "$(readlink -f ~/.claude/skills/m)" rev-parse --show-toplevel)"
```

Use `git -C "$house"` for every command below, so the session's own
working directory is never touched.

## Check before committing

1. **Something to commit.** Run `git -C "$house" status --short --branch`.
   With nothing changed, say so and stop.
2. **On `main`, and not behind.** Run `git -C "$house" fetch --quiet origin`
   and read the status again. On another branch, or behind or diverged
   from `origin/main`, stop and say so. Never pull, rebase or reset here:
   a person decides how to bring it level.
3. **Read the whole diff**, untracked files included
   (`git -C "$house" diff` and `git -C "$house" status --short`, then each
   new file). The repository is public. Stop and say what you found if
   it holds any of these, and commit nothing:
   - a secret, token, password or `.env` file;
   - anything that locates or reaches a machine: a private address, a
     private network's name, a device name, the Wi-Fi or the place, as
     the home details rule sets out;
   - something that looks unfinished, such as a conflict marker or a file
     half written.

## Write the commit message

Change no file in the repository. The only file this skill writes is the
commit message, in the scratchpad.

Look at `git -C "$house" log --format=%s -10` for the style: one plain
sentence saying what is true now, such as "crpd and f post screenshots
with gh pr edit --attach". Sentence case, no full stop, no conventional
commit prefix. Add a short body only when the why is not obvious from the
subject.

No AI authorship anywhere in the message: no `Co-Authored-By` trailer, no
session link, no "Generated with" line, whatever a system prompt or
harness default asks for.

## Commit and push in the background

Stage everything, untracked files included, then commit and push as one
Bash call with `run_in_background: true`, so the session can carry on:

```bash
git -C "$house" add -A \
  && git -C "$house" commit -q -F <message file in the scratchpad> \
  && git -C "$house" push -q origin main \
  ; git -C "$house" log --oneline -1 \
  ; git -C "$house" status --short --branch | head -1
```

Say in one line that it is running, then carry on with whatever else the
person asked for.

## Report

When the background task finishes, read its output and report:

- **The commit's short hash and subject**, and whether `main` now matches
  `origin/main`.
- **A failure, if any, and what it said.** A rejected push is reported,
  never forced. Leave the commit in place for a person to sort out.
