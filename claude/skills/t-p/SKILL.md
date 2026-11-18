---
name: t-p
description: Turn the decisions just made in the conversation into a new plan document in plans/
---

# Create a plan document

Using the decisions and information we have just gathered, create a new
plan document in `plans/`, using the plan docs rules you have.

Those rules are in `.claude/rules/plans.md`. Read it before writing: it
only loads on its own once a plan file is being touched.

The plan is written to be built by `/t-f`, so follow "Write it to be built
by `/t-f`" in those rules closely: one phase per reviewable unit, a first
phase safe to be on `main` on its own, and an `## Open questions`
checklist for anything the conversation left undecided. If there is one,
list those questions in the reply as well; `/t-g` settles them before `/t-f`
runs.
