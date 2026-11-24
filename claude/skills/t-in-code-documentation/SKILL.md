---
name: t-in-code-documentation
description: In code documentation
disable-model-invocation: true
---

# In code documentation

## Review all code

- Read through the code base and document as below. The repository's "For
  the shared skills" section names the folders to cover, what to leave
  alone, and anything published from the docstrings; without one, cover
  the whole code base.
- Leave generated and archived files alone, such as migrations and
  dependency locks.
- Change documentation only. Do not alter behaviour while you are there; if
  the code looks wrong, say so and leave it.

## Python

Add / update comprehensive Google-style docstrings to all functions, classes, and methods. For each:

- Summary: Brief description of purpose
- Args: parameter descriptions with types
- Returns: return value description with type
- Raises: any exceptions thrown
- Examples: only for complex functions where usage isn't obvious - use sparingly

Also, add / update summary module documentation at the top of the module.

Where the repository's docs site publishes docstrings, write each
published one for a reader who has not seen the code.

## TypeScript

Add / update comprehensive TSDoc comments to all functions, classes, and methods. For each:

- Summary: Brief description of purpose
- @param: parameter descriptions (types inferred from TypeScript)
- @returns: return value description (type inferred from TypeScript)
- @throws: any exceptions thrown
- @example: only for complex functions where usage isn't obvious - use sparingly

Also, add / update summary module documentation at the top of the module.

## React Components

Follow the TypeScript standards above. Additionally:

- Add component-level TSDoc describing the component's purpose
- Document all props in the Props/interface definition
- Add usage examples in TSDoc only for complex components

## Storybook Stories

Stories are self-documenting through their structure. Ensure:

- Each story file has a clear `title` in the meta export
- All argTypes have clear `description` fields
- Story names clearly describe what they demonstrate
- Longer prose about a component goes where the repository's rules for
  components say, such as a sibling `.mdx` guide or a `description` in
  the meta export
- Do NOT add TSDoc comments to individual story objects

## Tests

Tests should be self-documenting through descriptive names and clear structure. Only document:

- Test utilities and helper functions (using same standards as above)
- Test data factories and fixtures
- Complex test setup that isn't obvious from the code
- Shared test configuration

Individual test cases should not have documentation comments - use descriptive test names instead.
