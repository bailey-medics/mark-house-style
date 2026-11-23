import assert from "node:assert/strict";
import { test } from "node:test";
import { createWrongTokenAlarm, WRONG_TOKEN_ALARM_COUNT, WRONG_TOKEN_WINDOW_MS } from "../src/alarm.ts";

const START = new Date("2026-11-23T12:00:00.000Z").getTime();

function at(offsetMs: number): Date {
    return new Date(START + offsetMs);
}

test("it stays quiet until the count is reached, then raises the alarm once", () => {
    const alarm = createWrongTokenAlarm();

    for (let count = 1; count < WRONG_TOKEN_ALARM_COUNT; count += 1) {
        assert.equal(alarm.wrong(at(count)), false);
    }

    assert.equal(alarm.wrong(at(WRONG_TOKEN_ALARM_COUNT)), true);
});

test("a flood raises the alarm once in each window, not once for each wrong token", () => {
    const alarm = createWrongTokenAlarm(3, 1000);
    let raised = 0;

    for (let time = 0; time < 1000; time += 1) {
        raised += alarm.wrong(at(time)) ? 1 : 0;
    }
    assert.equal(raised, 1);

    for (let time = 1000; time < 3000; time += 1) {
        raised += alarm.wrong(at(time)) ? 1 : 0;
    }
    assert.equal(raised, 3);
});

test("wrong tokens older than the window do not count", () => {
    const alarm = createWrongTokenAlarm(3, 1000);

    // The ones at 0 and 100 have each aged out by the time a third arrives.
    alarm.wrong(at(0));
    alarm.wrong(at(100));
    assert.equal(alarm.wrong(at(1000)), false);
    assert.equal(alarm.wrong(at(1100)), false);

    // Three inside one window: 1000, 1100 and 1150.
    assert.equal(alarm.wrong(at(1150)), true);
});

test("the alarm can be raised again after a quiet window", () => {
    const alarm = createWrongTokenAlarm(2, 1000);

    alarm.wrong(at(0));
    assert.equal(alarm.wrong(at(1)), true);
    assert.equal(alarm.wrong(at(2)), false);

    alarm.wrong(at(10 * WRONG_TOKEN_WINDOW_MS));
    assert.equal(alarm.wrong(at(10 * WRONG_TOKEN_WINDOW_MS + 1)), true);
});

test("an alarm with no count or no window cannot be made", () => {
    assert.throws(() => createWrongTokenAlarm(0, 1000));
    assert.throws(() => createWrongTokenAlarm(1.5, 1000));
    assert.throws(() => createWrongTokenAlarm(3, 0));
});
