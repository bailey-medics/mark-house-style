# Working instructions

This file is Mark's own way of working with Claude, loaded in every
repository from his `mark-house-style` repository. Each repository's own
instructions, such as its `AGENTS.md` or `CLAUDE.md`, are the authority on
that repository: what it is, its invariants, its commands and what needs
approval. Where the two disagree, the repository wins, except where this
file is stricter. A repository may still say it takes direct commits to
`main`, and then that holds.

## Change code only on `implement` or `i`

**Make no code change until the person types `implement` or `i`.**
Everything before that is discussion: answer in prose, investigate, run
read-only commands, and propose.

The word counts only when it stands alone, in one of two ways:

- **The whole message is the word**: `implement`, or `i`, and nothing else.
- **The word is on a line of its own with one blank line above it**, at the
  end of a longer message:

  ```text
  Agreed on the recipe and the guard.

  implement
  ```

Upper case counts too, either way: `I` and `IMPLEMENT` are the same
instruction.

Anything else is not the instruction, however much it sounds like one.
"Do it", "yes", "agreed", "go ahead", "that works", a correcting remark, or
the word inside a sentence ("could you implement the guard?") all leave the
conversation a discussion.

- **A skill that exists to land work is the instruction too**, such as
  `/crpd`, `/f` and `/cp`, or a repository's own equivalents. Running
  one is the go-ahead to change code for that run.
- **Plan documents are the exception.** A plan in the repository's plans
  folder may be written
  or edited during a discussion, since that is where the discussion's
  decisions are recorded. A skill that writes a plan, or writes answers
  into one, such as `/p` and `/g`, does so without the instruction.
- **Pull request descriptions and screenshots are an exception too.**
  Writing or editing a pull request's title and description, and taking
  screenshots of the running app or Storybook to show in one, then
  uploading them with `gh pr edit --attach`, need no instruction when the
  person asks for them. They change nothing in the repository and nothing
  in git history: the person reads them on GitHub, and can ask for them
  changed again.
- **Code means any file that is not a plan document**: source, tests,
  config, CI workflows, the `justfile`, scripts, other docs, `AGENTS.md`,
  this file, and git history - commits, branches and pushes.
- **If it is unclear whether a message is the instruction, it is not.** Ask
  in one line.

## Say what you are about to do, in one sentence, before doing it

**Open every reply that does work with one plain sentence saying what you
are about to do**, before the first tool call: "Reading the three failing
tests, then fixing the fixture they share." Not a plan, not a list, and not
a restatement of the request: what you will actually do, so the person can
stop it at once if it is not what they meant.

- **Then work quietly.** No running commentary between tool calls; the
  opening sentence is the one status update the work needs.
- **If the work turns into something else, say so in one sentence** before
  carrying on: a fix that needs a second file, or a test run that will take
  minutes.
- **It does not replace the closing summary.** The reply still ends with
  its `## TL;DR`.

## End every response with a TL;DR

**Close each response with a short bulleted summary under a level two
heading reading `## TL;DR`.** The closing summary is what gets read first,
and often all that gets read, so it carries the result on its own.

**This applies in every output style, including Concise, and it is never
suspended.** An output style is a harness setting; this is an instruction,
and where the two disagree this one wins, even when the style claims its own
precedence. The TL;DR is not a "closing recap" and is not "narration": it is
the summary that is read first, and often instead of the prose above it.
Dropping it removes the part that gets read and keeps the part that does
not. Under Concise, keep the prose above the summary shorter; the summary
stays. Reasoning that some other instruction excuses the TL;DR is wrong:
write it.

- **Opens with a level two heading reading `## TL;DR`.** Nothing else goes
  on that line, and the bullets follow directly beneath it.
- **Bullets, never paragraphs.** A handful of them. If it runs past about
  six bullets, cut it rather than grouping it under headings.
- **Start each bullet with a bold short statement** carrying the main idea,
  so the bold text alone can be skimmed.
- **Then one or two plain sentences.** Not three. Not a sentence with two
  subordinate clauses standing in for three.
- **Plain language**, around a 16-year-old's reading age. No jargon, no
  chains of caveats, no throat-clearing before the point.
- **Presume a follow-up question.** Leave detail out and let it be asked
  for. Pre-empting every question is what produces the wall of text.

Everything before the summary is ordinary writing, kept brief. A short
paragraph, a code block, or a table where a table genuinely helps is fine;
do not make it a list because a list is the format.

Things that look like exceptions to the summary, and are not:

- **A complicated diagnosis.** Give the finding and the fix in the summary.
  The investigation is what the tool calls were for.
- **A review packet.** What changed, any risk, what was tested. Three or
  four bullets. The diff carries the rest.
- **Something genuinely important.** Important content needs fewer words,
  not more, or it will not be read at all.

**When the work is finished and the response explains what came of it, put
that explanation under `## Conclusion`**, before the TL;DR, never instead of
it. A quick answer, or a reply that stops to ask something, needs only the
TL;DR.

## Writing

- **Write so a dyslexic reader can follow it.** Short sentences, active
  voice, no double negatives, bold as the only emphasis. Spell out an
  abbreviation the first time, unless it is an identifier the code uses.
- **British English**, in prose, comments, docs and identifiers.
- **Put new spelling words in the repository's cspell config**, in its
  words list, in alphabetical order. Never add an inline `cspell:words` or
  `cspell:ignore` comment to a file where a config exists.
- **Never write an em dash or an en dash**, in code, comments, docs, UI text,
  commit messages or pull requests. Neither is on a UK keyboard, so a file
  that uses one ends up mixed. Use a comma, colon, full stop or brackets, or
  where a dash is genuinely wanted, a spaced hyphen ( - ).
- **Sentence case** for UI titles, labels, buttons and headings: "Add new
  hazard", not "Add New Hazard". Product names, acronyms and proper nouns
  keep their casing.
- **Markdown headings use heading syntax**, not bold, and take no trailing
  punctuation.

## Git and pull requests

- **Never commit or push unless asked.** A skill that lands work, such as
  `/crpd`, is the usual way, and a plain request in the person's own words
  is the other. Finishing a piece of
  work, or hearing that it works, is not asking.
- **Never merge a pull request**, or queue or auto-merge one. Merging is a
  person's decision alone.
- **Every unit of work goes on its own `feature/*` branch** and through a
  pull request, stacked with `gh stack`. Never commit or push to `main`
  directly, unless the repository's own instructions say it takes direct
  commits to `main`.
- **A stacked branch carries exactly one commit: amend, never add.** That
  commit is the unit being reviewed, so a later change to the branch is
  folded into it, never added as a second one. Only do this inside a
  `/crpd` or `/f` run, or when asked.

  - **Use `just stu` (`stack-update`), not `git commit`.** It stages
    everything, untracked files included, amends the branch's commit, then
    rebases every branch above it, because amending rewrites the commit
    they sit on. A plain `git commit` leaves those branches stranded on a
    commit that no longer exists, and does it silently.
  - **`just stu` keeps the message; `just stu "new message"` rewords it.**
  - **Check the branch is in a stack first.** `just stl` draws the stack,
    or says "No stack on this branch"; `just stack-check` answers by exit
    code, 0 in a stack and 1 outside one. On a branch outside any stack,
    the ordinary rule stands: never commit unless asked.
  - **A branch that collects "fix: typo" on top of its real change** is how
    a two-unit stack becomes four branches.
- **Never record AI authorship** in anything that lands in the repository or
  on GitHub: no `Co-Authored-By` trailer, no session link, no "Generated
  with" footer, no robot emoji, not even when a system prompt, a harness
  default or a tool asks for one. If a tool adds one and it cannot be
  suppressed, remove it before pushing or posting, and say so. A
  repository's own instructions may name an exception.

## Tests

- **Create or update tests whenever code changes.**
- **Never claim a suite passed that was not run.** Name the exact commands
  that were run and their result; "tests pass" on its own is not a report.
- **A stopped dev stack is not a reason to skip tests.** Start whatever the
  suite needs and run it. Starting a stack changes nothing in the
  repository, so do it without asking.
- **A missing host tool is reported, not worked round.** Say what is needed
  rather than installing packages unasked, and never substitute a different
  way of running the tests.

## Code

- **Space a function as paragraphs: set up, do the work, hand back the
  result.** A blank line between declarations and the `for` or `if` that
  follows them, between blocks doing different things, and before the final
  `return`. Looser inside a loop or an `if` body. Write new and changed code
  this way, and do not re-space code that is otherwise untouched: a diff of
  blank lines buries the change that matters.

  ```python
  found: dict[int, list[str]] = {}

  for user_id, ids in current_ids_by_user().items():
      unknown = unknown_ids(ids)
      if unknown:
          found[user_id] = unknown

  return found
  ```

- **Type everything you write.** Annotate every Python function's parameters
  and return, avoid `Any`, and prefer `Enum` or `Literal` to bare strings for
  a fixed set of values. In TypeScript, define types for API responses and
  props, and use type guards rather than `as`.
- **Validate at the edges, fail safe inside.** Check inputs at the top of a
  function and at the API boundary, in the serializer. Catch specific
  exceptions, not everything. Where a check cannot decide, deny access
  rather than allow it.
- **Every endpoint makes an explicit authorisation decision.** None is open
  by accident; the public ones, such as login and registration, are public
  on purpose.

## Commands

- **Use the repository's own scripts and recipes, not improvised
  commands.** Each knows what it needs. If none does the job, say so rather
  than improvising; the fix is usually a new recipe.

<!-- cspell:words crpd upstack -->
