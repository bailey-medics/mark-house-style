# House style setup plan

Mark's way of working with Claude Code - the working instructions, skills,
rules, hooks, just recipes and helper scripts - currently lives inside Turva,
in `.claude-personal/mark/` and a stack of tooling pull requests (#69, #75,
#78, #79, #82). Not everyone on the Turva team works this way, and the team
wants to adopt conventions slowly, so a personal set-up should not take up
room in a shared repository. Marcus keeps his in a separate house-style
repository that his agents read first, and this plan does the same for
Mark.

The outcome is this one private repository, `bailey-medics/mark-house-style`,
cloned once to `~/github/mark-house-style` and linked into the home folder.
Claude Code reads `~/.claude/` in every repository, so the set-up applies in
Turva, Quill and any new repository, in every worktree, with no copies to
keep in step. Each Turva worktree needs only one ignored line pointing at
the Turva-specific part.

## Open questions

- [x] **Which skill wins when a personal skill and a project skill share a
      name?** - Neither has to: every skill coming from Turva takes a `t-`
      prefix, such as `t-crpd`, `t-f` and `t-p`, so none shares a name with
      Quill's. All 13 clashed before: `crpd`, `e`, `f`,
      `fix-vs-code-problems`, `g`, `in-code-documentation`, `p`,
      `read-project-instructions`, `s`,
      `strong-static-typing-defensive-programming`, `tldr`,
      `update-docs-docs` and `update-nav`. Answered 18 November 2026.
- [x] **Does #81 stay in Turva?** - No. It closes with the rest of the
      tooling stack, but its change is kept: Turva's `AGENTS.md` needs to say
      not to commit to `main`, so Phase 6 opens it again as a new pull
      request from `main`, to be edited there. The same rule is repeated in
      this repository's `CLAUDE.md`. Answered 18 November 2026.
- [x] **Do the tmux hooks and recipes come here?** - Yes: the tab-topic
      and finished-response notification hooks, and the `cl` and `tw`
      recipes. Once this repository works, they are deleted from Turva's
      `main`. Answered 18 November 2026.
- [x] **Does this repository take direct commits to `main`?** - Yes. It
      has one author, and its code does not need to be guarded closely for
      now. Answered 18 November 2026.
- [x] **Is GPL-3.0 the right licence?** - Yes, it stays. It combines with
      Turva's and Quill's AGPL-3.0, so files can move between them, and it
      matters only if the repository is ever made public. Answered 18
      November 2026.

## Before running /f

- [x] Create `bailey-medics/mark-house-style`, private, and give the
      `bailey-medics` fine-grained token access to it. Done 18 November 2026;
      the clone at `~/github/mark-house-style` uses
      `~/.config/git/bailey-credentials`, as the Quill clones do.
- [x] Marcus rebases the Turva Storybook stack (#83 onwards) onto `main`, so
      nothing in it depends on the Claude stack. Phase 6 cannot close #82
      until then: GitHub would close #83 with it. Done 18 November 2026:
      #83's base is `main`.

## Phase 1: Lay out the repository

- [x] Add a `README.md` saying what the repository is: Mark's working
      instructions for coding agents, read in every repository through links
      from the home folder. Say how to install it (Phase 3) and that
      `projects/` holds per-repository additions. Done 18 November 2026.
- [x] Create the layout. Done 18 November 2026.

  ```text
  claude/CLAUDE.md          general working instructions
  claude/skills/            one folder per skill
  claude/rules/             path-scoped rules
  claude/hooks/             hook scripts
  projects/turva/rules/     Turva-only rules, turva.md among them
  just/justfile             personal recipes, run with just -g
  scripts/                  helper scripts the recipes call
  scripts/install.sh        links it all into the home folder
  scripts/turva-link.sh     sets up one Turva worktree
  plans/                    plans for this repository
  ```

- [x] Copy the files across from Turva's `.claude-personal/mark/`, taking
      each from the top of the Claude stack, `feature/claude-components-rule`,
      so every fold made there is included. Take `components.md`, `pages.md`
      and the in-code-documentation skill from Turva's #98 instead, where
      they were rewritten for the ported Storybook components. Leave out
      `reference-CLAUDE.md`, which is a local reference copy. Only 7 of
      the 13 skill folders held a skill; the other 6 were empty and were
      left behind. Done 18 November 2026.
- [x] Bring the Claude set-up port plan,
      `plans/2026-11-16-claude-setup-port-plan.md`, across from Turva. Its
      unfinished steps are about these files, so it belongs here once the
      Turva pull requests close. It is #82's version, with step 49 taken from
      #98, where it was ticked. Done 18 November 2026.

## Phase 2: Split the general from the Turva-specific

- [x] Rewrite `claude/CLAUDE.md` so it holds only what applies in every
      repository: the `implement` rule, the opening sentence and TL;DR,
      writing, git and pull requests, code style. A user-level `CLAUDE.md`
      loads in Quill too, so nothing in it may assume Turva. Done 18 November 2026.
- [x] Move the Turva-only parts into `projects/turva/rules/turva.md`: the
      sentence about `AGENTS.md`'s authority, `./s/test` and the dev stack,
      the `safety_file` pytest note, the `./s/` scripts, `.private/`, the
      overnight-run exception, and "the code does not sell anything". The
      `@AGENTS.md` import itself moved to `CLAUDE.local.md` (Phase 5). Done 18 November 2026.
- [x] Rename every skill with a `t-` prefix: its folder, and the `name:`
      in its `SKILL.md`, so `crpd` becomes `t-crpd`. They are Turva's
      versions, so their Turva commands, such as `./s/lint` in `t-crpd`, can
      stay. Done 18 November 2026.
- [x] Update every place that calls a skill by its old name, so nothing
      points at Quill's copy by mistake. `CLAUDE.md` names `/crpd`, `/f`,
      `/p` and `/g`; the `crpd`, `f`, `g` and `p` skills call each other; and
      the `plans` and `workflows` rules mention `/f` and `/g`. Search for
      each old name after renaming. The `## Before running /f` heading
      was kept as it is, because existing plans use it and `t-f` finds a
      plan's jobs by it. `t-f`'s calls to `just stack-*` and
      `s/stack/` now go to `just -g` and the scripts here. Done 18 November 2026.
- [x] Keep "never commit or push to `main` directly" in `claude/CLAUDE.md`,
      as #81 had it in Turva, but let a repository's own instructions
      override it, and add this repository's own `CLAUDE.md` saying it takes
      direct commits to `main`. Otherwise the general rule would forbid how
      this repository is meant to work. Done 18 November 2026.
- [x] Check each rule's `paths:`. They match relative to whichever repository
      is open, so `plans/**`, `justfile` and `.github/workflows/**` will
      apply in Quill as well. That is likely wanted; `components.md` and
      `pages.md` name Turva components, so move them to `projects/` or scope
      them so they do not mislead in Quill. They moved to
      `projects/turva/rules/`. Done 18 November 2026.

## Phase 3: Link it into the home folder

- [x] Link `~/.claude/CLAUDE.md` to `claude/CLAUDE.md`. Done 18 November 2026.
- [x] Link `~/.claude/rules` to `claude/rules`. Done 18 November 2026.
- [x] Link each skill into `~/.claude/skills/` one by one, rather than the
      whole folder, because `~/.claude/skills/synced` already exists and must
      be left alone. Done 18 November 2026.
- [x] Keep the tab-topic and notification hooks in each Turva worktree's
      own `.claude/settings.json`, pointing at `claude/hooks/` and
      `scripts/notification/` here, rather than in `~/.claude/settings.json`.
      Quill's project settings already run their own copies of both hooks,
      so home-folder hooks would fire twice there. `turva-link` repoints
      them. Done 18 November 2026.
- [x] Add a `SessionStart` hook running
      `git -C ~/github/mark-house-style pull --ff-only --quiet`, so each
      session starts on the latest version. A failed pull must not stop the
      session. Done 18 November 2026.
- [x] Put the linking in an `install` script, so a second machine is set up
      with one command, and so it can be re-run safely: `scripts/install.sh`.
      A second run changes nothing. Done 18 November 2026.

## Phase 4: Personal recipes and scripts

- [x] Write `just/justfile` with the personal recipes from Turva's
      `justfile`: `link-claude` is no longer needed; the `stack-*` recipes,
      `stack-watch` (#79) and the notification recipes (#78) come across.
      Give each `[no-cd]`, so it runs in the repository it is called from.
      All 20 recipes have it, including the new `turva-link`. Done 18 November 2026.
- [x] Move `s/stack/` and the notification scripts into `scripts/`, with
      their bats tests, and call them from the recipes by their path here.
      `bats scripts/stack/tests`, `bats scripts/notification/tests` and
      `bats claude/hooks/tab-topic.bats` pass: 60 tests. Done 18 November 2026.
- [x] Link `~/.config/just/justfile` to `just/justfile`, so `just -g <recipe>`
      works from any worktree. The shell alias is `t`, not `j`: `.bashrc`
      and `.zshrc` already make `j` plain `just`, which Turva's own recipes
      use. It was `jg` at first, renamed `t` the same day. Done 18 November 2026.
- [x] Bring `cl` and `tw` across too, from Turva's `justfile`, where #68
      merged them. They name sessions after the folder, so they work from any
      Turva worktree with `[no-cd]`. Bring the tab-topic hook's tmux title
      rules with them, as a documented snippet for `~/.tmux.conf`, in
      `scripts/tmux/README.md`. Outside a Turva folder both refuse. `cl` was renamed `c` the same day, so it runs as `t c`. Done 18 November 2026.

## Phase 5: Drop it into each Turva worktree

- [x] Add `CLAUDE.local.md` to `~/.config/git/ignore`, so it is ignored in
      every repository without changing Turva's `.gitignore`. Done 18 November 2026.
- [x] In `~/github/turva`, `turva-2` and `turva-3`, remove the `.claude/`
      links to `.claude-personal/mark/` (`CLAUDE.md`, `skills`, `rules`),
      so nothing loads twice. `t turva-link` does it. Done in `turva` and
      `turva-3` on 18 November 2026, and in `turva-2` once Marcus had moved
      its stack onto `main`, the same day.
- [x] Load the Turva part. The plan was a one-line `CLAUDE.local.md`
      importing `projects/turva.md`, but Claude Code only loads an import
      from outside the project after an approval, asked once per worktree
      in an interactive session, and it will not load a project rule that
      is a link to a file outside the project. So `CLAUDE.local.md` holds
      only `@AGENTS.md`, and `turva-link` copies `projects/turva/rules/`
      into `.claude/rules/` as read-only files, with a session-start hook in
      the worktree that refreshes the copies. Done 18 November 2026.
- [x] Start a Claude session in one worktree and check that the general
      instructions, the Turva part, the skills and the rules all load, and
      that a `just -g` recipe runs there. In `turva-3`, a fresh session
      quoted the TL;DR rule, "Working in Turva", "The code does not sell
      anything" and `AGENTS.md`'s first heading; the user-level
      `home-details` rule loaded too; `just -g stack-log` ran from
      `turva`. Done 18 November 2026.

## Phase 6: Retire the Turva tooling pull requests

- [x] Once Marcus has moved the Storybook stack onto `main`, close #82, #81,
      #79, #78, #75 and #69, top first, with a comment on each saying the set-up
      now lives in a personal repository. Close #98 too: its rules and step
      49 came here in Phase 1. Done 18 November 2026, with their branches
      deleted on GitHub and locally, and stack #80 removed from the local
      `gh stack` record. #98's local branch is left until `turva-2`'s
      session is finished, since it is checked out there, and so is the
      Storybook stack's local record, which still names the deleted #82
      branch as its base.
- [x] Open a new Turva pull request from `main` carrying #81's change, to be
      edited there rather than kept as it is. Close #81 with the rest of the
      stack. Its change, as it stood when closed:

  - **`AGENTS.md`, Git Workflow** - replace the three bullets that permit
    direct commits to `main` with:

    ```markdown
    - Never commit or push directly to `main`. Every change goes on its own descriptive branch and reaches `main` through a pull request, whoever or whatever wrote it.
    - Commit and push each validated coherent parcel to its branch; do not leave completed work only locally.
    - Use conventional commit messages (`feat(area):`, `fix:`, `docs:`, `chore(deps):`, `ci:`).
    ```

  - **`AGENTS.md`, the CI note** - "is the branch this project commits to"
    becomes "was then the branch this project committed to".
  - **`.github/workflows/ci.yml`, header comment** - drop the aside that
    `AGENTS.md` permits direct commits to `main`, put the sentence in the
    past tense, and add that changes now reach `main` only through pull
    requests, with the push run checking the merged result.

  #81's other changes, to `.claude-personal/` and the port plan, belong to
  the tooling stack and come here instead.

  Done 18 November 2026: #102, the bottom of Turva stack #104.
- [x] Open a Turva pull request deleting what #68 added to `main`: the
      `claude-session` and `tmux-window` recipes and their aliases in the
      `justfile`, their lines in `.gitignore`, and the terminal tab settings
      in `.vscode/settings.json`. Only once Phase 5 shows `just -g cl` and
      `just -g tw` working from a Turva worktree. Done 18 November 2026:
      #103, on #102. The terminal tab settings in `.vscode/settings.json`
      were kept after all: putting back the old values would override
      the personal VS Code settings that let tmux name the tabs.
- [ ] Remove `.claude-personal/` from the Turva checkouts, and the two
      exclude lines for `components.md` and `pages.md` from Turva's
      `.git/info/exclude`. Done in `turva` and `turva-3`, and the two lines
      are gone, 18 November 2026. Left: `turva-2`, once it leaves #98's
      branch, and then the `reference-CLAUDE.md` exclude line.

## Decisions

- **One clone, linked, rather than copies** - every repository and worktree
  reads the same files, so a change applies everywhere at once and nothing
  drifts.
- **A global justfile rather than an import in Turva's** - `just -g` needs
  no line in any shared `justfile`, so Turva's stays the team's alone.
- **Read-only copies for the Turva rules, refreshed at session start** -
  the plan wanted links or an import, so there would be no copies. Claude
  Code refuses both without an approval per worktree, and copies keep the
  path-scoped rules working. Making them read-only and refreshing them at
  every session start keeps them from drifting.
- **Hooks per worktree, not in the home folder** - Quill runs its own copies
  of the same hooks, so home-folder ones would fire twice there.
- **`bailey-medics`, private** - it sits beside Quill, and the existing
  `bailey-medics` token reaches it, so no new credentials file is needed.
