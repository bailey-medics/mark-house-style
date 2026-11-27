---
name: crpd
description: Commit, rebase, push and describe one stacked branch
argument-hint: "[repo] [draft]"
allowed-tools: Bash(readlink:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git fetch:*), Bash(just stack-log:*), Bash(just stack-log-long:*), Bash(just stack-files:*), Bash(git switch:*), Bash(just stack-add:*), Bash(just stack-new:*), Bash(just stack-fresh:*), Bash(just stack-sync:*), Bash(just stack-rebase:*), Bash(just stack-submit:*), Bash(just stack-move:*), Bash(gh stack view:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr edit:*), Bash(gh pr ready:*), Bash(just stack-check), Bash(STACK_REPO=* just stack-*), Bash(git -C *), Bash(just validate-teaching:*), Bash(just -g stack-log:*), Bash(just -g stack-log-long:*), Bash(just -g stack-files:*), Bash(just -g stack-add:*), Bash(just -g stack-new:*), Bash(just -g stack-fresh:*), Bash(just -g stack-sync:*), Bash(just -g stack-rebase:*), Bash(just -g stack-submit:*), Bash(just -g stack-move:*), Bash(./s/lint:*), Bash(./s/test:*), Bash(./s/frontend:*)
disallowed-tools: Bash(gh pr merge:*), Bash(gh stack merge:*), Bash(git rebase:*), Bash(git commit:*), Bash(git reset:*), Bash(git cherry-pick:*), Bash(git stash:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh stack unstack:*), mcp__github__merge_pull_request, mcp__github__enable_pr_auto_merge
---

# Commit, rebase, push and describe one stacked branch

The single act that finishes one unit of work. The uncommitted work becomes
a new branch with a single commit, stacked on the branch checked out, or
starting a new stack from `main`, and that branch gets its own pull
request.

**Read the shared rules first, in full.** They sit beside this skill, in
mark-house-style:

```bash
readlink -f ~/.claude/skills/crpd/../stack-landing.md
```

That prints the file's path; read it with the Read tool before anything
else. It holds what this skill shares with `/arpd`: what a run may do,
the Never list, other repositories, the stack checks, the tests, the
push, and how to write the pull request's title and body. This file says
only what is particular to making a new branch. Where the two seem to
disagree, this file is the more specific, and wins.

**One call, one branch, one pull request.** The uncommitted work becomes a
new branch stacked on the current one, with a single commit, and that branch
gets its own pull request. Call it again after the next piece of work and it
stacks another on top. To fold work into the branch already checked out
instead, the skill is `/arpd`.

It is deliberately one act rather than four, because on a stack the four are
not separable: a stack is pushed as a whole, rebased onto the latest trunk
first, so a branch committed and pushed on its own leaves the rest of the
stack behind it.

`/f` calls this once per unit. It is also useful on
its own, to finish a stacked branch by hand.

## Arguments

Up to two space-separated arguments, both optional, in either order:

- A **repository** name, from the list of other repositories in the
  repository's "For the shared skills" section, by its full or short
  name. Omitted, the run acts on the checkout it was run from. See
  "Target repository" below.
- **`draft`** - leave the pull request a draft. Omitted, the pull request
  is taken out of draft once it is described. Neither merges anything.
- **`ready`** is accepted and changes nothing, since ready is the default.
  It is kept so that `/crpd ready`, typed from habit, still works.

So `/crpd`, `/crpd draft`, `/crpd <repo>` and `/crpd <repo> draft`
are all valid. `draft` and `ready` together are an error, and so is any
other token: stop and ask what was meant rather than guessing.

Default to marking it ready. Run by hand, `/crpd` usually finishes a
small change the human means to review and merge soon, and marking it
ready starts any CI that waits for a ready pull request while they read
it. `/f` passes `draft`: in a long unattended run the whole stack is
reviewed the next morning, and a draft is the correct state until a
human has read it.

The arguments supplied to this command are: `$ARGUMENTS`

## Before anything

1. **Find out whether there is a stack yet.**

   ```bash
   just stack-log
   ```

   - **In a stack with at least one unmerged branch** - the ordinary case.
     Step 2 uses `just stack-add`, which stacks the new branch on the one
     checked out.
   - **In a stack where every branch is merged** - the stack is spent, and
     the next unit belongs to a new one. See "Starting again after a stack
     has merged" below; the work is carried to `main` first, and step 2
     then uses `just stack-new`.
   - **"No stack on this branch", and on `main`** - this is the first unit.
     Step 2 uses `just stack-new` instead, which starts the stack. Everything
     else is the same.
   - **"No stack on this branch", on a branch level with `origin/main`** -
     also the first unit, and step 2 uses `just stack-new` just the same.
     `main` can be checked out in one worktree only, so the others park on
     a temporary branch at its tip. Check it rather than assume it:
     `git fetch origin main`, then `git rev-list --left-right --count
     HEAD...origin/main` must report `0 0`. The branch then holds nothing
     `main` does not, and `stack-new` cuts the new branch from it.
   - **"No stack on this branch", on any other branch** - stop and say so.
     Committing here would put the work on a branch that is not part of any
     stack, and landing that is not this command's job.

   Then make the checks in "Check the stack is safe to change", in the
   shared rules: whether GitHub says the branch has merged, the two ways
   a stack can look merged and not be, and a stack across worktrees.
   When the branch checked out has merged, the stack is spent: follow
   "Starting again after a stack has merged" below, and step 2 uses
   `just stack-new`.

## Starting again after a stack has merged

Only when step 1 found the stack spent: every branch marked `merged`, or
GitHub saying the branch checked out has merged. The checkout is then
behind `main` by at least the merge commits of the stack's own pull
requests, and the working tree holds the next unit.

```bash
just stack-fresh
```

It fetches, moves the checkout to the tip of `origin/main`, carries the
uncommitted work across, and tidies the spent stack's record. Then carry
on at step 1 of "Steps" and use `just stack-new`, exactly as for a first
unit.

**Do not use `just stack-sync` then `git switch main` here**, which is
what this section used to say. Neither survives the ordinary case:

- `stack-sync` will not rebase with uncommitted changes in the tree, and
  the tree is dirty by definition: that is the unit being landed.
- `main` is usually checked out in another worktree, so this one cannot
  switch to it. `stack-fresh` detaches at `origin/main` instead, which
  `stack-new` starts from just the same.
- A plain switch refuses whenever `main` has changed a file that is also
  changed locally, and it has if the unit carries on from what just
  merged. `stack-fresh` carries the work with a three-way merge.

**If `stack-fresh` reports files that overlap, stop and report them.**
The unit and something merged since have changed the same lines, git has
left both versions between conflict markers, and choosing between them
is a human's call. Nothing is lost.

`just stack-new` checks the same thing from the other side: it refuses
to start a stack anywhere but the tip of `origin/main`, and says to run
`just stack-fresh`. That refusal means this section was skipped.

## Steps

1. **Stop if there is nothing to commit.**

   ```bash
   git status --short
   ```

   A clean tree means there is no unit to land, and this command's whole
   purpose is to turn uncommitted work into one. Say so and stop. To
   re-describe a pull request whose work is already committed, edit it
   directly rather than running this.

2. **Put the work on its own new branch.**

   ```bash
   just stack-add <name> "<message>"
   ```

   …or, when step 1 said this is the first unit of a new stack - on `main`,
   or on `main` having just carried the work off a merged stack:

   ```bash
   just stack-new <name> "<message>"
   ```

   One call, one new branch, one commit, one pull request. That is the
   point: each unit of work gets a pull request of its own rather than
   accumulating commits on a branch someone has to disentangle later.

   Both stage everything and commit it. `stack-add` stacks the branch on
   top of the one currently checked out, so the new unit depends on the one
   below it exactly as the stack describes; `stack-new` starts a fresh
   stack from `main` instead. The name and message are chosen the same way
   either way.

   **Choose both the name and the message yourself**, from what actually
   changed - do not ask for them. This command is called unattended, and
   stopping to ask would defeat that.

   - **The name** describes the unit, not the session: `pr-description-join`,
     not `fixes` or `part-2`. Lower case, hyphenated, no `feature/` prefix -
     `stack-add` adds it. Keep it short enough to read in a stack diagram.
     Name it for what the change does, never for the files it touches - the
     pull request title is this same name read back as a sentence, so a
     name that describes the files produces a title that says nothing.
   - **The name opens with the stack key**, so every branch in the stack
     sorts and reads together: `passport-record-and-review`,
     `passport-sign-off-page`. See "The stack key" below. On a stack that
     already has branches, take the key from them rather than choosing
     again.
   - **The message** is conventional-commit style, matching the branch's own
     history: `fix(tooling): stack-log-long could not read pull requests`.
     Describe what the change does, not what you did. Where the "For the
     shared skills" section asks for more, such as a body saying whether a
     particular file needed changing, add it.
   - **Read the diff before naming either.** `git diff --stat` and the diff
     itself; the name and message should come from the code, not from what
     the conversation was about.

   ### The stack key

   Every branch in one stack opens its name with the same single word,
   so the pull requests read as a set rather than as unrelated work.
   `passport-record-and-review` and `passport-sign-off-page` sit
   together in a list; `make-the-passport-usable` and
   `stop-a-hook-failure` do not, even when they are the same stack.

   **One word, naming the area the stack is about**: `Passport`,
   `Teaching`, `Billing`. Not the change - the area. The rest of the name
   says what this unit does.

   **Capitalised in a title, lower case in a branch name.**
   `Passport: record and review` is what a reader sees;
   `passport-record-and-review` is what git holds, because branch names
   here are lower case throughout. Same word, written the way each
   place writes words.

   **Choose it once, when the stack is started** - the `stack-new` run,
   or the first `stack-add` onto a bare branch. Every later branch takes
   the key from the branches already in the stack, read from
   `just stack-log`. It does not change while the stack lives, even as
   the work drifts: a stack whose PRs share a word and then stop sharing
   it is worse than one that never had a key.

   **Check the key is free before adopting it.** Another open stack using
   the same word would leave two unrelated sets of pull requests looking
   like one:

   ```bash
   gh pr list --state open --json number,title,headRefName \
     --limit 100
   ```

   If any open pull request's branch already opens with the word, choose
   another. Prefer a narrower one - `passport-evidence` over `passport` -
   rather than a vaguer one. Closed and merged pull requests do not
   count: a key is reusable once its stack is finished.

   **The title reads `Passport: what this branch does`** - the key, a
   colon, then a plain description of the unit. The colon is what makes
   the key scannable: `Passport: record and review` reads as a set,
   `Passport record and review` reads as a sentence that happens to
   start with a word.

   **The title and the branch name say the same thing.** Not only the
   key - the words after it too. `passport-record-and-review` becomes
   `Passport: record and review`: hyphens to spaces, nothing added and
   nothing dropped. Write the branch name first, then read it back as a
   title; if that does not produce a title worth reading, the branch
   name was the problem and it is still cheap to change.

   The two are read side by side all the time - in `just stack-log`
   against the pull request list, in a notification naming a branch, in
   a review that mentions one and links the other. A reader should not
   have to work out that they are the same unit. When they drift, it is
   usually because the branch was named from the files touched and the
   title from what the change does: `stack-tidier-sync-and-help` beside
   `Stack: prune on sync, and line up the short names` shares a key and
   nothing else, and the branch name is the weaker half.

   **Set the title, because nothing else will get it right.**
   A repository's own automation may build a title, such as Quill
   Medical's `auto-pr.yml` making `Feature: <the branch words>`, and
   `gh stack submit` falls back to the commit subject, so whichever
   opens the pull request produces something close but not this. Set it
   alongside the description in step 8:

   ```bash
   gh pr edit <number> --title "Passport: what this branch does"
   ```

   Leave every other field alone - labels, reviewers, milestones and
   the base branch are still not this command's to change, and the base
   in particular belongs to `gh stack`.

   ### When `stack-add` fails on a hook

   A pre-commit hook will sooner or later stop the commit - a spelling
   word it does not know, a formatter that rewrote a file, a linter with
   a finding. The recipe then exits non-zero **having already created
   and checked out the branch**, because making the branch comes before
   committing onto it. The stack has no record of that branch: writing
   it into the stack is the last thing the recipe does, and it never got
   there.

   **Fix the cause, then run the recipe again. How depends on which.**

   - **`just stack-new` is safe to re-run as it is.** The branch already
     exists and is checked out, so the same command, with the same name
     and message, commits onto it and finishes. Do not switch branches
     first.
   - **`just stack-add` is not.** Its guard runs first, finds the
     half-made branch in no stack, and refuses with "No stack on this
     branch". Go back to the branch below, delete the empty one, and run
     it again:

     ```bash
     git switch <the branch below>
     git branch -d feature/<name>
     just stack-add <name> "<message>"
     ```

     The work is in the working tree throughout, staged, and travels
     with the switch. `-d`, never `-D`: the branch holds no commit of its
     own, so git deletes it without being forced, and if it will not, it
     is not empty and something else is wrong.
   - **Fix the cause.** A hook that rewrote
     files, or a spelling fix, is mechanical: apply it and re-run
     without pausing. A formatter that rewrote a file has already fixed
     it, so the re-run is the whole fix. Anything needing you to write or
     change code - mypy, a lint finding a formatter would not fix, bandit -
     is a change nobody has reviewed: stop, show the diff and the
     reason, and wait.

   **Never finish the job with `git commit`.** This is the failure this
   section exists for, and it looks exactly like success: the code is
   committed, the tree is clean, and the branch carries the right
   commit. What is missing is invisible - `git commit` knows nothing
   about stacks, so the branch is never registered, `just stack-log`
   reports "No stack on this branch", and `just stack-submit` pushes
   nothing and opens no pull request. The work looks landed and is not.

   `git commit`, `git rebase`, `git cherry-pick` and `git reset` are all
   outside this command for the same reason: the stack is managed by
   `gh stack` through the `just stack-*` recipes, and any git command
   that writes history behind its back leaves the two disagreeing. If a
   recipe cannot be made to work, stop and report it - that is a
   mechanical failure of the first kind, and repairing a stack by hand
   is not this command's job.

   **Check the registration, not just the commit.** After `stack-add` or
   `stack-new` returns, `just stack-log` must draw the new branch in the
   stack. A clean tree and a good commit prove only that git is happy.

   **Do not judge the work. Commit it.** Whatever is uncommitted becomes
   one branch and one pull request. Running this command *is* the decision
   that the work is ready, and it has already been taken by the person who
   ran it. Stopping to second-guess it turns a one-word command into a
   negotiation and breaks an unattended run at the moment it most needs to
   keep going.

   This covers every kind of second-guessing, not only whether the work is
   one unit:

   - **What the work is.** A plan document, a scratch file, notes, a
     half-built feature - all of it is the unit. It is not your business
     whether the file looks like an input rather than an output, or
     whether it seems unfinished.
   - **Where it lives.** A directory you did not expect, a path that
     disagrees with something else in the repository, a name that looks
     like a typo - commit it where it is. The person who put it there
     chose that.
   - **Whether it belongs on this stack.** It does, because it is here.
   - **Whether it is ready.** It is, because the command was run.

   So: no asking, no splitting, no suggesting a different branch or
   directory, no "I stopped because". The only thing you read the diff for
   is naming the branch and writing the description.

   **Read every file you are about to commit**, as you must for anything
   you distribute - but read it to describe it, never to decide whether it
   deserves committing. Noticing something odd is fine; say it in the
   report, after the work is landed, not instead of landing it.

3. **Do not rebase here.** The new branch is always the top of the
   stack: a stack is one line, and `stack-add` puts the new branch on its
   end. Nothing sits above it, so nothing has been left on an older
   parent. The only rebase a run needs is the one onto the latest trunk,
   and `stack-submit` does that itself in step 5.

   If `just stack-log` ever warns that a branch needs rebasing, that is
   the trunk having moved, and step 5 deals with it.

4. **Run the tests**, as "Run the tests" in the shared rules sets out.

5. **Push the whole stack**, as "Push the whole stack" sets out.

6. **Find this branch's pull request, and read its own change**, as
   "Find the pull request and read its change" sets out.

7. **Check you are not overwriting a human**, as the shared rules set
   out.

8. **Write the title and the body, and post them**, as "Write the title
   and the body" sets out, with the title in the form "The stack key"
   above gives.

9. **Mark it ready unless `draft` was given**, and only if step 6 reported
   `isDraft: true`:

   ```bash
   gh pr ready <number>
   ```

   Marking ready starts the heavy CI tier - say so when reporting. If it is
   already out of draft, leave it and say so. With `draft`, leave it a draft,
   and never put back into draft a pull request that is already out of it.
   This is the last step; do not merge it.

## Report

One short block:

- The branch created, and its position in the stack (`just stack-log`).
- The pull request URL, and under it the description's three triage
  lines: Size, Look hardest at, Check for me.
- Every attempt's ease, in order, and which attempt was posted: "Scores
  58, 66, 72. Attempt 3 posted."
- Whether it was left a draft or marked ready.
- The commit message and the title used, since the name, the message and
  the title were all chosen for you.
- **Any decision or risk written into the description**, repeated here in
  one line each. After an unattended run the terminal is read before the
  pull requests are, and a decision nobody sees is a decision nobody
  checked.
- Which tests were run, by name. Never claim a suite that was not run.

Then read "Stopping" in the shared rules: it says when a run stops, and
that writing this report ends what the run authorised.
