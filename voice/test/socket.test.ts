import assert from "node:assert/strict";
import { mkdtemp, rm, stat } from "node:fs/promises";
import { connect, type Server } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, test } from "node:test";
import { MAX_LINE_BYTES } from "../src/limits.ts";
import { listenOnSocket, socketPath } from "../src/socket.ts";
import { connectHarness, type Harness } from "./helpers.ts";

let harness: Harness;
let runtimeDir: string;
let path: string;
let server: Server;

beforeEach(async () => {
    harness = await connectHarness();
    runtimeDir = await mkdtemp(join(tmpdir(), "voice-test-"));
    path = socketPath(runtimeDir);
    server = await listenOnSocket(harness.channel, path);
});

afterEach(async () => {
    await new Promise((resolve) => server.close(resolve));
    await harness.close();
    await rm(runtimeDir, { recursive: true, force: true });
});

// Sends raw text down the socket and resolves with the parsed answer.
function exchange(raw: string): Promise<Record<string, unknown>> {
    return new Promise((resolve, reject) => {
        const socket = connect(path);
        let answer = "";

        socket.on("connect", () => socket.write(raw));
        socket.on("data", (chunk: Buffer) => {
            answer += chunk.toString("utf8");
        });
        socket.on("end", () => resolve(JSON.parse(answer) as Record<string, unknown>));
        socket.on("error", reject);
    });
}

const message = (text: string): string => `${JSON.stringify({ text })}\n`;

test("the folder is 0700 and the socket 0600", async () => {
    const folderMode = (await stat(join(path, ".."))).mode & 0o777;
    const socketMode = (await stat(path)).mode & 0o777;

    assert.equal(folderMode, 0o700);
    assert.equal(socketMode, 0o600);
});

test("socketPath refuses to guess when XDG_RUNTIME_DIR is missing", () => {
    assert.throws(() => socketPath(undefined));
    assert.throws(() => socketPath(""));
});

test("socketPath refuses a path too long for a socket", () => {
    assert.throws(() => socketPath(`/${"a".repeat(100)}`), /longer than a socket path/);
});

test("a message goes in and its reply comes back on the same connection", async () => {
    const arrived = harness.nextEvent();
    const answer = exchange(message("What time is it?"));
    const event = await arrived;

    await harness.reply(String(event.meta.message_id), "Teatime.");

    assert.deepEqual(await answer, { reply: "Teatime." });
});

test("an over-long message is refused and nothing is pushed", async () => {
    const answer = await exchange("a".repeat(MAX_LINE_BYTES + 1));

    assert.deepEqual(answer, { error: "message is too long" });
    assert.equal(harness.events.length, 0);
});

test("a line that is not JSON, or has no text, is refused", async () => {
    assert.equal((await exchange("hello\n")).error, "not valid JSON");
    assert.equal((await exchange("{}\n")).error, "no text");
    assert.equal(harness.events.length, 0);
});

test("two clients waiting at once each get their own answer", async () => {
    const firstArrived = harness.nextEvent();
    const first = exchange(message("first"));
    const firstEvent = await firstArrived;

    const secondArrived = harness.nextEvent();
    const second = exchange(message("second"));
    const secondEvent = await secondArrived;

    await harness.reply(String(secondEvent.meta.message_id), "answer to second");
    await harness.reply(String(firstEvent.meta.message_id), "answer to first");

    assert.deepEqual(await first, { reply: "answer to first" });
    assert.deepEqual(await second, { reply: "answer to second" });
});

test("a second channel will not start beside a running one", async () => {
    await assert.rejects(listenOnSocket(harness.channel, path), /already listening/);
});
