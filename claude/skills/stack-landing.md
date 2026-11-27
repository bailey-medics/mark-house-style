# Landing work on a stack: the shared rules

`/crpd` and `/arpd` both read this file before they do anything. `/crpd`
lands uncommitted work as a new stacked branch with its own pull request.
`/arpd` folds it into the branch already checked out. Everything they do
the same way is here, once, so the two cannot drift apart: the rules on
what a run may do, the stack checks, the tests, the push, and the pull
request description. Each skill's own file says only what differs.

Where this file says "the skill", it means whichever of the two is
running.

**Where a skill needs to know something about the repository**, such as
its test commands, read the repository's "For the shared skills" section,
in its `CLAUDE.md` or `AGENTS.md` or in a rule Claude Code has loaded. Where
the section says nothing on a point, do without it and say so in the
report.

**The stack recipes are `just stack-*`.** They come from Mark's
mark-house-style repository. In a repository whose justfile imports the
global one, run them as written; anywhere else, run them as
`just -g stack-*`.

## The authorisation ends with the run

**Everything this skill does - committing, amending, branching, rebasing,
pushing, opening a pull request - is authorised only while this skill is
running.** The moment its report is written, that authorisation is spent.

So after a run finishes:

- **Do not amend the branch** because the work changed. Not with
  `git commit --amend`, and not with `just stack-update` or `just stu`,
  which is the same act behind a recipe.
- **Do not push** the branch again. `just stack-submit` and `git push`
  are both out.
- **Do not open or update the pull request**, and do not change whether
  it is a draft.

The branch this skill made or amended is not an open workspace. A later
fix on it needs the user to run `/crpd` or `/arpd` again, or to ask for a
commit in their own words.

**Confirming that a change works is not asking for it to be landed.**
"That works", "great", "yes", "perfect" are verification. The right
response to them is to stop, leave the tree dirty, and say plainly what
is uncommitted. So is silence about git: a message that does not mention
committing is not asking for one.

**This is how the rule gets broken, every time.** The user runs
`/crpd` or `/arpd`, the branch lands, work continues, they confirm the
next fix - and amending "the branch we are already landing" feels like
tidying rather than a new commit. It is a new commit. In the session that
produced this section it happened five times in a row, each one reading
as housekeeping, and the user's correction was "stop doing commits and
pushes without crpd". The answer to it is `/arpd`, run by the user.

If the work genuinely needs to be in git to be testable, commit it, show
what was committed, and stop there. Never push on top of that.

## Never

These hold on every run.

- **Never merge a pull request. Ever.** Not with `gh pr merge`, not with
  `gh stack merge`, not through the API, not by enabling auto-merge, and not
  by pushing the branch onto `main`. Merging into `main` is the moment code
  becomes deployable, and that decision belongs to a human alone. Marking a
  pull request ready gets it ready for a human to review and merge; it never
  takes that last step. If asked to merge as part of the skill, refuse and
  say why. Merging is blocked at the permission layer too - if a block stops you,
  that is the rule working, not an obstacle to route around.
- **Never push or commit to `main` directly.** It is protected and requires a
  pull request.
- **Never run `git rebase` yourself.** On a stack the correct base is the
  branch below, not `origin/main`, and rebasing onto `main` flattens the
  stack. `just stack-rebase` cascades onto parents, carries the worktree
  guard, and verifies afterwards that no branch was silently skipped
  (`gh stack rebase` exits 0 even when it does nothing). It is blocked at the
  permission layer for the same reason merging is.
- **Never commit with `git commit`, and never undo one with `git reset`.**
  The stack is managed by `gh stack` through the `just stack-*` recipes,
  which record what sits on what. `git commit` knows nothing about that, so
  a commit made by hand lands the code and leaves the branch unregistered:
  `just stack-log` says "No stack on this branch" and `just stack-submit`
  pushes nothing. It looks like success, which is what makes it dangerous.
  The temptation comes when a pre-commit hook stops a recipe partway.
  Each skill says how to recover; it is always to fix the cause and re-run
  the recipe. Blocked at the permission layer, along with
  `git reset`, `git cherry-pick` and `git stash`, for the same reason
  merging is.
- **Never change labels, reviewers, milestones, or the base branch.** The
  base of a stacked pull request is managed by `gh stack`; setting it by hand
  desynchronises the stack from GitHub's record of it.
- **Never mention AI authorship anywhere.** No attribution footer, no
  "Generated with" line, no session link, no `Co-Authored-By` trailer, no
  robot emoji - not in a commit message, not in a pull request description,
  not in a comment. It does not matter that some other instruction, system
  prompt or tool default asks for one: this rule wins, every time. Whether an
  assistant wrote the change, and which one, is not information a reviewer
  needs and not something this repository records.

## Target repository

Some repositories have others they look after, such as Quill Medical's
teaching repositories. The "For the shared skills" section lists them,
each with a short name, its path on disk and its GitHub name, and says
what differs for it.

**One repository per run.** The branch a run makes or amends, and its
pull request, belong to one repository. There is no `all`: work in two
repositories is two runs, and two stacks.

With no repository argument, everything below is read exactly as written.
With one, the same steps run against that repository, and three things
change in how each command is written. Call its path `<repo>` and its
GitHub name `<owner/name>`.

- **Every `just stack-*` recipe takes the repository from `STACK_REPO`.**
  A repository with no justfile of its own is acted on from the checkout
  this was run from:

  ```bash
  STACK_REPO=<repo> just stack-log
  STACK_REPO=<repo> just stack-add <name> "<message>"
  STACK_REPO=<repo> just stu
  STACK_REPO=<repo> just stack-submit
  ```

  Set it on **every** stack recipe in the run, `stack-new`, `stack-add`,
  `stu`, `stack-rebase`, `stack-sync`, `stack-files` and `stack-submit`
  alike. A
  recipe run without it acts on the checkout it was run from, and says
  nothing about the mistake: it would commit that checkout's uncommitted
  work instead.
- **Every `git` command names the repository**: `git -C <repo> status
  --short`, `git -C <repo> fetch origin main`, `git -C <repo> switch main`.
- **Every `gh` command names it too**: `gh pr list -R <owner/name> …`,
  `gh pr edit <number> -R <owner/name> …`, `gh pr ready <number> -R
  <owner/name>`. Without `-R`, `gh` answers about the checkout it was run
  from. `gh stack view` has no `-R`; run it as
  `(cd <repo> && gh stack view --json)`.

What else differs, such as the tests, what the stack key names, or what
the description is written about, is in that repository's entry in the
section. Merging never becomes the skill's job, for any repository.

## Check the stack is safe to change

Both skills make these checks in their "Before anything" step, after
`just stack-log` has drawn the stack.

**A merged stack is easy to miss**, because `stack-log` still draws the
stack - every branch simply carries `merged`. Read the marks, not the
shape: work landed on a merged branch sits on history that is already in
`main`, and its pull request then carries the old stack's merge commits.

**The marks are only as fresh as the last sync, so ask GitHub too.**
`stack-log` reads the stack's local record, which learns of a merge
only when something syncs. A pull request merged on GitHub since then
still reads as open, in `stack-log` and in `stack-log-long` alike
(which says only "no pull request"). That is the usual state when
the skill is run: the human merged, came back, and carried on
working. So before trusting an unmarked branch, ask about the one
checked out:

```bash
gh pr list --head "$(git branch --show-current)" --state merged \
  --json number,title
```

- **Empty** - the branch has not merged. Carry on with whichever case
  `stack-log` showed.
- **A pull request comes back** - the branch checked out has merged,
  whatever the marks say. A stack merges from the bottom, so every
  branch beneath it has too and the stack is spent. Treat it as "every
  branch is merged". Each skill says what to do then.

`just stack-add` makes the same check and refuses to stack on a branch
whose pull request has merged. That refusal means this check was
skipped. Do what it says, never work round it.

**Two ways a stack can look merged and not be.** Both happened in
Quill Medical on 15 October 2026.

- **A pull request GitHub closed without merging.** When the branch
  beneath it is deleted after a merge into another branch, GitHub
  closes the pull request above rather than moving it to `main`. Its
  branch is intact: `just stack-sync`, then `just stack-submit` opens
  a fresh pull request for it. Never reopen or replace it by hand.
- **A pull request merged into the branch below rather than `main`.**
  Its work is not on `main`. Check the merge commit with
  `git merge-base --is-ancestor <commit> origin/main` before syncing;
  if it is not on `main`, stop and report it, because `stack-sync`
  would drop the branch as done and the work needs a pull request
  into `main` that only the human should open.

**Stop if the stack spans worktrees.** `just stack-log` names any branch
checked out elsewhere. A stack lives in one worktree; `gh stack rebase`
would skip those branches and still report success. Report it and stop
rather than working around it.

## Run the tests

**Run the targeted tests for what this branch touched**, with the
commands the "For the shared skills" section names, and nothing wider.
For another repository named in the arguments, run the tests its entry
names. CI runs the full suites on every push; a local full run
duplicates that, unless the repository's instructions say otherwise.

If a test fails, stop and report it. Fixing it is a code change nobody has
reviewed, and by this point the unit is being landed rather than built.

This is narrower than it sounds, and it does not contradict
`/f`, which says to fix a failing test. That is
the build phase, where fixing it is the work. This is the landing phase,
reached because a human ran the skill - so a test failing here means
the work was finished with a red test, which a human should see.

## Push the whole stack

**Push the whole stack and open or update its pull requests.**

```bash
just stack-submit
```

This rebases onto the latest trunk first, then pushes every branch and
creates or updates a draft pull request for each. New pull requests open
as drafts, which is what this repository's heavy CI tier and its four gate
checks require.

It pushes the whole stack, not just this branch - that is unavoidable,
because rebasing onto the latest trunk rewrites every branch in it.

**Run it whether or not a pull request in the stack is queued to
merge.** `gh stack submit` skips a queued branch itself: it neither
rebases nor pushes it, so it stays in the queue, and it reports so
("Skipping feature/… (PR #2001 queued)"). Everything above it is
rebased and pushed as usual.

This section used to say the opposite: with a queued pull request below,
push the new branch alone and open its pull request with
`gh pr create`. That was written on 4 October 2026, when
`stack-submit` would force-push a queued branch and drop it from the
queue. It no longer does, and a pull request made with `gh pr create`
is one GitHub's stack feature does not track: when the stack beneath
it merges, GitHub cannot move it to `main`, and closes it. That
closed #2014 on 15 October. So every pull request is made here, by
`stack-submit`, and never by hand.

## Find the pull request and read its change

**Find this branch's pull request.**

```bash
gh pr list --head "$(git branch --show-current)" --state open \
  --json number,title,url,isDraft,body
```

If there is none, stop and say so. If more than one comes back, stop and
ask which to update.

**Read this branch's own change, not the whole stack.**

```bash
just stack-files
```

That lists what each branch changes **against its own parent** - the unit
being reviewed. Do not use `git diff origin/main...HEAD`: on a stacked
branch that replays every unit below it, and describing all of them on one
pull request is exactly what stacking exists to avoid.

For the full patch of this branch's unit:

```bash
just stack-files p
```

Read the patch, not just the file list: the decisions and risks the
description asks for are visible only in the change itself.

## Check you are not overwriting a human

Replace the body without asking only when it is empty, is a placeholder
the repository's own automation wrote, such as Quill Medical's `auto-pr.yml`, carries only
gh-stack's `<sub>Stack created with…</sub>` footer, or carries the
`<!-- crp:pr-summary -->` marker meaning it was generated here before.
Anything else is someone's writing: show it, and ask before replacing it.

## Write the title and the body

**The title takes the stack key form** - `Passport: what this branch
does`, as "The stack key" in `/crpd` sets out: the stack's one word, a
colon, then the branch name's words read back as a sentence.

**The reader is the person who ran the overnight stack, reading the
next morning, probably on a phone, deciding in twenty seconds whether
to merge after a skim, read every line, or push back.** Every rule
below follows from that sentence, and where a rule and the sentence
disagree, the sentence wins.

The reader could work most of this out from the diff. The point is
that they should not have to. Summarising what the change does is the
job; *transcribing* it is not. A file list, a count of lines or tests,
or a walk through the diff in order costs the reader time and tells
them what the diff already shows.

**The body is an opening, a triage block, then three level-two
sections**, with a fourth, `## Screenshots`, when the unit changes what
a person sees, and a fifth, `## New Storybook components`, when it
adds one. This is Quill Medical's pull request #2263 written that
way:

```markdown
Changing your email address now needs confirming. Quill sends a link to
the new address and does nothing until it is clicked. It also tells the
old address that a change was asked for.

**Size:** large. 20 files, a migration, two new emails.
**Look hardest at:** where the change link is checked in `backend/app/security.py`.
**Check for me:** that signing somebody out after they confirm is acceptable.

## Decisions to check

- **The current password is optional for now.** You chose expand then
  contract before the run. Until then somebody with a stolen cookie but
  no password can start a change, but cannot finish it.
- **The confirm link reuses the `/verify-email` page instead of a new
  one.** A new page would have duplicated the token-in-URL handling. Its
  own signing salt means a verification link cannot be used as a change
  link.
- **A password change cancels a pending link.** The link carries
  `token_version`, which a password change bumps. So the account page
  saves the password first and the email second. My reading; the plan
  is silent.

## Risks

- **A mistyped new address keeps the old one.** No link arrives,
  nothing changes. That is the safe failure.
- **Confirming signs the person out.** They must sign in again.

## What has changed

- **`users.pending_email` holds the new address** until it is
  confirmed (migration `772b1a92d9dd`).
- **Two new emails**, `email_change_confirm` and `email_change_notice`,
  each with a Storybook render.
- **The account page asks for the current password** before an email
  change, and says to check the new inbox.

<!-- crp:pr-summary -->
```

A one-file wording change is the same shape, much shorter:

```markdown
The "Add a delegate by hand" guide now says a delegate can be found by
username as well as by email address.

**Size:** tiny. One guide file, wording only. Merge if it reads well.
**Look hardest at:** step 3 of `frontend/src/guides/content/add-a-delegate-by-hand.md`.
**Check for me:** nothing in particular.

## Risks

- None found. Only guide wording changes.

## What has changed

- **Step 3 names both ways to find somebody**, which is what the Add
  staff page's lookup accepts.

<!-- crp:pr-summary -->
```

### The opening

First in the body, so the reader learns what the change is before
being told how to review it.

- **Two or three short sentences: what is true now that was not true
  before.** In terms of what someone using the thing would see. Never
  a paraphrase of the title, and never a sentence that only parses if
  you already know the answer.
- **Name the screen, and explain the domain words.** "What someone
  would see" means a named page or route, not "a form" or "the table".
  A domain word the change turns on, such as a framework's "level" or
  "scope", gets its short explanation here, the first time it appears.
- **If you do link something - a plan, a document - use a full
  `https://github.com/…/blob/main/…` URL.** GitHub does not resolve a
  relative path in a pull request body.

### The triage block

Three lines, after the opening and before the first section, each a
bold label and one plain sentence. Saying what feedback the author
wants is the strongest single predictor of a pull request merging
(Pirouzkhah, Wurzel Gonçalves and Bacchelli, arXiv 2602.14611), and
these lines are where that is said.

- **`Size`** - `tiny`, `small`, `medium` or `large`, then what makes it
  so in a few words: the file count, a migration, a new email, a
  security boundary, clinical data. A migration, a security boundary or
  clinical data makes it `large` whatever the line count. A `tiny`
  change may add "Merge if it reads well."
- **`Look hardest at`** - one place, named well enough to open: a file
  path and a function or component, and what to look for there. It is
  where you are least sure, or where a mistake would hurt most. One
  place, not a list.
- **`Check for me`** - the one thing the reader must agree with before
  merging, written as a request. "Nothing in particular" is allowed for
  a `tiny` change. **It must make sense read on its own**: what
  happens, where in the code or on which page, and the alternative you
  did not choose, so the reader can say yes or pick the other one.

  > ✗ "that asking again at a higher level, after the old level
  > retired, counting as a progression is right."
  >
  > ✓ "When a level retires, a learner who asks for a sign-off at a
  > higher level counts as a progression (`SignOffKind` in
  > `schemas.py`). Is that right, or should it be a fresh request?"

There is no review-time line: the Size line carries what the reader
triages on.

### When this pull request must wait to merge

**Some units can only merge after something else has happened**: a
lower pull request has merged, its deploy to production has
finished, or Terraform has applied it. Build and land those units
anyway. The wait is written into the description, so it is the first
thing the reader meets, before the triage block:

```markdown
**Merge only after:**

1. Merge #2482.
2. Wait for its deploy to production to finish.
3. Run `just terraform-github`, and check it applied.
4. Then merge this.
```

- **A numbered list, in the order the human does it.** Each step is
  one action they can take or check, naming the pull request, the
  workflow or the recipe.
- **Say what goes wrong if the order is broken**, in one sentence
  under `## Risks`: which job fails, or which setting a backend cannot
  read.
- **Leave it out when there is no wait.** An ordinary stacked pull
  request that only needs the one below merged first says nothing
  here: merging from the bottom is how every stack lands.
- **Repeat the wait in the report**, so it is seen in the terminal as
  well as on GitHub.

### Sentences

Language models over-produce four things that make prose slow for a
person to read: inanimate subjects doing human verbs, dropped "that"
and "which", stacked nouns, and rare word pairings (Clark, Martin and
Mahowald, arXiv 2610.29162). All four come from reaching for the
shorter of two phrasings, so **never trade a plain sentence for a
shorter one**.

- **The subject is a person or a named thing in the code.** "Quill
  sends a link", "`decode_token` refuses the token", "the user clicks".
  Never an abstraction doing a human verb: not "the old address hears
  of it", "a second change stops an older link", "the page asks".
- **Keep the small words**: that, which, because, so, but, instead of.
  They show how one fact leads to the next. Cutting them saves two
  words and costs a re-read.
- **One fact a sentence, around fifteen words.** Two short sentences
  beat one with a comma in the middle.
- **Concrete before abstract.** "Somebody with a stolen cookie but no
  password", not "a session alone".
- **No stacked nouns.** "The seed the guide screenshots run against",
  not "the guide screenshot seed".
- **Spell out an abbreviation the first time**, unless it is an
  identifier the code uses. Mark is dyslexic.
- **No pointing at context the reader does not have.** "Fix 3a", "as
  asked", "as a human chose before the run" each point at something
  that was in the conversation and is not in the reader's head the next
  morning. Say the thing - "you chose this before the run", "the plan's
  Phase 3" - or leave it out.
- **No aphorisms.** A neat, balanced line states a conclusion whose
  premise the reader has not been given:

  > ✗ "Whose tree a place goes into is checked on the move, not only
  > on the create."
  >
  > ✓ "Moving an `org_unit` now checks its new parent is in the same
  > organisation. Creating one already did."

**There is no word count.** Length follows the change: a one-file
wording fix is a handful of lines, and a twenty-file security change is
as long as it needs to be. A little repetition is fine. A sentence that
only parses on the second read is not.

### Bullets: a bold lead, then the plain detail

**Every bullet opens with its claim in bold, five to eight words, then
one or two plain sentences giving the reason or the consequence.** The
reader skims the bold column and dips into the plain text only where
they want to, as they do with every `## TL;DR`.

- **The bold and the plain text never say the same thing.** A bold
  headline that the sentence then repeats is wasted, and so is a
  conclusion in bold with its premise left out.
- **One idea per bullet.** Two bullets on the same idea are one bullet;
  one bullet carrying two ideas is two.
- **No sentence that restates another**, however short it is.

### Names

**Use the vocabulary of the plan and of the code, not a private
synonym for it.** If the plan calls it an `org_unit`, write `org_unit`;
if the route is `/api/sites`, write `/api/sites`. A gentler word is
worse than jargon because it can be wrong: "place" for `org_unit` cost
a review, since the plan says the tree is governance, not geography.
Leave out the *incidental* - a local variable, a private helper - which
only the diff needs.

**Give every name three or four words saying what it is, the first
time it appears:** "`org_unit`, a node in the governance tree: a trust,
a hospital or a ward". Bare after that. **This covers domain words as
well as identifiers**: "a level, the grade a sign-off is given at" is
as much a name as `org_unit` is, and the reader needs it just as much.

**Never point at something with a bare noun phrase.** "The new list",
"the form", "the loader", "the routes", "the tables" ask the reader to
guess which thing is meant.

**Each kind of thing has one way to be named:**

- **A route**: its method and path,
  `POST /api/passport/{passport_id}/competencies/{competency_id}/requests`.
- **A page or form**: its on-screen title and URL, or its component
  name.
- **A table or column**: `passport_framework_level.retired_on`.
- **A function**: its name and file, `level_ref` in
  `backend/app/features/passport/definitions.py`.
- **A test**: its file and the test's name.
- **Another pull request**: its number, `#2365`. Never "the pull
  request below".
- **A migration**: its id and what it adds.
- **A count**: the things counted. Not "four nullable columns" but
  "`retired_on` and `retired_in_version`, on both tables".

> ✗ "The new list is added beside the old ones."
>
> ✓ "`place_ids` is added beside `organisation_ids` and `site_ids`."

> ✗ "So the `xfail` test from the pull request below stays."
>
> ✓ "So `test_asking_again_at_a_higher_level_after_the_old_one_went`,
> the `xfail` test from #2365, stays."

> ✗ "The routes refuse a retired level or scope."
>
> ✓ "`POST /api/passport/{passport_id}/competencies/{competency_id}/requests`
> refuses a retired level or scope."

This holds for the branch below too. A reader arrives at one pull
request in a stack, not at all of them in order.

**Before scoring, do a "which one?" pass.** Read each sentence as if
it were the only one on the screen. Wherever "the X", "it", "one" or
"a form" leaves you asking "which?" or "what is that?", put the name
in, in the form above. Check the name against the diff, not your
memory of it.

### Punctuation and spelling

**No em dashes.** Not in the opening, not in a bullet, not in a
heading. A comma, a colon, a full stop or a pair of brackets does the
same job. A sentence reaching for an em dash is usually one clause too
long, so the honest fix is to split it.

**British English throughout**, as the working instructions require: organisation,
behaviour, recognise, licence as the noun. Identifiers, route paths and
library names keep whatever spelling the code gives them.

### Writing for a dyslexic reader

The reader is dyslexic, and these are the British Dyslexia Association's
writing rules, from its style guide: "Use short, simple sentences in a
direct style. Give instructions clearly. Avoid long sentences of
explanation. Use active rather than passive voice. Avoid double
negatives. Be concise." The sentence rules above already carry the short
sentences, the bullets, the first-use explanation of a name and bold in
place of italics. These are the rest.

- **Active voice.** "Quill sends a link", never "a link is sent". The
  subject names who does the verb, so the sentence says who did it.
- **No double negatives.** Not "a job that is not excluded does not
  fail" but "every job the check covers passes". Security write-ups
  breed these, so look for them there.
- **Instructions a person must carry out go in a numbered list**, in
  the order they are done, separate from the explanation. The guide
  says to give instructions clearly and to avoid long sentences of
  explanation around them. Secrets to set before merging, a command to
  run afterwards, a setting to change by hand: each is a numbered step.
- **No italics, no underlining, no block capitals outside a code
  span.** The guide says underlining and italics "make the text appear
  to run together" and block capitals are "much harder to read". Bold
  is the only emphasis, and only for a word that must not be missed.
- **Every bullet ends with a full stop.** A text-to-speech reader
  pauses on punctuation and runs straight on without it.
- **No tables, and no text inside an image.** A text reader stumbles on
  a table and cannot hear an image. An embedded screenshot needs a
  short description on the line above it, saying what it shows.

### The sections

- **`## Decisions to check`** - the choices you made that a human might
  have made differently. A wrong one means the whole pull request needs
  a closer read, so it comes first. Each bullet takes one shape: what
  was chosen, what it was chosen instead of, and why. Then, where the
  choice is not certain, one of two fixed words, so they can be scanned
  for: `my reading` (the plan was silent and you picked a reading) or
  `a guess`. No word means you are sure. Do not hedge with "may",
  "should" or "I believe". A departure from the plan opens with
  "Departed from the plan:". Following the plan is not a decision. Omit
  the section when there genuinely were none. **Each bullet makes sense
  on its own**: it names the code or the page the choice lives in, so
  "the loader" is `_check_part_retirement` in
  `backend/app/cbac/competencies.py`. **A choice made in a `/g` run
  says so in plain words**: "You chose this when we ran the grill me
  skill." Never "in the plan's interview", which does not say which
  step was meant, and never "in the plan's grill me", which reads
  badly.

- **`## Risks`** - security, data leaks, patient safety, anything that
  could go wrong beyond the code being incorrect. **Always present**,
  even as "None found.", because an omitted section cannot be told
  apart from one nobody thought about. Say "none found", never "none":
  it is what you noticed, not a guarantee, and your judgement of risk
  is not well calibrated.

- **`## What has changed`** - what is different now, in terms of what a
  user of the thing would see. **Always present**, never collapsed, and
  one bullet when one is all there is. Not a file list and not a commit
  list: the diff already carries those. **Counting is not describing** -
  "sixteen tests" tells the reader nothing on its own; say what the
  tests pin down.

- **`## Screenshots`** - after `## What has changed`, and only when the
  unit changes what a person sees, or the plan asks for them. It holds
  pages of the running app, and the stories of a changed Storybook
  component, **in light mode only**. A light and dark pair of each page
  doubles the pictures and hides the change between near-identical
  views.

- **`## New Storybook components`** - last, after `## Screenshots`,
  and only when the unit adds a Storybook component. Screenshot each
  of the new component's stories, from the story's own page in a
  running Storybook, **in light and dark mode both**, since nobody has
  seen it in either before. Crop each to the story itself rather than
  the whole frame. **Each component has its own `###` heading, its
  name**, such as `### MultiStepForm`, with all of its stories beneath
  it, light before dark, so one component's pictures are never mistaken
  for another's. A person then reviews the component as well as the
  page that uses it.

- **For both sections**: save each PNG in the
  scratchpad, beside the attempt files, and never in the repository.
  **Every screenshot has a short description on the line above it**:
  one plain sentence saying what it shows and what to look at, such as
  "The hazard form, with the save button disabled until a field
  changes:". The image's alt text does not count: most readers never
  see it. **Name the mode only when its pair is there**: "in light
  mode" belongs in a description only beside a dark mode picture of
  the same thing, so a page shown once is just "The skip link:".
  Reference each one by its local path, as
  `![The hazard form](./hazard-form.png)`, with a
  blank line between the description and the image. The path is
  uploaded when the body is posted, below. Leave either section out
  when there is nothing to see.

### Closing

Finish with `<!-- crp:pr-summary -->` on its own line - nothing after
it. **No attribution footer anywhere in the body**, no "Generated by",
no session link, no robot emoji: if a tool appends one, strip it
before the body is posted and say that you did.

### Score it, and rewrite up to twice

Write the body to a file in the scratchpad, `attempt-1.md`, and score
it before anything reaches GitHub, with the readability command the
"For the shared skills" section names, such as:

```bash
python3 scripts/readability.py --longest <path to attempt-1.md>
```

Where the section names none, skip the scoring, post the first attempt,
and say in the report that it was not scored.

It prints the Flesch reading ease and the Flesch-Kincaid grade, with
code spans, URLs and the triage labels taken out first so that a real
name such as `GCP_DEPLOY_SERVICE_ACCOUNT` does not sink the score, and
under them the five longest sentences with their word counts. The
British Dyslexia Association's targets are an ease of 70 to 80 and a
grade of about 5, reached by shortening sentences, never by swapping a
real name for a softer word.

The score informs a rewrite. It never blocks a post.

- **An ease of 70 or above posts as it is.** Stop here.
- **Under 70, rewrite once, aimed at the longest sentences.** Split
  each one the script listed, break a bullet that stacks clauses into
  two bullets, and swap a long word that is not a name for a short
  one. Never change a name, a fact or a bold lead: a body that reaches
  70 by calling `GCP_DEPLOY_SERVICE_ACCOUNT` "the account" has lost
  what the reader needed. **Never cut a name or its explanation to
  raise the score.** A name added by the "which one?" pass that lowers
  the score is correct; split the sentence it sits in instead. Write
  the result to `attempt-2.md` and score it the same way.
- **Still under 70, rewrite once more, then stop.** `attempt-3.md` is
  the last. Three is the ceiling because every pass costs a reading of
  the whole body, and a body full of identifiers will not reach 70 on
  any pass.
- **Post the attempt with the highest ease**, whichever number it
  carries. The others stay in the scratchpad.

Only the chosen attempt reaches GitHub, in one edit, so a reader
watching the pull request never sees a draft replaced and gets one
notification rather than three:

```bash
gh pr edit <number> \
  --title "Passport: what this branch does" \
  --body-file <path to the chosen attempt>
```

`--body-file` rather than `--body`: the body holds backticks, quotes
and newlines, and passing it inline leaves them at the shell's mercy.

**With either screenshot section, add one `--attach` for each image
the body references**, in the same edit:

```bash
gh pr edit <number> \
  --title "Passport: what this branch does" \
  --body-file <path to the chosen attempt> \
  --attach <path to the first image> \
  --attach <path to the second image>
```

- **`--attach` uploads each image to GitHub's attachment storage**, as
  dragging it in on the website does, and swaps its local path in the
  body for the uploaded link. Nothing goes into a branch or into Git
  history. Paths in the body are read relative to the body file's
  folder, which is why the images sit beside the attempts.
- **Attach every image the body references.** A path with no matching
  `--attach` stays a local path, and shows as a broken image.
- **It needs `gh` 2.99.0 or newer and a person's token.** The Actions
  `GITHUB_TOKEN` and GitHub App tokens are refused. Never fall back to
  an orphan branch, a cookie tool or a browser: say in the report that
  the screenshots could not be posted, and why.
- **A partial failure still updates the body**, with the images that
  did upload, and exits non-zero. Say in the report which images
  failed.

Keep every attempt's ease, in order, for the report.

## Stopping

If a step fails mechanically - a test fails, a rebase conflicts, two pull
requests match the branch - stop and report it rather than working around
it, unless the skill's own file says how to deal with that failure.

**That is not licence to stop because the work itself gave you pause.**
The stopping conditions in both skills are all of the first kind: no
stack, a stack spanning worktrees, a failing test, an ambiguous pull
request. None of them is about what the work is, where it lives, or
whether it looks ready. Those are settled by the skill having been run.

**Writing the report ends the run, and ends what it authorised.** From
that point the branch is the user's, not yours: no further commit, no
amend, no push, no pull request edit, however small the change or however
clearly it belongs to the unit just landed. See "The authorisation ends
with the run" above.
