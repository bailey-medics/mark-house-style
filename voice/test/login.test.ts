import assert from "node:assert/strict";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, test } from "node:test";
import {
    checkToken,
    headerValue,
    isExpired,
    issueLogin,
    loadLogin,
    loginFilePath,
    LoginError,
    MAX_TOKEN_DAYS,
    saveLogin,
} from "../src/login.ts";

const NOW = new Date("2026-11-23T12:00:00.000Z");
const DAY_MS = 24 * 60 * 60 * 1000;

let folder: string | undefined;

afterEach(() => {
    if (folder !== undefined) {
        rmSync(folder, { recursive: true, force: true });
        folder = undefined;
    }
});

function scratch(): string {
    folder = mkdtempSync(join(tmpdir(), "voice-login-"));

    return folder;
}

test("a token is 43 url-safe characters, and no two are alike", () => {
    const first = issueLogin(7, NOW);
    const second = issueLogin(7, NOW);

    assert.match(first.token, /^[A-Za-z0-9_-]{43}$/);
    assert.notEqual(first.token, second.token);
    assert.notEqual(first.record.tokenHash, second.record.tokenHash);
});

test("the record holds a hash and the dates, and never the token", () => {
    const { token, record } = issueLogin(7, NOW);

    assert.match(record.tokenHash, /^[0-9a-f]{64}$/);
    assert.equal(record.createdAt, NOW.toISOString());
    assert.equal(Date.parse(record.expiresAt) - NOW.getTime(), 7 * DAY_MS);
    assert.equal(JSON.stringify(record).includes(token), false);
});

test("a token's life must be a whole number of days within the limit", () => {
    for (const days of [0, -1, 1.5, MAX_TOKEN_DAYS + 1, Number.NaN]) {
        assert.throws(() => issueLogin(days, NOW), LoginError);
    }

    assert.doesNotThrow(() => issueLogin(MAX_TOKEN_DAYS, NOW));
});

test("the right token passes", () => {
    const { token, record } = issueLogin(7, NOW);

    assert.deepEqual(checkToken(record, headerValue(token), NOW), { ok: true });
});

test("no header is reported as missing", () => {
    const { record } = issueLogin(7, NOW);

    assert.deepEqual(checkToken(record, undefined, NOW), { ok: false, reason: "missing" });
});

test("another token is wrong", () => {
    const { record } = issueLogin(7, NOW);
    const other = issueLogin(7, NOW);

    assert.deepEqual(checkToken(record, headerValue(other.token), NOW), { ok: false, reason: "wrong" });
});

// This is checkToken on its own. Over HTTP, Node drops the spaces around a
// header's value before the bridge sees it; test/bridge.test.ts covers
// what a real request does.
test("a header of the wrong shape is wrong, even with the right token inside", () => {
    const { token, record } = issueLogin(7, NOW);
    const shapes: (string | string[])[] = [
        "",
        token,
        `bearer ${token}`,
        `Bearer  ${token}`,
        `Bearer ${token} `,
        ` Bearer ${token}`,
        `Bearer ${token}x`,
        `Bearer ${token.slice(1)}`,
        `Basic ${token}`,
        `Bearer ${token}\n`,
        [headerValue(token)],
    ];

    for (const shape of shapes) {
        assert.deepEqual(checkToken(record, shape, NOW), { ok: false, reason: "wrong" }, JSON.stringify(shape));
    }
});

test("the right token stops working at its end time, and a wrong one still reads as wrong", () => {
    const { token, record } = issueLogin(7, NOW);
    const other = issueLogin(7, NOW);
    const justBefore = new Date(NOW.getTime() + 7 * DAY_MS - 1);
    const atTheEnd = new Date(NOW.getTime() + 7 * DAY_MS);

    assert.deepEqual(checkToken(record, headerValue(token), justBefore), { ok: true });
    assert.deepEqual(checkToken(record, headerValue(token), atTheEnd), { ok: false, reason: "expired" });
    assert.deepEqual(checkToken(record, headerValue(other.token), atTheEnd), { ok: false, reason: "wrong" });
    assert.equal(isExpired(record, justBefore), false);
    assert.equal(isExpired(record, atTheEnd), true);
});

test("a saved login reads back the same, in a file and folder closed to other users", () => {
    const path = join(scratch(), "state", "voice-bridge", "login.json");
    const { token, record } = issueLogin(7, NOW);

    saveLogin(path, record);

    assert.deepEqual(loadLogin(path), record);
    assert.equal(statSync(path).mode & 0o777, 0o600);
    assert.equal(statSync(join(path, "..")).mode & 0o777, 0o700);
    assert.equal(readFileSync(path, "utf8").includes(token), false);
});

test("saving again replaces the login, so the old token stops", () => {
    const path = join(scratch(), "voice-bridge", "login.json");
    const first = issueLogin(7, NOW);
    const second = issueLogin(7, NOW);

    saveLogin(path, first.record);
    saveLogin(path, second.record);

    const current = loadLogin(path);
    assert.deepEqual(checkToken(current, headerValue(first.token), NOW), { ok: false, reason: "wrong" });
    assert.deepEqual(checkToken(current, headerValue(second.token), NOW), { ok: true });
});

test("a missing login is refused", () => {
    assert.throws(() => loadLogin(join(scratch(), "login.json")), LoginError);
});

test("a login that other users could read is refused", () => {
    const path = join(scratch(), "login.json");
    saveLogin(path, issueLogin(7, NOW).record);

    for (const mode of [0o644, 0o640, 0o604, 0o660]) {
        chmodSync(path, mode);
        assert.throws(() => loadLogin(path), /other users/, mode.toString(8));
    }
});

test("a login in a folder that other users could open is refused", () => {
    const path = join(scratch(), "voice-bridge", "login.json");
    saveLogin(path, issueLogin(7, NOW).record);

    for (const mode of [0o755, 0o750, 0o701, 0o770]) {
        chmodSync(join(path, ".."), mode);
        assert.throws(() => loadLogin(path), /folder is open/, mode.toString(8));
    }

    chmodSync(join(path, ".."), 0o700);
    assert.doesNotThrow(() => loadLogin(path));
});

test("a login in a folder reached through a link is refused", () => {
    const base = scratch();
    const real = join(base, "real");
    const link = join(base, "linked");

    saveLogin(join(real, "login.json"), issueLogin(7, NOW).record);
    symlinkSync(real, link);

    assert.throws(() => loadLogin(join(link, "login.json")), /folder is open/);
});

test("a link, or a folder, in place of the login is refused", () => {
    const base = scratch();
    const real = join(base, "real.json");
    const link = join(base, "login.json");
    const dir = join(base, "folder.json");

    saveLogin(real, issueLogin(7, NOW).record);
    symlinkSync(real, link);
    mkdirSync(dir);

    assert.throws(() => loadLogin(link), /plain file/);
    assert.throws(() => loadLogin(dir), /plain file/);
});

test("a login file that is not a whole, valid record is refused", () => {
    const path = join(scratch(), "login.json");
    const good = issueLogin(7, NOW).record;
    const broken: string[] = [
        "",
        "not json",
        "null",
        "[]",
        JSON.stringify({ ...good, version: 2 }),
        JSON.stringify({ ...good, tokenHash: "abc" }),
        JSON.stringify({ ...good, tokenHash: good.tokenHash.toUpperCase() }),
        JSON.stringify({ ...good, expiresAt: "soon" }),
        JSON.stringify({ ...good, expiresAt: good.createdAt }),
        JSON.stringify({ version: 1, tokenHash: good.tokenHash }),
    ];

    for (const text of broken) {
        writeFileSync(path, text, { mode: 0o600 });
        assert.throws(() => loadLogin(path), LoginError, text);
    }
});

test("the login lives under the state folder, and nowhere if neither is set", () => {
    assert.equal(loginFilePath({ XDG_STATE_HOME: "/state", HOME: "/home/u" }), "/state/voice-bridge/login.json");
    assert.equal(loginFilePath({ HOME: "/home/u" }), "/home/u/.local/state/voice-bridge/login.json");
    assert.equal(loginFilePath({ XDG_STATE_HOME: "", HOME: "/home/u" }), "/home/u/.local/state/voice-bridge/login.json");
    assert.throws(() => loginFilePath({ XDG_STATE_HOME: "relative", HOME: "/home/u" }), LoginError);
    assert.throws(() => loginFilePath({}), LoginError);
    assert.throws(() => loginFilePath({ HOME: "relative" }), LoginError);
});
