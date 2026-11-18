# Working in Turva

This adds Mark's Turva-only rules to his general working instructions. Each
Turva worktree has a read-only copy in `.claude/rules/`, with no `paths:`,
so it always loads there. `jg turva-link` makes the copy, and a
session-start hook refreshes it. Change this file, never the copy.

`AGENTS.md` is the authority on Turva: what it is, its safety invariants,
its layout, its commands and what needs approval. Where it and these rules
disagree, `AGENTS.md` wins, except where these rules are stricter.

## Skills

- **Turva's skills carry a `t-` prefix**: `/t-crpd`, `/t-f`, `/t-g`, `/t-p`,
  `/t-e`, `/t-s` and `/t-in-code-documentation`. They name Turva's own
  commands, such as `./s/lint`, so use them only in Turva.

## Git and pull requests

- **`AGENTS.md` asks agents to commit and push each finished parcel.** The
  general rule is stricter and wins: never commit or push unless asked.
- **The one exception to "never record AI authorship" is an overnight run**,
  where `specifications/nightly-triage.md` asks for the model to be named in
  the pull request.

## Tests

- **`./s/test` runs the Django suite in the `web` container**, so start the
  stack with `./s/up -d` and run it, without asking.
- **The `safety_file` suite runs on the host and needs `pytest`**, from
  `.venv` or the system Python. If it is missing, say so rather than
  installing it.

## Code

- **The frontend's TypeScript is `strict`.**
- **The code does not sell anything.** Whether Turva charges for something,
  and how, is a business matter that can change without the code changing.
  Code, comments, error messages and test names describe the mechanism, such
  as who may do what, never the commerce.

## Commands

- **Use the `./s/` scripts and the `just` recipes.** Each knows which
  container to run in and what it needs.

## Local-only material

- **`.private/` is git-ignored and holds local-only work**: decks, reports,
  notes and private plans. Read it only when asked, and never copy its
  contents into a commit, a pull request, a docs page or a comment.
