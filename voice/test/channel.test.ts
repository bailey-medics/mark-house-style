import assert from "node:assert/strict";
import { afterEach, beforeEach, test } from "node:test";
import { CHANNEL_METHOD } from "../src/channel.ts";
import { connectHarness, type Harness } from "./helpers.ts";

let harness: Harness;

beforeEach(async () => {
    harness = await connectHarness();
});

afterEach(async () => {
    await harness.close();
});

test("the server declares claude/channel", () => {
    const capabilities = harness.client.getServerCapabilities();

    assert.deepEqual(capabilities?.experimental?.["claude/channel"], {});
});

test("the server has no claude/channel/permission key at all", () => {
    const experimental = harness.client.getServerCapabilities()?.experimental ?? {};

    assert.equal("claude/channel/permission" in experimental, false);
});

test("the server gives the session instructions", () => {
    assert.match(harness.client.getInstructions() ?? "", /reply tool/);
});

test("tools/list returns reply alone", async () => {
    const { tools } = await harness.client.listTools();

    assert.deepEqual(
        tools.map((tool) => tool.name),
        ["reply"],
    );
});

test("a pushed message is a channel event with only valid meta keys", async () => {
    const arrived = harness.nextEvent();
    void harness.channel.ask("Hello from the phone");
    const event = await arrived;

    assert.equal(event.method, CHANNEL_METHOD);
    assert.equal(event.content, "Hello from the phone");
    assert.equal(event.meta.via, "voice");

    for (const [key, value] of Object.entries(event.meta)) {
        assert.match(key, /^[A-Za-z0-9_]+$/);
        assert.equal(typeof value, "string");
    }
});

test("ask resolves with the session's reply", async () => {
    const arrived = harness.nextEvent();
    const answer = harness.channel.ask("Ping");
    const event = await arrived;

    await harness.reply(String(event.meta.message_id), "Pong");

    assert.equal(await answer, "Pong");
});

test("a reply to an unknown message is an error", async () => {
    const result = (await harness.reply("no-such-id", "Hello")) as { isError?: boolean };

    assert.equal(result.isError, true);
});

test("a reply after the wait was aborted is refused", async () => {
    const abort = new AbortController();
    const arrived = harness.nextEvent();
    const answer = harness.channel.ask("Hello", abort.signal);
    const event = await arrived;

    abort.abort(new Error("hung up"));
    await assert.rejects(answer);
    const result = (await harness.reply(String(event.meta.message_id), "Late")) as {
        isError?: boolean;
    };

    assert.equal(result.isError, true);
});
