import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import type { Server as HttpServer } from "node:http";
import { afterEach, test } from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { createBridge, NOTHING_WAITING, STILL_WORKING } from "../src/bridge.ts";

const SECRET = "0123456789abcdef0123456789abcdef";
const ANTHROPIC_CALLER = "160.79.104.20";

let bridge: HttpServer | undefined;
let client: Client | undefined;

afterEach(async () => {
    await client?.close();
    await new Promise((resolve) => (bridge ? bridge.close(resolve) : resolve(undefined)));
    client = undefined;
    bridge = undefined;
});

async function start(ask: (text: string) => Promise<string>, askWaitMs = 200): Promise<string> {
    bridge = createBridge({ pathSecret: SECRET, ask, askWaitMs });
    await new Promise<void>((resolve) => bridge?.listen(0, "127.0.0.1", resolve));
    const { port } = bridge.address() as AddressInfo;

    return `http://127.0.0.1:${port}`;
}

async function connectClient(base: string): Promise<Client> {
    client = new Client({ name: "claude-ai-stand-in", version: "0.0.0" });
    const transport = new StreamableHTTPClientTransport(new URL(`${base}/${SECRET}/mcp`), {
        requestInit: { headers: { "cf-connecting-ip": ANTHROPIC_CALLER } },
    });
    await client.connect(transport);

    return client;
}

function textOf(result: unknown): string {
    const content = (result as { content: { type: string; text: string }[] }).content;

    return content.map((part) => part.text).join("");
}

test("a bad path secret stops the bridge being made", () => {
    assert.throws(() => createBridge({ pathSecret: "short", ask: async () => "", askWaitMs: 1 }));
});

test("the wrong path gets a 404 and reaches no tool", async () => {
    let asked = false;
    const base = await start(async () => {
        asked = true;
        return "";
    });

    const response = await fetch(`${base}/wrong/mcp`, {
        method: "POST",
        headers: { "cf-connecting-ip": ANTHROPIC_CALLER, "content-type": "application/json" },
        body: "{}",
    });

    assert.equal(response.status, 404);
    assert.equal(asked, false);
});

test("a caller outside Anthropic's ranges gets a 403, even on the right path", async () => {
    const base = await start(async () => "");

    const outside = await fetch(`${base}/${SECRET}/mcp`, {
        method: "POST",
        headers: { "cf-connecting-ip": "203.0.113.5" },
    });
    const missing = await fetch(`${base}/${SECRET}/mcp`, { method: "POST" });

    assert.equal(outside.status, 403);
    assert.equal(missing.status, 403);
});

test("an MCP request is answered as an event stream", async () => {
    const base = await start(async () => "");

    const response = await fetch(`${base}/${SECRET}/mcp`, {
        method: "POST",
        headers: {
            "cf-connecting-ip": ANTHROPIC_CALLER,
            "content-type": "application/json",
            accept: "application/json, text/event-stream",
        },
        body: JSON.stringify({
            jsonrpc: "2.0",
            id: 1,
            method: "initialize",
            params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "t", version: "0" } },
        }),
    });

    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type") ?? "", /text\/event-stream/);
});

test("the tools are ping, ask and check_reply", async () => {
    const mcp = await connectClient(await start(async () => ""));
    const { tools } = await mcp.listTools();

    assert.deepEqual(tools.map((tool) => tool.name).sort(), ["ask", "check_reply", "ping"]);
});

test("every tool has a title, and only ask is marked as able to change things", async () => {
    const mcp = await connectClient(await start(async () => ""));
    const { tools } = await mcp.listTools();
    const byName = new Map(tools.map((tool) => [tool.name, tool]));

    for (const tool of tools) {
        assert.ok(tool.title !== undefined && tool.title.trim() !== "", `${tool.name} has no title`);
        assert.equal(tool.annotations?.title, tool.title);
    }

    assert.equal(byName.get("ping")?.annotations?.readOnlyHint, true);
    assert.equal(byName.get("check_reply")?.annotations?.readOnlyHint, true);
    assert.equal(byName.get("ask")?.annotations?.readOnlyHint, false);
    assert.equal(byName.get("ask")?.annotations?.destructiveHint, true);
});

test("ping waits as asked", async () => {
    const mcp = await connectClient(await start(async () => ""));

    const started = Date.now();
    const result = await mcp.callTool({ name: "ping", arguments: { delay_seconds: 0.3 } });

    assert.ok(Date.now() - started >= 290);
    assert.match(textOf(result), /pong/);
});

test("ping refuses a delay out of range", async () => {
    const mcp = await connectClient(await start(async () => ""));
    const result = await mcp.callTool({ name: "ping", arguments: { delay_seconds: 9999 } });

    assert.equal((result as { isError?: boolean }).isError, true);
});

test("ask returns the session's reply", async () => {
    const mcp = await connectClient(await start(async (text) => `You said: ${text}`));
    const result = await mcp.callTool({ name: "ask", arguments: { text: "hello" } });

    assert.equal(textOf(result), "You said: hello");
});

test("ask refuses empty or over-long text, and never reaches the session", async () => {
    let asked = false;
    const mcp = await connectClient(
        await start(async () => {
            asked = true;
            return "";
        }),
    );

    const empty = await mcp.callTool({ name: "ask", arguments: { text: " " } });
    const long = await mcp.callTool({ name: "ask", arguments: { text: "a".repeat(2001) } });

    assert.equal((empty as { isError?: boolean }).isError, true);
    assert.equal((long as { isError?: boolean }).isError, true);
    assert.equal(asked, false);
});

test("a slow reply says still working, and check_reply fetches it later", async () => {
    let finish: (reply: string) => void = () => {};
    const slow = new Promise<string>((resolve) => {
        finish = resolve;
    });
    const mcp = await connectClient(await start(() => slow, 100));

    const first = await mcp.callTool({ name: "ask", arguments: { text: "a hard one" } });
    const tooSoon = await mcp.callTool({ name: "check_reply", arguments: {} });
    finish("Here is the answer.");
    await new Promise((resolve) => setImmediate(resolve));
    const later = await mcp.callTool({ name: "check_reply", arguments: {} });
    const after = await mcp.callTool({ name: "check_reply", arguments: {} });

    assert.equal(textOf(first), STILL_WORKING);
    assert.equal(textOf(tooSoon), STILL_WORKING);
    assert.equal(textOf(later), "Here is the answer.");
    assert.equal(textOf(after), NOTHING_WAITING);
});

test("a session error comes back as a tool error", async () => {
    const mcp = await connectClient(
        await start(async () => {
            throw new Error("The voice channel closed without answering.");
        }),
    );
    const result = await mcp.callTool({ name: "ask", arguments: { text: "hello" } });

    assert.equal((result as { isError?: boolean }).isError, true);
    assert.match(textOf(result), /closed without answering/);
});
