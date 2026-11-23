import assert from "node:assert/strict";
import { test } from "node:test";
import { MAX_TEXT_LENGTH, parseMessage } from "../src/limits.ts";

const line = (text: unknown): string => JSON.stringify({ text });

test("a message exactly at the cap passes", () => {
    const result = parseMessage(line("a".repeat(MAX_TEXT_LENGTH)));

    assert.equal(result.ok, true);
});

test("a message one character over the cap is refused", () => {
    const result = parseMessage(line("a".repeat(MAX_TEXT_LENGTH + 1)));

    assert.equal(result.ok, false);
});

test("empty or blank text is refused", () => {
    assert.equal(parseMessage(line("")).ok, false);
    assert.equal(parseMessage(line("   ")).ok, false);
});

test("a line that is not JSON is refused", () => {
    assert.deepEqual(parseMessage("hello"), { ok: false, reason: "not valid JSON" });
});

test("JSON with no text, or text that is not a string, is refused", () => {
    assert.equal(parseMessage("{}").ok, false);
    assert.equal(parseMessage("null").ok, false);
    assert.equal(parseMessage(line(42)).ok, false);
});

test("good text comes back unchanged", () => {
    assert.deepEqual(parseMessage(line("What is in this folder?")), {
        ok: true,
        text: "What is in this folder?",
    });
});
