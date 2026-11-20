# Hours calculator

Works out how many hours you have spent on a repository, from when you send prompts to Claude Code. It needs no timesheet: a hook notes the time of each prompt, and a report turns those times into hours per day and per week.

It is personal tooling. It does nothing until a Claude Code hook calls it, and it only ever logs prompts sent from inside the repository you name.

## How prompts become hours

- **Prompts close together form one block of work.** A silence of more than 20 minutes ends the block.
- **Each block gets 5 minutes after its last prompt**, for reading the final reply.
- **Each block also gets a lead-in**, for writing its first prompt. It is the prompt's length at 40 characters a minute, never under 3 minutes and never over 30, so pasted text cannot inflate it.
- **A block counts towards the day it started on.**

Every one of these numbers can be changed on the report, with `--gap`, `--pad`, `--rate`, `--lead-min` and `--lead-cap`.

## What it keeps, and where

One log per repository, at `~/.local/share/hours/<repository name>.jsonl`. It is outside every repository, so it is never committed.

Each line holds a time, a Claude Code session id, the worktree's folder name and the prompt's length in characters. **It never holds the text of a prompt.**

## Turning it on

Add a `UserPromptSubmit` hook to your own `~/.claude/settings.json`, naming the repository to track:

```json
"hooks": {
  "UserPromptSubmit": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "python3 ~/github/mark-house-style/scripts/hours/hours.py --repo ~/github/turva hook",
          "timeout": 5,
          "async": true
        }
      ]
    }
  ]
}
```

Any worktree of the repository counts, so `turva-2` and `turva-3` add to the same log as `turva`. To track a second repository, add a second hook with its own `--repo`.

To count the prompts you sent before the hook was set up, load them from Claude Code's saved transcripts. It is safe to run twice:

```sh
python3 ~/github/mark-house-style/scripts/hours/hours.py --repo ~/github/turva backfill
```

## Using it

`hours.py` below is short for the full path above. Set `HOURS_REPO=~/github/turva` in your shell to leave `--repo` off; otherwise put `--repo <path>` straight after `hours.py`, before the command.

```sh
hours.py report                       # hours per day and per week
hours.py report --since 2026-11-01    # from a date onwards

hours.py start "reviewing pull requests"   # time work that sends no prompts
hours.py stop
hours.py status
hours.py start --at 15:30             # when you forgot to press start

hours.py add 45m "thinking on a walk" # time away from the keyboard
```

- **Timer time and prompt blocks are merged**, so a stretch covered by both counts once.
- **One timer runs at a time.** Starting a new one stops the old one.
- **A timer left running counts for 4 hours at most**, and the report says so.
- **Time added by hand is counted on top** of everything else.

## Tests

```sh
python3 -m unittest discover -s scripts/hours
```
