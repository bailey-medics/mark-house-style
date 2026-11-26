---
name: r
description: Review the branch the worktree is on for the edge-case bugs a diff review misses - read each touched file whole, attack it with a fixed list, and fix the class, not the instance
argument-hint: "[fix]"
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git show:*), Bash(git ls-files:*), Bash(git grep:*), Bash(just stack-check), Bash(just stack-files:*), Bash(just -g stack-check), Bash(just -g stack-files:*)
disallowed-tools: Bash(git commit:*), Bash(git push:*), Bash(git rebase:*), Bash(git reset:*), Bash(git stash:*), Bash(git switch:*), Bash(git checkout:*), Bash(git merge:*), Bash(git cherry-pick:*), Bash(just stack-update:*), Bash(just stu:*), Bash(just stack-submit:*), Bash(just -g stack-update:*), Bash(just -g stu:*), Bash(just -g stack-submit:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(gh pr ready:*), Bash(gh pr comment:*), Bash(gh pr review:*), Bash(gh pr merge:*), Bash(gh stack merge:*)
disable-model-invocation: true
---

# Review the branch for edge cases

A diff review reads the lines that changed. The bugs this skill hunts sit
in the lines that did not: a guard missing from a component, a value
nobody tried, a state nobody rendered. So it reads each file the branch
touches in full, attacks it with a fixed list, and checks every sibling
for the same fault.

It runs on the branch the worktree is on.

- **`/r` reports, and changes nothing.**
- **`/r fix` also fixes what it confirms**, failing test first, and leaves
  the fixes uncommitted.

The argument was: `$ARGUMENTS`

**Where this skill needs to know something about the repository**, such
as its test commands, how it renders a component in a browser, or how it
tiers a review, read the repository's "For the shared skills" section, in
its `CLAUDE.md` or `AGENTS.md` or in a rule Claude Code has loaded. Where
the section says nothing on a point, do without it and say so in the
report.

**The stack recipes are `just stack-*`.** In a repository whose justfile
imports the global one, run them as written; anywhere else, run them as
`just -g stack-*`.

## Nothing lands from here

- **Never commit, amend, push, rebase, switch branch or touch a pull
  request.** Landing a fix is a separate act: `/crpd`, or `just stu` on a
  stacked branch, when the person asks.
- **`/r` alone edits no file.** Only `/r fix` edits, and only to fix a
  finding and test it.
- **A finding that needs a person's decision is never fixed here.** That
  covers behaviour somebody chose on purpose, new interface, a new
  dependency, and a changed rule. It goes in the report as a question.

## 1. Find what the branch changes

Say in one line which branch is reviewed, against what, and how many
files.

- **In a stack** (`just stack-check` exits 0): `just stack-files p` prints
  each branch's patch against its own parent. Read only the part for the
  branch checked out. Never diff a stacked branch against `main`: that
  replays every unit below it.
- **Not in a stack**: compare with where the branch left `main`, using
  `git diff --merge-base origin/main --stat`, then the same without
  `--stat` for the patch.
- **Add uncommitted work.** `git status --short` lists it, and a new file
  that is not yet tracked counts as changed.
- **On `main` with nothing uncommitted, or with nothing changed**, say
  there is nothing to review and stop.

## 2. Decide how hard to look

Sort the touched files by how much harm a bug in each could do. Use the
repository's own tiers where its section names them. Otherwise:

- **Every line**: access control and sign-in, data models and
  migrations, anything that writes clinical or audit records, checks and
  gates (continuous integration, test helpers, accessibility checks), and
  infrastructure. **Shared components count here too**: anything in a
  shared components folder, or used by more than one page. Every page
  inherits a shared component's bug, so it is never "only interface".
- **Read closely, and attack the risky parts**: routes, hooks, pages and
  scripts.
- **Glance**: stories, docs, styles that only restyle, and dependency
  bumps.

Say which tier each file sits in.

## 3. Read each touched file whole

For every file in the top two tiers:

- **Read the whole file**, not only the changed lines. A guard missing
  three functions away is still in this file.
- **Read its tests and its stories**, and note what each test actually
  proves.
- **Find its callers** with `git grep`, so you know what real code sends
  it. A component fed only text by its tests may be fed a 0 by a page.
- **Find its siblings**: the other files in the same folder, and other
  code doing the same job elsewhere, such as two dialogs, three button
  pairs or two date displays. Step 5 needs them.

## 4. Attack it with the list

Walk every heading that applies to the file, and skip the rest. Do not
list the skipped headings in the report.

### Doing it twice, and late

- **Two clicks, two Enters, or a submit from code before the page
  re-renders.** A `disabled` or loading prop is not a guard. A ref set
  before the first `await` is.
- **While an action is pending**, are accept, Cancel, Escape, the overlay
  and the close button all handled the same way?
- **Closed and reopened while pending**: can the first opening's result
  close, fill or put an error into the second? Count openings.
- **A timeout in the interface does not stop the request.** Is the
  request aborted, by a signal handed to the call? Is the button held
  until the request settles? Is a late success kept from navigating or
  resetting the form?
- **A retry after a timeout**: can it write twice?

### State that outlives a step

- **A callback that throws**: is a flag set before the call left stuck?
  Set it once the call returns.
- **Edits made during a save**: does success reset the form over them?
- **After a save**: is the unsaved-changes warning back on? Does leaving
  mid-save warn? Does a change of query string count as leaving? Does
  closing the tab warn?
- **Controlled and uncontrolled props**: given `onChange` and no `value`,
  does typing still work? Are `defaultValue` and `defaultChecked`
  honoured?
- **An effect that reads a state its dependency list leaves out**, such
  as loading.
- **Changing one part of the address or the history state**: are the
  `#fragment` and the rest kept?

### Values nobody tried

- **0, an empty string, an empty list, null, undefined and NaN.**
  `{count && ...}` puts a 0 on the screen; compare against null instead.
- **One item, exactly one page, and one more than a page.**
- **The longest plausible label, and one long word with no spaces.**
- **An odd prop**: a page size of 0 or 2.5, a negative number, or a style
  given as a list or a function where the code expects an object.
- **An identifier built into an address or a path**: empty, `..`, a
  slash, a percent sign.

### Dates and numbers

- **Typed dates read day, month, year.** 03/04 is 3 April. A date that
  does not exist, such as 31/02, is refused, not rolled into March. A
  two-digit year is refused, not guessed.
- **A plain date such as `2026-05-06` read with `new Date` is midnight
  UTC**, so it shows the day before anywhere west of UTC. Run the date
  tests under `America/Los_Angeles` and `Pacific/Kiritimati`.
- **Plain dates and timestamps sent to the same display**: does it handle
  both?

### Text parsers

- **A hand-written parser** for Markdown, CSV, a template or a query: try
  nesting, code that contains the syntax, a link with brackets or spaces,
  a numbered list that does not start at 1, and a line that carries on a
  list item. A maintained library is usually the fix; ask before adding
  one.

### Keyboard and screen readers

- **Everything clickable is reached by Tab and works with Enter or
  Space**: rows, cards and icons too. A click handler on a table row is
  mouse-only.
- **A click on a control inside a row does not also open the row.** Watch
  for clicks that bubble out of menus and popovers drawn elsewhere in the
  page.
- **Focus moves into a menu or dialog when it opens**, onto a real item,
  and back to the control that opened it when it closes.
- **A tooltip opens on keyboard focus**, not only on hover.
- **Every dialog has an accessible name**, even with no visible title.
- **Every input is linked to its label, its description and its error.**
- **Changes are announced**: `aria-sort` on sort headers, `aria-busy`
  while busy, and a live region that reads out the error, not a stale
  result count.
- **A control marked `aria-disabled`** still matches a `:not(:disabled)`
  hover style.
- **Valid HTML**: no `<div>` or `<p>` inside a `<p>`.

### Layout

- **320 pixels wide, and 200% zoom**: nothing overflows sideways. Look
  for `min-width`, `max-content`, `nowrap` and fixed widths.
- **Long labels wrap or shorten** as the design intends.
- **Both colour schemes.** Faded, hover, disabled and weekend colours keep
  enough contrast.
- **Reduced motion**: scrolling and animation respect it.
- **Touch targets at least 44 by 44 pixels** on a phone.

### Checks that fail open

- **A gate, guard or check where a crash, a missing result or an empty
  list becomes a pass**: `?? []`, a `catch` that returns true, an
  optional chain that falls back to success, or a skipped test that
  reports green.
- **Every check has a canary**: a test with a known bad input that proves
  the check fails.

### Tests that prove less than they say

- **Would the test pass with the fix taken out?** If you cannot tell, it
  proves nothing.
- **Does a mock replace the very thing under test?**
- **Does it check how the code works**, rather than what a person sees?
- **Is the hard case tested at all**: the double click, the time zone,
  the 0?

### Away from the screen

- **Two requests at once**: is the second refused, or does it overwrite
  the first? Is the version a write was based on checked?
- **A call to another service that times out, half fails or is
  retried**: can it write twice, or leave half a record?
- **A permission check that cannot decide** denies.
- **Input at the edge of the system** is checked before any work runs.

## 5. Fix the class, not the instance

For every finding:

- **Name the rule it breaks**, in one line: "a busy flag is set before
  the await", not "line 74".
- **Look for the same mechanism** in the siblings from step 3, in the
  other callers, and in other code doing the same job. Follow the
  mechanism, not the file name.
- **List every instance found**, in this branch or outside it.
- **Keep differences that are on purpose.** If a sibling differs by
  design, leave it and say why.

## 6. Render it

Where the branch changes anything a person sees:

- **Render each changed component's stories, or the changed pages, in a
  real browser.** Use the repository's own command, or a browser tool
  the session has.
- **Look at 320, 390, 768 and 1440 pixels wide**, in both colour schemes,
  at 200% zoom and with reduced motion. Make one pass with the keyboard
  only.
- **Show the states a story hides**: an open menu or tooltip, pending,
  error, empty and a very long label.
- **If nothing can render it, say so plainly** under "Not checked", with
  the reason. Never write that something looked right when it was not
  seen.

## 7. Prove each finding

Give each finding a status:

- **Confirmed**: a test fails, a command shows it, or it was seen in the
  browser.
- **Likely**: read from the code, and not reproduced. Say what would show
  it.
- **Question**: it needs a person to decide.

Under `/r`, prove things only with what already exists: tests, stories
and commands. Edit nothing to prove a point.

Under `/r fix`, take each Confirmed or Likely finding that needs no
decision, one at a time:

1. **Write a test that fails because of the bug**, run it, and see it
   fail. A test you have not seen fail proves nothing.
2. **Fix it at the narrowest shared place**: one shared helper when the
   instances share one, otherwise each instance. An instance in a file
   the branch does not touch is fixed too when the fix is the same and
   small. Anything bigger is reported as a follow-up.
3. **Run the test and see it pass**, then the other tests of each file
   you changed, with the repository's targeted test commands. Do not run
   a full suite unless the repository's section says to.
4. **Add a story** for any state a person needs to see: pending, open,
   error or a long label.

A Likely finding whose test passes before any fix was not a bug. Drop it,
and say so.

## 8. Report

Open with one line: the branch, what it was compared against, how many
files were read whole, and their tiers.

Then `## Findings`, most serious first: wrong data saved or shown, then
actions run twice or lost, then people shut out by keyboard or screen
reader, then layout. For each:

- **`path:line`, and what goes wrong**, as one concrete case: "click
  Delete twice quickly and `onAccept` runs twice".
- **The rule it breaks**, and every other place with the same fault.
- **Its status**: Confirmed, Likely or Question. Under `/r fix`, also
  whether it was fixed, and the test that proves it.

Then `## Not checked`: what could not run, such as the browser, a time
zone or a service, and which files were only glanced at. Leave it out
only when everything was checked.

Under `/r fix`, say the fixes are uncommitted, list the files changed,
and say that landing them is a separate act.

End with the `## TL;DR` the working instructions ask for.
