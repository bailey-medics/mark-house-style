# Working in Turva

This adds Mark's Turva-only rules to his general working instructions. Each
Turva worktree has a read-only copy in `.claude/rules/`, with no `paths:`,
so it always loads there. `just -g turva-link` makes the copy, and a
session-start hook refreshes it. Change this file, never the copy.

`AGENTS.md` is the authority on Turva: what it is, its safety invariants,
its layout, its commands and what needs approval. Where it and these rules
disagree, `AGENTS.md` wins, except where these rules are stricter.

## For the shared skills

The shared skills, such as `/t-crpd` and `/t-f`, read this section for
what is particular to Turva.

- **Tests before every commit are the whole gates, not a targeted
  subset**: `./s/lint` and `./s/test`, plus `./s/frontend` when the unit
  touches `frontend/`. `AGENTS.md` says not to commit red. `./s/lint`
  checks untracked files as well, so it sees the unit as it will be
  committed. `./s/test` needs the dev stack: start it with `./s/up -d`
  rather than skip the tests. While building, run only the tests that
  cover the unit, so each try is quick.
- **The commit message** adds a body when the why is not obvious from
  the subject, and says there whether `SAFETY.md` needed changing.
- **The pull request's `## Risks` section** says whether `SAFETY.md`
  changed and why, or why it did not need to, because Turva is
  safety-critical by consequence. It names any gate that could not run.
- **No readability command**: the description is not scored.
- **No other repositories**: a repository argument is an error here.
- **A Clinical Safety Officer decides** any new or changed hazard in
  `SAFETY.md`, and any change to how risk level is derived from severity
  and likelihood. A plan records who decides them, not a value the run
  chooses.
- **Tests that need a service**: the Django tests need the dev stack
  running; the `safety_file` tests need only Git.
- **In-code documentation** covers `safety_file/`, `app/` and
  `frontend/src/`, and leaves Django migrations, the dependency locks and
  `specifications/archive/` alone. The docs site's Code Reference pages
  are built from the docstrings in `safety_file/`, in the Google style
  that `docs/mkdocs.yml` sets for mkdocstrings. Longer prose about a
  component goes in a sibling `.mdx` guide, as `.claude/rules/components.md`
  sets out.

## Plans

- **Plans live in `plans/` at the root**, with no index.
- **Irreversible, for the plans rule, also means** a change to who can
  edit a safety file, and a commit to a safety file's Git history. Name
  either in its step, so `/t-f` stops and asks before committing it.

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
