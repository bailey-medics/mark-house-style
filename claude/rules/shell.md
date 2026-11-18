---
paths:
  - "**/*.bats"
  - "**/*.sh"
  - "s/**"
  - "scripts/**"
---

# Shell scripts and their bats tests

Shell scripts are read far more often than they are written, usually by
someone checking whether a change is safe. Write them, and their tests, for
that reader.

## Spacing: one idea per line, one step per block

- **Space a function as paragraphs: set up, do the work, hand back the
  result.** A function that reads as three or four blocks is far easier to
  check than fifteen unbroken lines, even when the code is identical. The
  blank lines go in exactly these places:

  - **Between the declarations and the `for` or `if` that follows them.**
  - **Between blocks doing different jobs.** Two steps that answer
    different questions do not share a paragraph.
  - **Before the final `return`, or the `echo` that hands back the result.**
  - **Inside a loop or an `if` body the rule is looser.** The body is one
    piece of work, so a value worked out on one line and tested on the next
    stays together. Add a gap there only when the body itself holds
    separate steps.

  ```bash
  hours_since() {
  	local timestamp="$1"
  	local opened
  	local now

  	opened="$(to_epoch "$timestamp")"
  	now="$(date -u +%s)"

  	echo $(((now - opened) / 3600))
  }
  ```

  And with a loop, where the body stays together:

  ```bash
  unknown_names() {
  	local wanted="$1"
  	local known
  	local name

  	known="$(list_names)"

  	for name in ${wanted}; do
  		if ! grep -qxF "${name}" <<<"${known}"; then
  			echo "${name}"
  		fi
  	done
  }
  ```

- **Lay out every bats test the same way: setup, then the `run`, then the
  assertions**, each block separated by a blank line. A test is then quick
  to scan: what was set up, what ran, what was checked.

  ```bash
  @test "plan refuses without a token" {
  	unset GITHUB_TOKEN

  	run "${script}" plan

  	[ "$status" -eq 1 ]
  	[[ "$output" == *"GITHUB_TOKEN is not set"* ]]
  }
  ```

  A test with no setup starts with the `run`. Keep the blank line before
  the assertions even when there is only one.

- **Declare one variable per line.** `local hours="$1" policy="$2"` packs
  two ideas into one line and hides the second from anyone scanning the left
  margin. Write each on its own line.
- **Prefer several small named functions to one long one.** If a block needs
  a comment saying what it does, that is usually a function wanting a name.
- **Space new and changed code this way, and leave untouched code alone.** A
  diff full of blank lines buries the change that matters.

## The shape of a script

- **Every script opens the same way.** The `#!` line, then a comment block
  in this order: one line saying what the script does, a `Usage:` line, and
  any notes that matter, such as whether it is safe to run twice. Then
  `set -euo pipefail`:

  ```bash
  #!/usr/bin/env bash
  # Copies the release notes into the docs site.
  #
  # Usage: copy-notes.sh <version>
  #
  # Safe to run twice: it overwrites the page it wrote before.
  set -euo pipefail

  main() {
  	local version="${1:-}"

  	if [ -z "${version}" ]; then
  		echo "No version given. Usage: copy-notes.sh <version>" >&2
  		exit 1
  	fi

  	echo "Copying the notes for ${version}"
  }

  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  	main "$@"
  fi
  ```

- **`set -euo pipefail` in every script.** Stop on an error, treat an unset
  variable as an error, and let a failure inside a pipe count.
- **Errors go to standard error.** Use the repository's own logging helper
  where it has one; otherwise `echo ... >&2`.

## Writing a script that tests can reach

- **Put the work in a `main()` function, called behind a source guard**,
  bash's equivalent of Python's `if __name__ == "__main__"`:

  ```bash
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  	main "$@"
  fi
  ```

  Sourcing a file runs it top to bottom. With a bare `main "$@"` at the end,
  a test that sources the script to reach one function would run the whole
  script, with bats' arguments. The guard makes sourcing define the
  functions and stop. Add it even when the tests run the script end to end;
  it costs nothing. A library that is only ever sourced needs no `main()`.
- **Validate required arguments at the top of `main()`**, before any work,
  as `local` positional parameters rather than bare upper-case globals.
- **Declare every variable `local`**, loop variables included, so nothing
  leaks into a shell that sources the script.
- **Split `local` from a command substitution.** `local x=$(cmd)` swallows
  `cmd`'s exit status, so a failure slips past `set -e`. Write `local x`,
  then `x=$(cmd)` on the next line.
- **Find files beside the script with `${BASH_SOURCE[0]}`, not `$0`.** When
  bats sources a script, `$0` is bats, so a path built from it points into
  bats' own folder.

## Testing with bats

- **Give every script a bats test**, beside it or in the repository's
  `tests/` folder for scripts, whichever the repository already does.
- **Stub outside commands rather than running them.** Put a fake on `PATH`
  that records its arguments and answers from a variable, then assert on
  what the script asked for. A test must never reach Docker, the network or
  a real account.
- **End every heredoc with `EOF`**, such as when writing a stub. It is the
  marker everyone recognises. Quote it, as `<<'EOF'`, so the text is
  written exactly as it stands and the stub reads its variables when it
  runs; leave it unquoted only when a value must be filled in as the file
  is written, and then escape the rest, such as `\$*`.

  ```bash
  cat >"${bin}/curl" <<'EOF'
  #!/usr/bin/env bash
  echo "$*" >>"${BATS_TEST_TMPDIR}/curl.log"
  EOF
  ```

- **Write multi-line text with a heredoc, not a one-line `printf` full of
  `\n`.** Whether it is a stub, a config file or Terraform for a test, a
  heredoc shows the text exactly as it will be written.
  `printf 'resource "x" {\n  name = "%s"\n}\n'` hides the shape, and its
  brackets inside quotes confuse editors' bracket matching, so a correct
  closing `}` further down shows as an error. Use unquoted `<<EOF` when a
  value must be filled in. A one-line `printf` is still fine for one line.

  ```bash
  cat >>"${repo}/rulesets.tf" <<EOF
  resource "github_repository_ruleset" "${name}" {
    name = "${name}"
  }
  EOF
  ```

- **Assert a negative with `run !`, never a bare `!`.** A bare `!` only fails
  the test when it is the last command in the `@test` block. Anywhere else
  `set -e` ignores it, and the assertion passes whether or not it holds.
- **Declare `bats_require_minimum_version 1.5.0`** at the top of any file
  that puts flags on `run`, such as `run !`, `run -1` or
  `run --separate-stderr`. Without it bats runs in a compatibility mode
  where the flags are ignored, so `run !` passes vacuously.
- **Treat bats warnings as failures.** bats reports both mistakes above as
  `BW01` or `BW02` and still exits 0, so a vacuous assertion shows green.
  Where the repository's test runner does not fail on them, say so rather
  than relying on it, and never add a way to tolerate one.
- **Prove an assertion can fail.** After writing a test that checks
  something does not happen, break the script on purpose and watch the test
  go red. A negative assertion that cannot fail is the most common way a
  green suite hides a regression.
- **Do not trust a bats run on macOS for a script that runs on Linux.** The
  Mac's bash is 3.2 by default, its core tools differ, and its `sha256sum`
  is not GNU's. Use the repository's container or CI to decide; a local Mac
  run is only for iterating.

<!-- cspell:words vacuously -->
