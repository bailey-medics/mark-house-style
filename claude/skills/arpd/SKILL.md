---
name: arpd
description: Amend, rebase, push and describe the stacked branch checked out, then fix any red CI in the stack
argument-hint: "[repo] [ready]"
allowed-tools: Bash(readlink:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git fetch:*), Bash(git ls-files:*), Bash(git add:*), Bash(git switch:*), Bash(git -C *), Bash(just stu:*), Bash(just stack-update:*), Bash(just stack-log:*), Bash(just stack-log-long:*), Bash(just stack-files:*), Bash(just stack-rebase:*), Bash(just stack-submit:*), Bash(just stack-check), Bash(STACK_REPO=* just *), Bash(just -g stu:*), Bash(just -g stack-update:*), Bash(just -g stack-log:*), Bash(just -g stack-log-long:*), Bash(just -g stack-files:*), Bash(just -g stack-rebase:*), Bash(just -g stack-submit:*), Bash(gh stack view:*), Bash(gh stack rebase --continue:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr edit:*), Bash(gh pr ready:*), Bash(gh pr checks:*), Bash(gh run view:*), Bash(gh run rerun:*), Bash(just validate-teaching:*), Bash(./s/lint:*), Bash(./s/test:*), Bash(./s/frontend:*)
disallowed-tools: Bash(gh pr merge:*), Bash(gh stack merge:*), Bash(git rebase:*), Bash(git commit:*), Bash(git reset:*), Bash(git cherry-pick:*), Bash(git stash:*), Bash(git push:*), Bash(git branch -m:*), Bash(git branch -M:*), Bash(gh pr create:*), Bash(gh pr merge:*), Bash(gh stack unstack:*), mcp__github__merge_pull_request, mcp__github__enable_pr_auto_merge
disable-model-invocation: true
---

# Amend, rebase, push and describe the branch checked out

`/crpd`'s sibling. `/crpd` lands uncommitted work as a **new** branch with
its own pull request. This skill folds it into the branch **already checked
out**: it amends that branch's one commit, rebases every branch above it,
pushes the stack, and brings the branch's pull request description up to
date. Then it watches CI across the whole stack and fixes anything red,
because amending a lower branch can break the branches built on it.

**Read the shared rules first, in full.** They sit beside this skill, in
mark-house-style:

```bash
readlink -f ~/.claude/skills/arpd/../stack-landing.md
```

That prints the file's path; read it with the Read tool before anything
else. It holds what this skill shares with `/crpd`: what a run may do,
the Never list, other repositories, the stack checks, the tests, the
push, and how to write the pull request's title and body. This file says
only what is particular to amending. Where the two seem to disagree, this
file is the more specific, and wins.

## What this run may do

Running `/arpd` is the request to:

- **amend the branch checked out**, which this file calls the home
  branch, with the uncommitted work;
- **rebase the branches above it**, resolving conflicts as step 5 sets
  out;
- **push the stack** and **rewrite the home branch's description**;
- **fix red CI on any branch in the stack**, amending that branch, and
  noting the fix in its description.

Nothing else. "The authorisation ends with the run", in the shared rules,
holds in full: once the report is written, none of this is allowed again
until the user runs `/arpd` or `/crpd`, or asks in their own words.

**Never rename a branch.** Renaming a stacked branch on GitHub closes its
pull request and the ones above it. If the title no longer fits the branch
name, change the title only, and say so in the report.

## Arguments

Up to two space-separated arguments, both optional, in either order:

- A **repository** name, as "Target repository" in the shared rules sets
  out.
- **`ready`** - take the home branch's pull request out of draft once it
  is described. Omitted, its draft state is left exactly as it was.

So `/arpd`, `/arpd ready`, `/arpd <repo>` and `/arpd <repo> ready` are all
valid. `draft` is accepted and changes nothing, since a draft is left a
draft. Any other token is an error: stop and ask what was meant rather
than guessing.

This differs from `/crpd` on purpose. A new pull request is usually
finished when `/crpd` opens it. A pull request being amended has already
been put in one state or the other by a person, and an amend is no reason
to change their decision.

The arguments supplied to this command are: `$ARGUMENTS`

## Before anything

1. **Check the home branch is a stacked branch that has not merged.**

   ```bash
   just stack-log
   git branch --show-current
   ```

   Stop, and point to `/crpd`, when any of these is true:

   - **"No stack on this branch".** There is no stacked branch to amend.
     On `main`, or a branch level with `origin/main`, the work belongs on
     a new branch, which is `/crpd`'s job.
   - **The branch checked out has merged**, by the marks or by GitHub, as
     "Check the stack is safe to change" sets out. Amending it would
     rewrite work that is already on `main`. `/crpd` starts a new stack
     for it.

   Make the rest of the checks in "Check the stack is safe to change"
   too: the two ways a stack can look merged and not be, and a stack
   across worktrees. Each one stops this run the same way it stops
   `/crpd`.

2. **Write down where the run starts**: the home branch's name, and
   the state of CI on every open pull request in the stack, from
   `just stack-log-long` and `gh pr checks <number>` for each. Step 10
   uses it to tell a check the run broke from one already red.

## Steps

1. **Stop if there is nothing to commit.**

   ```bash
   git status --short
   ```

   A clean tree means there is nothing to fold in. Say so and stop. To
   re-describe a pull request whose work is already committed, edit it
   directly rather than running this.

2. **Read everything about to be folded in**: `git diff`, then every
   untracked file. Read it to describe it, never to decide whether it
   deserves committing. As for `/crpd`, running this skill is the
   decision that the work is ready, and it belongs on the home branch
   because it is here.

3. **Run the tests**, as "Run the tests" in the shared rules sets out, for
   what the home branch touches with this work folded in. A failure stops
   the run, before anything is amended.

4. **Amend the home branch.**

   ```bash
   just stu
   ```

   That stages everything, untracked files included, amends the branch's
   one commit with its message kept, then rebases every branch above it.

   **Reword the message only when it is no longer true.** If the work
   widens what the branch does, so the old subject now leaves something
   out, give the new one: `just stu "feat(frontend): …"`. Match the
   branch's own style and the "For the shared skills" section, as `/crpd`
   sets out for a new message.

   **When a pre-commit hook stops it**, nothing has been amended: the
   commit failed, and the work is still in the tree, staged. Fix the
   cause, then run `just stu` again. A hook that rewrote files, or a
   spelling word for the config, is mechanical: apply it and re-run.
   Anything that needs code written or changed, such as a type error or a
   lint finding, is a change nobody has reviewed: stop, show it, and wait.
   Never finish the job with `git commit --amend`.

5. **Resolve a rebase conflict when both sides plainly stand.** The
   amend rewrote the commit every branch above sits on, so a branch above
   that changed the same lines stops the rebase.

   - **Resolve it when each side's intent is plain and both can stand**:
     two branches adding different imports to one list, different entries
     to one table, or different tests to one file. Keep both, in the order
     the file already uses. Then `git add` the files and continue:

     ```bash
     gh stack rebase --continue
     ```

   - **Stop when the two sides change the same thing differently**, such
     as one logic block edited two ways. Choosing between them is a
     judgement about another unit, and a human's call. Report the branch
     and the files, and leave the rebase where it is.
   - **Then check the rebase finished**: `just stack-log` must show no
     branch needing a rebase, and `git branch --show-current` must be the
     home branch. If it is not, `git switch` back to it.

   Say in the report which conflicts were resolved, on which branches,
   and how.

6. **Push the whole stack**, as "Push the whole stack" in the shared
   rules sets out.

7. **Find the home branch's pull request, and read its own change**, as
   "Find the pull request and read its change" sets out. Read the patch
   of the whole unit as it now is, not only the part this run added.

8. **Bring the description up to date.** First read the live body:

   ```bash
   gh pr view <number> --json title,body -q .body
   ```

   "Check you are not overwriting a human", in the shared rules, decides
   whether it may be rewritten. Then write it as "Write the title and the
   body" sets out, with three differences:

   - **Describe the unit as it now is, not the story of its edits.** No
     "Updated:" line and no list of what this run added. A reviewer reads
     the description against today's diff. Keep what is still true, and
     rewrite what the amend made untrue: the opening, the triage block,
     and every section.
   - **Keep each screenshot that still shows the branch as it is**, with
     its uploaded link and its description line. Retake the ones the
     amend changed, take new ones for anything new a person would see,
     and take out the ones that no longer match. The screenshot rules in
     the shared file hold as they are.
   - **Keep the title** unless it no longer says what the branch does.
     Then change the title alone, never the branch name, and say so in the
     report.

   Post it in one edit, with an `--attach` for each new image.

9. **Take it out of draft only if `ready` was given**, and only if step 7
   found it a draft:

   ```bash
   gh pr ready <number>
   ```

   Without `ready`, leave the draft state exactly as it was.

10. **Watch CI across the stack, and fix anything red.**

    Wait for every check on every open pull request in the stack to
    finish, with a Monitor or a background loop rather than polling by
    hand, for example:

    ```bash
    for n in <each open pull request in the stack>; do
      gh pr checks "$n" --watch >/dev/null 2>&1
    done
    ```

    Then read each one with `gh pr checks <number>`. For every check that
    failed:

    - **A failure in GitHub's own tooling gets one re-run**, with
      `gh run rerun <run id> --failed`: an API or GraphQL error, a runner
      that died, a network fetch that timed out. Read the job's log with
      `gh run view <run id> --log-failed` to tell. If it fails again,
      treat it as real.
    - **A real failure is fixed on the branch it belongs to.** That is
      usually a branch above the home branch, which still uses something
      the amend changed or removed. Read the log, find the branch whose
      own change fails, `git switch` to it, fix the code, run the
      targeted tests for it, then `just stu` there. That amends its one
      commit and rebases the branches above it, with step 5's rules for
      any conflict.
    - **Fix the code, not the test.** Change a test only when the amend
      deliberately changed what is correct, so the test is out of date.
      Never weaken one to get green: no wider assertion, no deleted case,
      no new `skip` or `xfail`. If weakening is the only way, stop and
      report it.
    - **Two attempts at each failure, then stop and report it.** A third
      guess is less use than a person reading the log.
    - **Note each fix in that pull request's description**, under
      `## Decisions to check`, in one bullet: what failed, why, and what
      was changed. Name the home branch's pull request by its number, as
      the cause. "Check you are not overwriting a human" decides whether
      that body may be edited.

    **Fix a check that was already red before the run as well**, on the
    branch it belongs to, under the same rules. Say in the report which
    ones the run found red, from step 2 of "Before anything".

    When the fixes are made, `git switch` back to the home branch, run
    `just stack-submit` once, and wait for the checks again. Carry on
    until every check is green, or a failure has had its two attempts.

## Report

One short block:

- **The home branch and its place in the stack** (`just stack-log`), and
  whether its message was kept or reworded, giving the new one.
- **The pull request URL**, and under it the description's three triage
  lines: Size, Look hardest at, Check for me.
- **What the description update changed**, in a line: which sections
  moved, and which screenshots were kept, retaken, added or taken out.
- **Any rebase conflict resolved**, with its branch and files.
- **CI across the stack**, one line for each pull request: green, fixed
  (and what), re-run, or still red after two attempts. Mark the ones
  that were red before the run.
- **The draft state**, and whether `ready` changed it.
- **Any decision or risk written into a description**, repeated here in
  one line each.
- **Which tests were run, by name.** Never claim a suite that was not run.

Then read "Stopping" in the shared rules: it says when a run stops, and
that writing this report ends what the run authorised.
