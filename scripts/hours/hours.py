#!/usr/bin/env python3
"""Private log of the hours spent working on one repository.

Claude Code runs `hours.py --repo <path> hook` each time a prompt is sent.
A prompt sent from any worktree of that repository appends one line to its
log; prompts from anywhere else are ignored. `hours.py --repo <path> report`
turns those lines into hours. `--repo` can be left off when the
`HOURS_REPO` environment variable names the repository instead.

Set up the hook in `~/.claude/settings.json`, once per tracked repository:

    "hooks": {
      "UserPromptSubmit": [
        {"hooks": [{"type": "command",
          "command": "python3 <this folder>/hours.py --repo ~/github/<repo> hook"}]}
      ]
    }

`hours.py --repo <path> backfill` loads the prompts already in Claude Code's
saved transcripts, so the log can start from before the hook was set up.

How prompts become hours: prompts close together form one block of work. A
silence longer than the gap (20 minutes unless told otherwise) ends the
block. Each block also gets a few minutes of padding after its last prompt,
for reading the final reply. A block counts towards the day it started on.

Writing the first prompt of a block takes time too, and nothing records when
the typing began. So each block gets a lead-in worked out from how long that
first prompt is: its characters divided by a typing rate, never less than a
minimum and never more than a cap. The cap is there because pasted text
counts as length. A lead-in never reaches back into the block before it.

Work that sends no prompts, such as reading someone else's pull request,
is timed instead:

    hours.py start "reviewing pull requests"
    hours.py stop

Timer time is merged with prompt blocks, so a stretch covered by both counts
once. One timer runs at a time, and starting a new one stops the old one. A
timer left running is cut off after a few hours, and the report says so.
`--at 15:30` on `start` or `stop` sets the real time when it was forgotten.

Anything else is added by hand, and is counted on top of the rest:

    hours.py add 45m "thinking on a walk"

The log lives outside every repository, in `~/.local/share/hours/`, one
file per tracked repository named after it, so it is never committed. It
holds times, session ids, worktree names and the length of each prompt in
characters, never the prompt text.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections.abc import Sequence
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, time, timedelta, tzinfo
from pathlib import Path
from typing import Literal

DATA = Path.home() / ".local" / "share" / "hours"
PROJECTS = Path.home() / ".claude" / "projects"
REPO_VARIABLE = "HOURS_REPO"

DEFAULT_GAP_MINUTES = 20
DEFAULT_PAD_MINUTES = 5
DEFAULT_CHARS_PER_MINUTE = 40
DEFAULT_LEAD_MIN_MINUTES = 3
DEFAULT_LEAD_CAP_MINUTES = 30
DEFAULT_TIMER_CAP_HOURS = 4
GIT_TIMEOUT_SECONDS = 3
SAME_PROMPT = timedelta(seconds=5)

DURATION = re.compile(r"(?:(?P<hours>\d+(?:\.\d+)?)h)?(?:(?P<minutes>\d+)m)?")
CLOCK = re.compile(r"(?P<hour>\d{1,2}):(?P<minute>\d{2})")

TimerAction = Literal["start", "stop"]


@dataclass(frozen=True)
class Prompt:
    """One prompt sent to Claude Code from a Turva worktree."""

    at: datetime
    session: str
    worktree: str
    chars: int | None = None


@dataclass(frozen=True)
class Manual:
    """Time added by hand, for work away from the keyboard."""

    day: date
    minutes: int
    note: str


@dataclass(frozen=True)
class TimerEvent:
    """One press of the timer's start or stop."""

    at: datetime
    action: TimerAction
    note: str = ""


@dataclass(frozen=True)
class Span:
    """One run of the timer, from start to stop."""

    start: datetime
    end: datetime
    note: str
    capped: bool = False
    running: bool = False

    @property
    def hours(self) -> float:
        return (self.end - self.start).total_seconds() / 3600


@dataclass
class Entries:
    """Everything in the log, sorted by kind."""

    prompts: list[Prompt] = field(default_factory=list)
    manual: list[Manual] = field(default_factory=list)
    timers: list[TimerEvent] = field(default_factory=list)
    skipped: int = 0


@dataclass(frozen=True)
class Block:
    """One unbroken stretch of work, from its first prompt to after its last.

    `lead` is the time credited for writing the first prompt, before `start`.
    """

    start: datetime
    end: datetime
    lead: timedelta = timedelta(0)

    @property
    def hours(self) -> float:
        return (self.end - self.start + self.lead).total_seconds() / 3600


@dataclass(frozen=True)
class LeadIn:
    """How the length of a block's first prompt becomes time spent writing it."""

    chars_per_minute: int = DEFAULT_CHARS_PER_MINUTE
    minimum: timedelta = timedelta(minutes=DEFAULT_LEAD_MIN_MINUTES)
    cap: timedelta = timedelta(minutes=DEFAULT_LEAD_CAP_MINUTES)

    def for_prompt(self, chars: int | None) -> timedelta:
        """A prompt of unknown length earns the minimum."""
        if chars is None:
            return self.minimum

        typing = timedelta(minutes=chars / self.chars_per_minute)

        return min(max(typing, self.minimum), self.cap)


@dataclass
class Day:
    """What one day adds up to.

    `worked_hours` is prompt blocks and timer runs together, with any overlap
    counted once. `timer_hours` is the timer's own length, shown for interest.
    """

    worked_hours: float = 0.0
    blocks: int = 0
    timers: int = 0
    timer_hours: float = 0.0
    manual_hours: float = 0.0

    @property
    def hours(self) -> float:
        return self.worked_hours + self.manual_hours


def parse_duration(text: str) -> int:
    """Turn `45m`, `2h`, `1.5h` or `1h30m` into whole minutes."""
    match = DURATION.fullmatch(text.strip().lower())
    if match is None or not match.group(0):
        raise ValueError(f"not a duration: {text!r} (try 45m, 2h or 1h30m)")

    minutes = round(float(match["hours"] or 0) * 60) + int(match["minutes"] or 0)
    if minutes <= 0:
        raise ValueError(f"a duration must be longer than nothing: {text!r}")

    return minutes


def parse_at(text: str, now: datetime) -> datetime:
    """Turn `15:30` (today, on this machine's clock) or a full date and time into a moment."""
    clock = CLOCK.fullmatch(text.strip())
    if clock is not None:
        local_now = now.astimezone()
        when = time(int(clock["hour"]), int(clock["minute"]))

        return datetime.combine(local_now.date(), when, local_now.tzinfo)

    try:
        moment = datetime.fromisoformat(text.strip())
    except ValueError as error:
        raise ValueError(f"not a time: {text!r} (try 15:30 or 2026-11-17T15:30)") from error

    return moment if moment.tzinfo is not None else moment.astimezone()


def parse_line(line: str) -> Prompt | Manual | TimerEvent | None:
    """Read one line of the log. A line that cannot be read gives None."""
    try:
        record: object = json.loads(line)
    except ValueError:
        return None
    if not isinstance(record, dict):
        return None

    try:
        if record.get("kind") == "prompt":
            at = datetime.fromisoformat(record["ts"])
            if at.tzinfo is None:
                return None

            chars = record.get("chars")
            if not isinstance(chars, int) or isinstance(chars, bool) or chars < 0:
                chars = None

            return Prompt(at, str(record["session"]), str(record["worktree"]), chars)

        if record.get("kind") == "manual":
            day = date.fromisoformat(record["day"])

            return Manual(day, int(record["minutes"]), str(record["note"]))

        if record.get("kind") == "timer" and record.get("action") in ("start", "stop"):
            at = datetime.fromisoformat(record["ts"])
            if at.tzinfo is None:
                return None

            action: TimerAction = "start" if record["action"] == "start" else "stop"

            return TimerEvent(at, action, str(record.get("note", "")))
    except (KeyError, TypeError, ValueError):
        return None

    return None


def read_log(log: Path) -> Entries:
    """Read the whole log, counting the lines that could not be read."""
    entries = Entries()

    if not log.exists():
        return entries

    for line in log.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue

        entry = parse_line(line)
        if isinstance(entry, Prompt):
            entries.prompts.append(entry)
        elif isinstance(entry, Manual):
            entries.manual.append(entry)
        elif isinstance(entry, TimerEvent):
            entries.timers.append(entry)
        else:
            entries.skipped += 1

    return entries


def append(log: Path, record: dict[str, str | int]) -> None:
    """Add one line to the log. One short write, so worktrees cannot interleave."""
    log.parent.mkdir(parents=True, exist_ok=True)

    with log.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")


def prompt_record(prompt: Prompt, source: str) -> dict[str, str | int]:
    record: dict[str, str | int] = {
        "kind": "prompt",
        "ts": prompt.at.isoformat(),
        "session": prompt.session,
        "worktree": prompt.worktree,
        "source": source,
    }
    if prompt.chars is not None:
        record["chars"] = prompt.chars

    return record


def timer_record(event: TimerEvent) -> dict[str, str | int]:
    record: dict[str, str | int] = {
        "kind": "timer",
        "action": event.action,
        "ts": event.at.isoformat(),
    }
    if event.note:
        record["note"] = event.note

    return record


def in_order(events: Sequence[TimerEvent]) -> list[TimerEvent]:
    """Sort by time, putting a stop before a start at the same moment."""
    return sorted(events, key=lambda event: (event.at, event.action == "start"))


def running_timer(events: Sequence[TimerEvent]) -> TimerEvent | None:
    """The start of the timer that is running now, if one is."""
    running: TimerEvent | None = None

    for event in in_order(events):
        running = event if event.action == "start" else None

    return running


def timer_spans(events: Sequence[TimerEvent], cap: timedelta, now: datetime) -> list[Span]:
    """Pair starts with stops. A start with no stop runs until `now`.

    A start that follows another start stops the first one. A stop with no
    start is ignored. No run counts for longer than `cap`.
    """
    spans: list[Span] = []
    running: TimerEvent | None = None

    def close(started: TimerEvent, end: datetime, still_running: bool) -> None:
        capped = end - started.at > cap
        spans.append(
            Span(started.at, min(end, started.at + cap), started.note, capped, still_running)
        )

    for event in in_order(events):
        if running is not None:
            close(running, event.at, False)
        running = event if event.action == "start" else None

    if running is not None:
        close(running, max(now, running.at), True)

    return spans


def main_worktree(path: Path) -> Path | None:
    """The main worktree of the repository `path` is in, or None if it is in none.

    Any worktree of a repository, or a folder inside one, gives the same
    answer, so the log does not depend on which worktree was named.
    """
    command = ["git", "-C", str(path), "rev-parse", "--path-format=absolute", "--git-common-dir"]

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT_SECONDS,
            check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    common_dir = Path(result.stdout.strip())
    if common_dir.name != ".git":
        return None

    return common_dir.parent.resolve()


def log_for(main: Path, data: Path) -> Path:
    """The log for the repository whose main worktree is `main`."""
    return data / f"{main.name}.jsonl"


def worktree_of(cwd: Path, main: Path) -> str | None:
    """Name the worktree `cwd` is in, or None if it is not this repository."""
    command = [
        "git",
        "-C",
        str(cwd),
        "rev-parse",
        "--path-format=absolute",
        "--git-common-dir",
        "--show-toplevel",
    ]

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT_SECONDS,
            check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    lines = result.stdout.splitlines()
    if len(lines) != 2:
        return None

    common_dir, top_level = lines
    if Path(common_dir).resolve() != (main / ".git").resolve():
        return None

    return Path(top_level).name


def record_prompt(payload: str, log: Path, main: Path, now: datetime) -> bool:
    """Log the prompt Claude Code just described on stdin. True if a line was written."""
    try:
        data: object = json.loads(payload)
    except ValueError:
        return False
    if not isinstance(data, dict):
        return False

    cwd = data.get("cwd")
    session = data.get("session_id")
    if not isinstance(cwd, str) or not isinstance(session, str):
        return False

    worktree = worktree_of(Path(cwd), main)
    if worktree is None:
        return False

    text = data.get("prompt")
    chars = len(text) if isinstance(text, str) else None

    append(log, prompt_record(Prompt(now, session, worktree, chars), "hook"))

    return True


def find_blocks(
    prompts: Sequence[Prompt], gap: timedelta, pad: timedelta, lead_in: LeadIn
) -> list[Block]:
    """Group prompts into blocks of work, split wherever the silence exceeds `gap`."""
    ordered = sorted(prompts, key=lambda prompt: prompt.at)
    if not ordered:
        return []

    found: list[Block] = []
    start = last = ordered[0].at
    lead = lead_in.for_prompt(ordered[0].chars)

    for prompt in ordered[1:]:
        if prompt.at - last > gap:
            found.append(Block(start, last + pad, lead))
            # A lead-in may not reach back into the block before it.
            lead = min(lead_in.for_prompt(prompt.chars), prompt.at - (last + pad))
            start = prompt.at
        last = prompt.at

    found.append(Block(start, last + pad, lead))

    return found


def daily_totals(
    prompts: Sequence[Prompt],
    manual: Sequence[Manual],
    spans: Sequence[Span],
    gap: timedelta,
    pad: timedelta,
    lead_in: LeadIn,
    zone: tzinfo | None = None,
) -> dict[date, Day]:
    """Add up each day. `zone` decides where a day starts; None means this machine's.

    Blocks and timer runs are laid on one timeline and merged where they
    overlap. Each merged stretch counts towards the day of the earliest prompt
    or timer start inside it, so a lead-in never moves work to the day before.
    """
    days: dict[date, Day] = {}
    # Each stretch is (the moment that decides its day, from, to).
    stretches: list[tuple[datetime, datetime, datetime]] = []

    for block in find_blocks(prompts, gap, pad, lead_in):
        day = days.setdefault(block.start.astimezone(zone).date(), Day())
        day.blocks += 1
        stretches.append((block.start, block.start - block.lead, block.end))

    for span in spans:
        day = days.setdefault(span.start.astimezone(zone).date(), Day())
        day.timers += 1
        day.timer_hours += span.hours
        stretches.append((span.start, span.start, span.end))

    for anchor, start, end in merge(stretches):
        days[anchor.astimezone(zone).date()].worked_hours += (end - start).total_seconds() / 3600

    for entry in manual:
        days.setdefault(entry.day, Day()).manual_hours += entry.minutes / 60

    return days


def merge(
    stretches: Sequence[tuple[datetime, datetime, datetime]],
) -> list[tuple[datetime, datetime, datetime]]:
    """Join stretches that overlap or touch, keeping the earliest anchor of each."""
    merged: list[tuple[datetime, datetime, datetime]] = []

    for anchor, start, end in sorted(stretches, key=lambda stretch: stretch[1]):
        if merged and start <= merged[-1][2]:
            last_anchor, last_start, last_end = merged[-1]
            merged[-1] = (min(last_anchor, anchor), last_start, max(last_end, end))
        else:
            merged.append((anchor, start, end))

    return merged


def render(days: dict[date, Day]) -> str:
    """Lay the days out by week, with a total for each week and overall."""
    if not days:
        return "No hours logged yet."

    weeks: dict[date, float] = {}
    for day, totals in days.items():
        monday = day - timedelta(days=day.weekday())
        weeks[monday] = weeks.get(monday, 0.0) + totals.hours

    lines: list[str] = []
    current: date | None = None

    for day in sorted(days):
        totals = days[day]
        monday = day - timedelta(days=day.weekday())
        if monday != current:
            if lines:
                lines.append("")
            lines.append(f"Week of {monday:%d %b %Y}: {weeks[monday]:.1f} h")
            current = monday

        detail = f"{totals.blocks} block{'' if totals.blocks == 1 else 's'}"
        if totals.timers:
            detail += f", {totals.timer_hours:.1f} h on the timer"
        if totals.manual_hours:
            detail += f", {totals.manual_hours:.1f} h added by hand"
        lines.append(f"  {day:%a %d %b}  {totals.hours:5.1f} h   {detail}")

    lines.append("")
    lines.append(f"Total: {sum(weeks.values()):.1f} h")

    return "\n".join(lines)


def prompt_length(message: object) -> int | None:
    """Count the characters of text in a transcript's record of a prompt."""
    if not isinstance(message, dict):
        return None

    content = message.get("content")
    if isinstance(content, str):
        return len(content)
    if not isinstance(content, list):
        return None

    texts = [part.get("text") for part in content if isinstance(part, dict)]

    return sum(len(text) for text in texts if isinstance(text, str))


def transcript_prompts(transcript: Path) -> list[Prompt]:
    """Pull the prompts a person sent out of one Claude Code transcript."""
    found: list[Prompt] = []

    for line in transcript.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            record: object = json.loads(line)
        except ValueError:
            continue
        if not isinstance(record, dict):
            continue
        if record.get("type") != "user" or record.get("isSidechain"):
            continue

        origin = record.get("origin")
        if not isinstance(origin, dict) or origin.get("kind") != "human":
            continue

        stamp = record.get("timestamp")
        session = record.get("sessionId")
        cwd = record.get("cwd")
        if not isinstance(stamp, str) or not isinstance(session, str):
            continue

        try:
            at = datetime.fromisoformat(stamp)
        except ValueError:
            continue
        if at.tzinfo is None:
            continue

        worktree = Path(cwd).name if isinstance(cwd, str) else transcript.parent.name
        found.append(Prompt(at, session, worktree, prompt_length(record.get("message"))))

    return found


def backfill(projects: Path, main: Path, log: Path) -> int:
    """Copy prompts from saved transcripts into the log. Safe to run twice.

    The hook and the transcript stamp the same prompt a moment apart, so a
    prompt counts as already logged if its session has one within a few seconds.
    """
    prompts = read_log(log).prompts
    known: dict[str, list[datetime]] = {}
    prefix = re.sub(r"[^A-Za-z0-9]", "-", str(main))
    added = 0

    for prompt in prompts:
        known.setdefault(prompt.session, []).append(prompt.at)

    for transcript in sorted(projects.glob(f"{prefix}*/*.jsonl")):
        for prompt in transcript_prompts(transcript):
            seen = known.setdefault(prompt.session, [])
            if any(abs(prompt.at - at) <= SAME_PROMPT for at in seen):
                continue

            append(log, prompt_record(prompt, "backfill"))
            seen.append(prompt.at)
            added += 1

    return added


def describe(length: timedelta) -> str:
    whole = int(length.total_seconds() // 60)

    return f"{whole // 60} h {whole % 60:02d} m" if whole >= 60 else f"{whole} m"


def timer_command(
    action: Literal["start", "stop", "status"],
    note: str,
    at_text: str | None,
    log: Path,
    now: datetime,
) -> int:
    """Start, stop or report on the timer. Returns the exit code."""
    events = read_log(log).timers
    running = running_timer(events)
    cap = timedelta(hours=DEFAULT_TIMER_CAP_HOURS)

    if action == "status":
        if running is None:
            print("No timer is running.")

            return 0

        length = now - running.at
        label = f" ({running.note})" if running.note else ""
        print(f"Timer running for {describe(length)}{label}, since {running.at.astimezone():%H:%M}.")
        if length > cap:
            print(f"It is over {DEFAULT_TIMER_CAP_HOURS} h, so only {DEFAULT_TIMER_CAP_HOURS} h will count.")

        return 0

    try:
        moment = parse_at(at_text, now) if at_text is not None else now
    except ValueError as error:
        print(error, file=sys.stderr)

        return 2

    if moment > now + timedelta(minutes=1):
        print("That time is in the future.", file=sys.stderr)

        return 2

    latest = max((event.at for event in events), default=None)

    if action == "stop":
        if running is None:
            print("No timer is running.", file=sys.stderr)

            return 1
        if moment <= running.at:
            print(f"The timer started at {running.at.astimezone():%H:%M}, after that time.", file=sys.stderr)

            return 2

        append(log, timer_record(TimerEvent(moment, "stop")))
        print(f"Timer stopped after {describe(moment - running.at)}.")
        if moment - running.at > cap:
            print(f"It ran over {DEFAULT_TIMER_CAP_HOURS} h, so only {DEFAULT_TIMER_CAP_HOURS} h will count.")

        return 0

    if latest is not None and moment < latest:
        print(
            f"The last timer change was at {latest.astimezone():%H:%M}, after that time.",
            file=sys.stderr,
        )

        return 2

    if running is not None:
        append(log, timer_record(TimerEvent(moment, "stop")))
        label = f" ({running.note})" if running.note else ""
        print(f"Stopped the timer that was running{label} after {describe(moment - running.at)}.")

    append(log, timer_record(TimerEvent(moment, "start", note)))
    print(f"Timer started at {moment.astimezone():%H:%M}.")

    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Log and report the hours spent on a repository.")
    parser.add_argument(
        "--repo",
        default=os.environ.get(REPO_VARIABLE),
        metavar="PATH",
        help=f"the repository to track, or any worktree of it; defaults to ${REPO_VARIABLE}",
    )
    commands = parser.add_subparsers(dest="command", required=True)

    commands.add_parser("hook", help="log one prompt; Claude Code runs this")
    commands.add_parser("backfill", help="load prompts from saved transcripts")

    report = commands.add_parser("report", help="print hours per day and week")
    report.add_argument("--gap", type=int, default=DEFAULT_GAP_MINUTES, metavar="MINUTES")
    report.add_argument("--pad", type=int, default=DEFAULT_PAD_MINUTES, metavar="MINUTES")
    report.add_argument("--since", type=date.fromisoformat, metavar="YYYY-MM-DD")
    report.add_argument(
        "--rate",
        type=int,
        default=DEFAULT_CHARS_PER_MINUTE,
        metavar="CHARS",
        help="characters a minute, for the time spent writing a block's first prompt",
    )
    report.add_argument(
        "--lead-min", type=int, default=DEFAULT_LEAD_MIN_MINUTES, metavar="MINUTES"
    )
    report.add_argument(
        "--lead-cap", type=int, default=DEFAULT_LEAD_CAP_MINUTES, metavar="MINUTES"
    )

    report.add_argument(
        "--timer-cap", type=float, default=DEFAULT_TIMER_CAP_HOURS, metavar="HOURS"
    )

    start = commands.add_parser("start", help="start the timer, for work with no prompts")
    start.add_argument("note", nargs="?", default="")
    start.add_argument("--at", metavar="HH:MM", help="when it really started")

    stop = commands.add_parser("stop", help="stop the timer")
    stop.add_argument("--at", metavar="HH:MM", help="when it really stopped")

    commands.add_parser("status", help="say whether the timer is running")

    add = commands.add_parser("add", help="add time by hand")
    add.add_argument("duration", type=parse_duration, help="45m, 2h or 1h30m")
    add.add_argument("note", nargs="?", default="")
    add.add_argument("--date", type=date.fromisoformat, metavar="YYYY-MM-DD")

    return parser


def main(argv: Sequence[str]) -> int:
    args = build_parser().parse_args(argv)
    repo: str | None = args.repo
    main = main_worktree(Path(repo).expanduser()) if repo else None

    if args.command == "hook":
        # A hook that fails must never get in the way of the prompt, so a
        # missing or wrong --repo logs nothing rather than complaining.
        if main is None:
            return 0

        try:
            record_prompt(sys.stdin.read(), log_for(main, DATA), main, datetime.now(UTC))
        except OSError:
            pass

        return 0

    if repo is None:
        print(f"Name the repository to track with --repo, or set ${REPO_VARIABLE}.", file=sys.stderr)

        return 2

    if main is None:
        print(f"Not a git repository: {repo}", file=sys.stderr)

        return 2

    log = log_for(main, DATA)

    if args.command == "backfill":
        print(f"Added {backfill(PROJECTS, main, log)} prompts from saved transcripts.")

        return 0

    if args.command == "add":
        day: date = args.date or datetime.now().astimezone().date()
        append(
            log,
            {"kind": "manual", "day": day.isoformat(), "minutes": args.duration, "note": args.note},
        )
        print(f"Added {args.duration} minutes on {day:%a %d %b %Y}.")

        return 0

    if args.command in ("start", "stop", "status"):
        note: str = args.note if args.command == "start" else ""
        at_text: str | None = getattr(args, "at", None)

        return timer_command(args.command, note, at_text, log, datetime.now(UTC))

    if args.gap <= 0 or not 0 <= args.pad <= args.gap:
        print("--gap must be above 0, and --pad between 0 and --gap.", file=sys.stderr)

        return 2

    if args.rate <= 0 or not 0 <= args.lead_min <= args.lead_cap:
        print(
            "--rate must be above 0, and --lead-min between 0 and --lead-cap.",
            file=sys.stderr,
        )

        return 2

    lead_in = LeadIn(
        args.rate, timedelta(minutes=args.lead_min), timedelta(minutes=args.lead_cap)
    )
    if args.timer_cap <= 0:
        print("--timer-cap must be above 0.", file=sys.stderr)

        return 2

    entries = read_log(log)
    spans = timer_spans(entries.timers, timedelta(hours=args.timer_cap), datetime.now(UTC))
    days = daily_totals(
        entries.prompts,
        entries.manual,
        spans,
        timedelta(minutes=args.gap),
        timedelta(minutes=args.pad),
        lead_in,
    )
    if args.since is not None:
        days = {day: totals for day, totals in days.items() if day >= args.since}

    print(render(days))

    for span in spans:
        started = f"{span.start.astimezone():%a %d %b %H:%M}"
        if span.capped:
            print(
                f"Note: the timer started {started} ran over {args.timer_cap:g} h, "
                f"so only {args.timer_cap:g} h is counted."
            )
        elif span.running:
            print(f"Note: a timer is running, started {started}.")

    if entries.skipped:
        print(f"Skipped {entries.skipped} unreadable lines in {log}.", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
