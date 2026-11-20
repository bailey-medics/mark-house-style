"""Tests for the private hours log.

Run with: python3 -m unittest discover -s scripts/hours
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Literal
from unittest import mock

import hours

GAP = timedelta(minutes=20)
PAD = timedelta(minutes=5)
NO_LEAD = hours.LeadIn(40, timedelta(0), timedelta(0))
LEAD = hours.LeadIn(40, timedelta(minutes=3), timedelta(minutes=30))
CAP = timedelta(hours=4)


def at(hour: int, minute: int, day: int = 16, second: int = 0) -> datetime:
    return datetime(2026, 11, day, hour, minute, second, tzinfo=UTC)


def sent(when: datetime, chars: int | None = None, session: str = "a") -> hours.Prompt:
    return hours.Prompt(when, session, "turva", chars)


def minutes(count: float) -> timedelta:
    return timedelta(minutes=count)


def start(when: datetime, note: str = "") -> hours.TimerEvent:
    return hours.TimerEvent(when, "start", note)


def stop(when: datetime) -> hours.TimerEvent:
    return hours.TimerEvent(when, "stop")


def span(begin: datetime, end: datetime) -> hours.Span:
    return hours.Span(begin, end, "")


def git(cwd: Path, *args: str) -> None:
    identity = ["-c", "user.name=test", "-c", "user.email=test@example.com"]
    subprocess.run(
        ["git", *identity, "-c", "commit.gpgsign=false", *args],
        cwd=cwd,
        check=True,
        capture_output=True,
    )


class ParseDurationTests(unittest.TestCase):
    def test_reads_minutes_hours_and_both(self) -> None:
        self.assertEqual(hours.parse_duration("45m"), 45)
        self.assertEqual(hours.parse_duration("2h"), 120)
        self.assertEqual(hours.parse_duration("1.5h"), 90)
        self.assertEqual(hours.parse_duration("1h30m"), 90)

    def test_refuses_what_is_not_a_duration(self) -> None:
        for text in ("", "soon", "45", "0m", "m"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                hours.parse_duration(text)


class LeadInTests(unittest.TestCase):
    def test_a_short_prompt_earns_the_minimum(self) -> None:
        self.assertEqual(LEAD.for_prompt(6), minutes(3))
        self.assertEqual(LEAD.for_prompt(0), minutes(3))

    def test_a_longer_prompt_earns_its_length_over_the_rate(self) -> None:
        self.assertEqual(LEAD.for_prompt(400), minutes(10))

    def test_a_very_long_prompt_stops_at_the_cap(self) -> None:
        self.assertEqual(LEAD.for_prompt(50_000), minutes(30))

    def test_a_prompt_of_unknown_length_earns_the_minimum(self) -> None:
        self.assertEqual(LEAD.for_prompt(None), minutes(3))


class FindBlocksTests(unittest.TestCase):
    def test_no_prompts_means_no_blocks(self) -> None:
        self.assertEqual(hours.find_blocks([], GAP, PAD, LEAD), [])

    def test_close_prompts_join_into_one_padded_block(self) -> None:
        prompts = [sent(at(9, 0)), sent(at(9, 25)), sent(at(9, 10))]

        blocks = hours.find_blocks(prompts, GAP, PAD, NO_LEAD)

        self.assertEqual(blocks, [hours.Block(at(9, 0), at(9, 30))])
        self.assertAlmostEqual(blocks[0].hours, 0.5)

    def test_a_silence_longer_than_the_gap_starts_a_new_block(self) -> None:
        blocks = hours.find_blocks([sent(at(9, 0)), sent(at(9, 21))], GAP, PAD, NO_LEAD)

        self.assertEqual(
            blocks, [hours.Block(at(9, 0), at(9, 5)), hours.Block(at(9, 21), at(9, 26))]
        )

    def test_a_silence_of_exactly_the_gap_stays_in_the_block(self) -> None:
        blocks = hours.find_blocks([sent(at(9, 0)), sent(at(9, 20))], GAP, PAD, NO_LEAD)

        self.assertEqual(blocks, [hours.Block(at(9, 0), at(9, 25))])

    def test_each_block_gets_a_lead_in_from_its_first_prompt_only(self) -> None:
        prompts = [
            sent(at(9, 0), chars=400),
            sent(at(9, 10), chars=4000),
            sent(at(14, 0), chars=20),
        ]

        blocks = hours.find_blocks(prompts, GAP, PAD, LEAD)

        self.assertEqual(
            blocks,
            [
                hours.Block(at(9, 0), at(9, 15), minutes(10)),
                hours.Block(at(14, 0), at(14, 5), minutes(3)),
            ],
        )
        self.assertAlmostEqual(blocks[0].hours, 25 / 60)
        self.assertAlmostEqual(blocks[1].hours, 8 / 60)

    def test_a_lead_in_never_reaches_back_into_the_block_before(self) -> None:
        prompts = [sent(at(9, 0)), sent(at(9, 21), chars=50_000)]

        blocks = hours.find_blocks(prompts, GAP, PAD, LEAD)

        self.assertEqual(blocks[1], hours.Block(at(9, 21), at(9, 26), minutes(16)))
        self.assertAlmostEqual(sum(block.hours for block in blocks), 29 / 60)


class DailyTotalsTests(unittest.TestCase):
    def test_blocks_and_manual_time_add_up_per_day(self) -> None:
        prompts = [
            sent(at(9, 0), session="a"),
            sent(at(9, 15), session="b"),
            sent(at(14, 0), session="a"),
            sent(at(10, 0, day=17), session="c"),
        ]
        manual = [hours.Manual(date(2026, 11, 16), 45, "walk")]

        days = hours.daily_totals(prompts, manual, [], GAP, PAD, NO_LEAD, UTC)

        monday = days[date(2026, 11, 16)]
        self.assertEqual(monday.blocks, 2)
        self.assertAlmostEqual(monday.worked_hours, 25 / 60)
        self.assertAlmostEqual(monday.manual_hours, 0.75)
        self.assertAlmostEqual(monday.hours, 25 / 60 + 0.75)
        self.assertEqual(days[date(2026, 11, 17)].blocks, 1)

    def test_the_lead_in_is_part_of_the_day(self) -> None:
        days = hours.daily_totals([sent(at(9, 0), chars=400)], [], [], GAP, PAD, LEAD, UTC)

        self.assertAlmostEqual(days[date(2026, 11, 16)].hours, 15 / 60)

    def test_a_block_counts_towards_the_day_of_its_first_prompt(self) -> None:
        prompts = [sent(at(23, 55)), sent(at(0, 5, day=17))]
        early = [sent(at(0, 1, day=17), chars=400)]

        self.assertEqual(
            list(hours.daily_totals(prompts, [], [], GAP, PAD, LEAD, UTC)), [date(2026, 11, 16)]
        )
        self.assertEqual(
            list(hours.daily_totals(early, [], [], GAP, PAD, LEAD, UTC)), [date(2026, 11, 17)]
        )

    def test_manual_time_alone_makes_a_day(self) -> None:
        manual = [hours.Manual(date(2026, 11, 18), 30, "")]

        days = hours.daily_totals([], manual, [], GAP, PAD, LEAD, UTC)

        self.assertEqual(days[date(2026, 11, 18)].blocks, 0)
        self.assertAlmostEqual(days[date(2026, 11, 18)].hours, 0.5)


class RenderTests(unittest.TestCase):
    def test_empty_log_says_so(self) -> None:
        self.assertEqual(hours.render({}), "No hours logged yet.")

    def test_groups_days_by_week_with_totals(self) -> None:
        days = {
            date(2026, 11, 15): hours.Day(worked_hours=1.0, blocks=1),
            date(2026, 11, 16): hours.Day(worked_hours=2.0, blocks=3, manual_hours=0.5),
            date(2026, 11, 17): hours.Day(worked_hours=1.5, blocks=1, timers=1, timer_hours=1.0),
        }

        text = hours.render(days)

        self.assertIn("Week of 09 Nov 2026: 1.0 h", text)
        self.assertIn("Week of 16 Nov 2026: 4.0 h", text)
        self.assertIn("Sun 15 Nov    1.0 h   1 block", text)
        self.assertIn("Mon 16 Nov    2.5 h   3 blocks, 0.5 h added by hand", text)
        self.assertIn("Tue 17 Nov    1.5 h   1 block, 1.0 h on the timer", text)
        self.assertTrue(text.endswith("Total: 5.0 h"))


class ReadLogTests(unittest.TestCase):
    def setUp(self) -> None:
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.log = Path(folder.name) / "log.jsonl"

    def write(self, *lines: str) -> None:
        with self.log.open("a", encoding="utf-8") as handle:
            handle.write("".join(line + "\n" for line in lines))

    def test_reads_both_kinds_and_counts_unreadable_lines(self) -> None:
        hours.append(self.log, hours.prompt_record(sent(at(9, 0), chars=120), "hook"))
        hours.append(
            self.log, {"kind": "manual", "day": "2026-11-16", "minutes": 45, "note": "walk"}
        )
        self.write(
            "not json",
            "",
            '{"kind": "prompt", "ts": "2026-11-16T09:00:00"}',
            '{"kind": "mystery"}',
        )

        hours.append(self.log, hours.timer_record(start(at(10, 0), "review")))
        self.write('{"kind": "timer", "action": "pause", "ts": "2026-11-16T10:00:00+00:00"}')

        entries = hours.read_log(self.log)

        self.assertEqual(entries.prompts, [sent(at(9, 0), chars=120)])
        self.assertEqual(entries.manual, [hours.Manual(date(2026, 11, 16), 45, "walk")])
        self.assertEqual(entries.timers, [start(at(10, 0), "review")])
        self.assertEqual(entries.skipped, 4)

    def test_a_prompt_without_a_usable_length_is_kept_with_none(self) -> None:
        base = '{"kind": "prompt", "ts": "2026-11-16T09:00:00+00:00", "session": "a", "worktree": "turva"'
        self.write(base + "}", base + ', "chars": "long"}', base + ', "chars": -4}', base + ', "chars": true}')

        entries = hours.read_log(self.log)

        self.assertEqual(entries.prompts, [sent(at(9, 0))] * 4)
        self.assertEqual(entries.skipped, 0)

    def test_a_missing_log_is_empty(self) -> None:
        self.assertEqual(hours.read_log(Path("/nonexistent/log.jsonl")), hours.Entries())


class RecordPromptTests(unittest.TestCase):
    def setUp(self) -> None:
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        root = Path(folder.name).resolve()

        self.main = root / "turva"
        self.linked = root / "turva-2"
        self.elsewhere = root / "other"
        self.log = root / "out" / "log.jsonl"

        self.main.mkdir()
        self.elsewhere.mkdir()
        git(self.main, "init", "-q")
        git(self.main, "commit", "-q", "--allow-empty", "-m", "start")
        git(self.main, "worktree", "add", "-q", str(self.linked))

    def send(self, cwd: Path) -> bool:
        payload = json.dumps({"cwd": str(cwd), "session_id": "s1", "prompt": "secret words"})

        return hours.record_prompt(payload, self.log, self.main, at(9, 0))

    def test_logs_a_prompt_from_the_main_worktree_with_its_length(self) -> None:
        self.assertTrue(self.send(self.main))

        self.assertEqual(hours.read_log(self.log).prompts, [hours.Prompt(at(9, 0), "s1", "turva", 12)])

    def test_logs_a_prompt_from_a_linked_worktree_and_its_subfolders(self) -> None:
        nested = self.linked / "deep"
        nested.mkdir()

        self.assertTrue(self.send(nested))

        self.assertEqual(hours.read_log(self.log).prompts[0].worktree, "turva-2")

    def test_never_stores_the_prompt_text(self) -> None:
        self.send(self.main)

        self.assertNotIn("secret", self.log.read_text(encoding="utf-8"))

    def test_logs_a_prompt_whose_text_is_missing_without_a_length(self) -> None:
        payload = json.dumps({"cwd": str(self.main), "session_id": "s1"})

        self.assertTrue(hours.record_prompt(payload, self.log, self.main, at(9, 0)))

        self.assertIsNone(hours.read_log(self.log).prompts[0].chars)
        self.assertNotIn("chars", self.log.read_text(encoding="utf-8"))

    def test_ignores_a_folder_outside_the_repository(self) -> None:
        self.assertFalse(self.send(self.elsewhere))
        self.assertFalse(self.log.exists())

    def test_ignores_another_repository(self) -> None:
        git(self.elsewhere, "init", "-q")

        self.assertFalse(self.send(self.elsewhere))

    def test_ignores_input_it_cannot_read(self) -> None:
        for payload in ("", "not json", "[]", '{"cwd": 3, "session_id": "s"}', '{"cwd": "/tmp"}'):
            with self.subTest(payload=payload):
                self.assertFalse(hours.record_prompt(payload, self.log, self.main, at(9, 0)))

        self.assertFalse(self.log.exists())


class BackfillTests(unittest.TestCase):
    def setUp(self) -> None:
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        root = Path(folder.name)

        self.main = Path("/home/someone/github/turva")
        self.projects = root / "projects"
        self.log = root / "log.jsonl"

        def line(**fields: object) -> str:
            base: dict[str, object] = {
                "type": "user",
                "sessionId": "s1",
                "cwd": "/home/someone/github/turva-2",
                "origin": {"kind": "human"},
                "message": {"role": "user", "content": "ten chars!"},
            }

            return json.dumps(base | fields)

        blocks = {"content": [{"type": "text", "text": "four"}, {"type": "image"}, {"type": "text", "text": "plus3"}]}
        ours = self.projects / "-home-someone-github-turva-2"
        ours.mkdir(parents=True)
        (ours / "s1.jsonl").write_text(
            "\n".join(
                [
                    line(timestamp="2026-11-16T09:00:00.000Z"),
                    line(timestamp="2026-11-16T09:10:00.000Z", message=blocks),
                    line(timestamp="2026-11-16T09:11:00.000Z", origin=None),
                    line(timestamp="2026-11-16T09:12:00.000Z", isSidechain=True),
                    line(timestamp="2026-11-16T09:13:00.000Z", type="assistant"),
                    line(timestamp="never"),
                    "not json",
                ]
            ),
            encoding="utf-8",
        )

        theirs = self.projects / "-home-someone-github-other"
        theirs.mkdir()
        (theirs / "s2.jsonl").write_text(line(timestamp="2026-11-16T10:00:00.000Z"), encoding="utf-8")

    def test_copies_only_prompts_a_person_sent_in_this_repository(self) -> None:
        self.assertEqual(hours.backfill(self.projects, self.main, self.log), 2)

        entries = hours.read_log(self.log)
        self.assertEqual(
            entries.prompts,
            [
                hours.Prompt(at(9, 0), "s1", "turva-2", 10),
                hours.Prompt(at(9, 10), "s1", "turva-2", 9),
            ],
        )
        self.assertEqual(entries.skipped, 0)

    def test_running_it_twice_adds_nothing_new(self) -> None:
        hours.backfill(self.projects, self.main, self.log)

        self.assertEqual(hours.backfill(self.projects, self.main, self.log), 0)
        self.assertEqual(len(hours.read_log(self.log).prompts), 2)

    def test_skips_a_prompt_the_hook_logged_a_moment_earlier(self) -> None:
        logged = hours.Prompt(at(9, 0, second=2), "s1", "turva-2", 10)
        other_session = hours.Prompt(at(9, 10, second=1), "s9", "turva", 10)
        hours.append(self.log, hours.prompt_record(logged, "hook"))
        hours.append(self.log, hours.prompt_record(other_session, "hook"))

        self.assertEqual(hours.backfill(self.projects, self.main, self.log), 1)

    def test_a_prompt_with_no_readable_text_has_no_length(self) -> None:
        self.assertIsNone(hours.prompt_length(None))
        self.assertIsNone(hours.prompt_length({"content": 7}))
        self.assertEqual(hours.prompt_length({"content": []}), 0)


class ParseAtTests(unittest.TestCase):
    def test_a_clock_time_means_today_on_this_machine(self) -> None:
        now = at(15, 0)

        moment = hours.parse_at("09:30", now)

        self.assertEqual(moment.astimezone().date(), now.astimezone().date())
        self.assertEqual((moment.astimezone().hour, moment.astimezone().minute), (9, 30))

    def test_a_full_date_and_time_is_read_as_given(self) -> None:
        self.assertEqual(hours.parse_at("2026-11-16T09:30+00:00", at(15, 0)), at(9, 30))

    def test_refuses_what_is_not_a_time(self) -> None:
        with self.assertRaises(ValueError):
            hours.parse_at("lunch", at(15, 0))


class TimerSpansTests(unittest.TestCase):
    def test_pairs_each_start_with_its_stop(self) -> None:
        events = [stop(at(11, 0)), start(at(10, 0), "review")]

        self.assertEqual(
            hours.timer_spans(events, CAP, at(12, 0)),
            [hours.Span(at(10, 0), at(11, 0), "review")],
        )

    def test_a_start_with_no_stop_runs_until_now(self) -> None:
        spans = hours.timer_spans([start(at(10, 0))], CAP, at(10, 30))

        self.assertEqual(spans, [hours.Span(at(10, 0), at(10, 30), "", running=True)])

    def test_a_second_start_stops_the_first(self) -> None:
        events = [start(at(10, 0), "one"), start(at(10, 20), "two"), stop(at(11, 0))]

        spans = hours.timer_spans(events, CAP, at(12, 0))

        self.assertEqual(
            spans,
            [hours.Span(at(10, 0), at(10, 20), "one"), hours.Span(at(10, 20), at(11, 0), "two")],
        )

    def test_a_stop_and_start_at_the_same_moment_hand_over_cleanly(self) -> None:
        events = [start(at(10, 0)), start(at(11, 0)), stop(at(11, 0))]

        spans = hours.timer_spans(events, CAP, at(11, 30))

        self.assertEqual([s.end for s in spans], [at(11, 0), at(11, 30)])
        self.assertTrue(spans[1].running)

    def test_a_stop_with_no_start_is_ignored(self) -> None:
        self.assertEqual(hours.timer_spans([stop(at(10, 0))], CAP, at(12, 0)), [])

    def test_a_forgotten_timer_is_cut_off_at_the_cap(self) -> None:
        spans = hours.timer_spans([start(at(9, 0)), stop(at(23, 0))], CAP, at(23, 30))

        self.assertEqual(spans, [hours.Span(at(9, 0), at(13, 0), "", capped=True)])

    def test_running_timer_finds_the_open_start(self) -> None:
        self.assertEqual(hours.running_timer([start(at(9, 0), "x")]), start(at(9, 0), "x"))
        self.assertIsNone(hours.running_timer([start(at(9, 0)), stop(at(10, 0))]))
        self.assertIsNone(hours.running_timer([]))


class TimerTotalsTests(unittest.TestCase):
    def test_timer_time_with_no_prompts_counts_in_full(self) -> None:
        days = hours.daily_totals([], [], [span(at(10, 0), at(11, 30))], GAP, PAD, NO_LEAD, UTC)

        day = days[date(2026, 11, 16)]
        self.assertAlmostEqual(day.hours, 1.5)
        self.assertEqual((day.blocks, day.timers), (0, 1))
        self.assertAlmostEqual(day.timer_hours, 1.5)

    def test_time_covered_by_a_timer_and_prompts_counts_once(self) -> None:
        prompts = [sent(at(10, 30)), sent(at(10, 40))]

        days = hours.daily_totals(prompts, [], [span(at(10, 0), at(11, 0))], GAP, PAD, NO_LEAD, UTC)

        self.assertAlmostEqual(days[date(2026, 11, 16)].hours, 1.0)

    def test_a_block_running_past_the_timer_extends_it(self) -> None:
        prompts = [sent(at(10, 50)), sent(at(11, 10))]

        days = hours.daily_totals(prompts, [], [span(at(10, 0), at(11, 0))], GAP, PAD, NO_LEAD, UTC)

        self.assertAlmostEqual(days[date(2026, 11, 16)].hours, 75 / 60)

    def test_separate_timer_and_block_both_count(self) -> None:
        days = hours.daily_totals(
            [sent(at(14, 0))], [], [span(at(10, 0), at(11, 0))], GAP, PAD, NO_LEAD, UTC
        )

        self.assertAlmostEqual(days[date(2026, 11, 16)].hours, 65 / 60)

    def test_a_timer_counts_towards_the_day_it_started(self) -> None:
        days = hours.daily_totals(
            [], [], [span(at(23, 30), at(0, 30, day=17))], GAP, PAD, NO_LEAD, UTC
        )

        self.assertEqual(list(days), [date(2026, 11, 16)])
        self.assertAlmostEqual(days[date(2026, 11, 16)].hours, 1.0)


class TimerCommandTests(unittest.TestCase):
    def setUp(self) -> None:
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.log = Path(folder.name) / "log.jsonl"

    def run_timer(
        self, action: Literal["start", "stop", "status"], now: datetime,
        note: str = "", at_text: str | None = None,
    ) -> tuple[int, str]:
        out = io.StringIO()
        with redirect_stdout(out), redirect_stderr(out):
            code = hours.timer_command(action, note, at_text, self.log, now)

        return code, out.getvalue()

    def test_start_then_stop_records_one_run(self) -> None:
        self.assertEqual(self.run_timer("start", at(10, 0), "review")[0], 0)
        code, text = self.run_timer("stop", at(10, 45))

        self.assertEqual(code, 0)
        self.assertIn("45 m", text)
        self.assertEqual(
            hours.timer_spans(hours.read_log(self.log).timers, CAP, at(12, 0)),
            [hours.Span(at(10, 0), at(10, 45), "review")],
        )

    def test_status_reports_a_running_timer_and_an_idle_one(self) -> None:
        self.assertIn("No timer", self.run_timer("status", at(10, 0))[1])

        self.run_timer("start", at(10, 0), "review")

        self.assertIn("1 h 30 m (review)", self.run_timer("status", at(11, 30))[1])
        self.assertIn("only 4 h will count", self.run_timer("status", at(15, 0))[1])

    def test_stop_with_nothing_running_fails_and_writes_nothing(self) -> None:
        self.assertEqual(self.run_timer("stop", at(10, 0))[0], 1)
        self.assertFalse(self.log.exists())

    def test_starting_again_stops_the_running_timer_first(self) -> None:
        self.run_timer("start", at(10, 0), "one")
        code, text = self.run_timer("start", at(10, 30), "two")

        self.assertEqual(code, 0)
        self.assertIn("Stopped the timer that was running (one) after 30 m", text)
        self.assertEqual(hours.running_timer(hours.read_log(self.log).timers), start(at(10, 30), "two"))

    def test_at_sets_the_real_time(self) -> None:
        self.run_timer("start", at(10, 0), at_text="2026-11-16T09:15+00:00")
        self.run_timer("stop", at(11, 0), at_text="2026-11-16T10:40+00:00")

        self.assertEqual(
            [event.at for event in hours.read_log(self.log).timers], [at(9, 15), at(10, 40)]
        )

    def test_refuses_times_that_would_tangle_the_log(self) -> None:
        self.run_timer("start", at(10, 0))

        future = self.run_timer("stop", at(10, 30), at_text="2026-11-16T11:00+00:00")
        before_start = self.run_timer("stop", at(10, 30), at_text="2026-11-16T09:00+00:00")
        bad = self.run_timer("stop", at(10, 30), at_text="lunch")
        self.run_timer("stop", at(10, 30))
        before_last = self.run_timer("start", at(11, 0), at_text="2026-11-16T10:15+00:00")

        self.assertEqual([future[0], before_start[0], bad[0], before_last[0]], [2, 2, 2, 2])
        self.assertEqual(len(hours.read_log(self.log).timers), 2)


class RepositoryTests(unittest.TestCase):
    """Which repository is tracked, and where its log is kept."""

    def setUp(self) -> None:
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        root = Path(folder.name).resolve()

        self.main = root / "turva"
        self.linked = root / "turva-2"
        self.elsewhere = root / "other"
        self.data = root / "data"

        self.main.mkdir()
        self.elsewhere.mkdir()
        git(self.main, "init", "-q")
        git(self.main, "commit", "-q", "--allow-empty", "-m", "start")
        git(self.main, "worktree", "add", "-q", str(self.linked))

        patches = [
            mock.patch.object(hours, "DATA", self.data),
            mock.patch.dict("os.environ", {}, clear=False),
        ]
        for patch in patches:
            patch.start()
            self.addCleanup(patch.stop)
        os.environ.pop(hours.REPO_VARIABLE, None)

    def run_main(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()

        with redirect_stdout(out), redirect_stderr(err):
            code = hours.main(list(argv))

        return code, out.getvalue(), err.getvalue()

    def test_every_worktree_and_subfolder_finds_the_main_worktree(self) -> None:
        nested = self.linked / "deep"
        nested.mkdir()

        for path in (self.main, self.linked, nested):
            with self.subTest(path=path):
                self.assertEqual(hours.main_worktree(path), self.main)

    def test_a_folder_outside_any_repository_has_no_main_worktree(self) -> None:
        self.assertIsNone(hours.main_worktree(self.elsewhere))

    def test_the_log_is_named_after_the_repository_and_kept_outside_it(self) -> None:
        log = hours.log_for(self.main, self.data)

        self.assertEqual(log, self.data / "turva.jsonl")
        self.assertFalse(log.is_relative_to(self.main))

    def test_a_linked_worktree_writes_to_the_main_worktrees_log(self) -> None:
        code, _, _ = self.run_main("--repo", str(self.linked), "add", "45m", "walk")

        self.assertEqual(code, 0)
        self.assertEqual(hours.read_log(self.data / "turva.jsonl").manual[0].minutes, 45)

    def test_the_repository_can_come_from_the_environment(self) -> None:
        with mock.patch.dict("os.environ", {hours.REPO_VARIABLE: str(self.main)}):
            code, _, _ = self.run_main("add", "1h")

        self.assertEqual(code, 0)
        self.assertTrue((self.data / "turva.jsonl").exists())

    def test_refuses_to_run_without_a_repository(self) -> None:
        code, _, err = self.run_main("report")

        self.assertEqual(code, 2)
        self.assertIn("--repo", err)

    def test_refuses_a_folder_that_is_not_a_repository(self) -> None:
        code, _, err = self.run_main("--repo", str(self.elsewhere), "report")

        self.assertEqual(code, 2)
        self.assertIn("Not a git repository", err)

    def test_the_hook_stays_silent_and_writes_nothing_without_a_repository(self) -> None:
        payload = json.dumps({"cwd": str(self.main), "session_id": "s1", "prompt": "hi"})

        with mock.patch("sys.stdin", io.StringIO(payload)):
            code, out, err = self.run_main("--repo", str(self.elsewhere), "hook")

        self.assertEqual((code, out, err), (0, "", ""))
        self.assertFalse(self.data.exists())

    def test_the_hook_logs_a_prompt_for_the_named_repository(self) -> None:
        payload = json.dumps({"cwd": str(self.linked), "session_id": "s1", "prompt": "hi"})

        with mock.patch("sys.stdin", io.StringIO(payload)):
            code, _, _ = self.run_main("--repo", str(self.main), "hook")

        self.assertEqual(code, 0)
        self.assertEqual(hours.read_log(self.data / "turva.jsonl").prompts[0].worktree, "turva-2")


if __name__ == "__main__":
    unittest.main()
