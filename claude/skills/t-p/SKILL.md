---
name: t-p
description: Turn the decisions just made in the conversation into a new plan document in the repository's plans folder
---

# Create a plan document

Using the decisions and information we have just gathered, create a new
plan document in the repository's plans folder, using the plan docs rules
you have. The repository's "For the shared skills" section, or its plans
rule, says where that folder is and whether the plans have an index.

Those rules are in two files: the shared `plans.md`, linked at
`~/.claude/rules/plans.md`, and any additions the repository makes in its
own `.claude/rules/plans.md`. Read both before writing: they only load on
their own once a plan file is being touched.

The plan is written to be built by `/t-f`, so follow "Write it to be built
by `/t-f`" in those rules closely: one phase per reviewable unit, a first
phase safe to be on `main` on its own, and an `## Open questions`
checklist for anything the conversation left undecided. If there is one,
list those questions in the reply as well; `/t-g` settles them before `/t-f`
runs.
