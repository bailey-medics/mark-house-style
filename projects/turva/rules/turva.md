# Working in Turva

This adds Mark's Turva-only rules to his general working instructions. Each
Turva worktree has a read-only copy in `.claude/rules/`, with no `paths:`,
so it always loads there. `just -g turva-link` makes the copy, and a
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

## Issues

- **Every new issue goes on the turva-uk project board, in the `Triage`
  column.** A person decides priority, owner and timing there, so never put
  a new issue straight into a working column or set its priority.
- **Write an issue so someone who missed the conversation can pick it
  up**: the problem, why it matters, links to the code and specs, and a
  checklist of what done looks like. Link code with permalinks pinned to a
  commit, so the line numbers stay right.
- **Use sub-issues for the parts of a larger issue**, not just a mention
  in the text.
- **Assign an issue only to someone the person names**, and confirm their
  GitHub login rather than guessing it from a name.

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

## Quill Medical stays out of what Turva publishes

- **Never name Quill Medical, or cite it as evidence, in anything that
  lands in Turva**: code, comments, config, scripts, tests, docs, plans,
  commit messages and pull request descriptions. Give the reason in
  Turva's own terms: "a config with no rules passes every commit", not
  "Quill's config passed every commit".
- **Describe ported work by what it does, not where it came from.** Not
  "ported from Quill's `check-home-details.sh`", and not "as Quill does".
- **Leave what Turva already says about Quill alone**:
  `specifications/quill-port.md`, the ADRs and `SAFETY.md` that link to
  it, and the attribution the port decisions require. They record the
  port itself, which is a different thing from citing Quill as proof.
- **Talking with Mark about Quill is fine.** The rule covers only what
  lands in the repository or on its pull requests.

## Local-only material

- **`.private/` is git-ignored and holds local-only work**: decks, reports,
  notes and private plans. Read it only when asked, and never copy its
  contents into a commit, a pull request, a docs page or a comment.
