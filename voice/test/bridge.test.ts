import assert from "node:assert/strict";
import { mkdtempSync, rmSync, unlinkSync } from "node:fs";
import { connect, type AddressInfo } from "node:net";
import type { Server as HttpServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, test } from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { WRONG_TOKEN_ALARM_COUNT } from "../src/alarm.ts";
import {
    createBridge,
    HEADERS_TIMEOUT_MS,
    MAX_CONNECTIONS,
    MCP_PATH,
    NOTHING_WAITING,
    REQUEST_TIMEOUT_MS,
    STILL_WORKING,
} from "../src/bridge.ts";
import { headerValue, issueLogin, saveLogin } from "../src/login.ts";

const ANTHROPIC_CALLER = "160.79.104.20";
const OUTSIDE_CALLER = "203.0.113.5";
const START = new Date("2026-11-23T12:00:00.000Z");
const DAY_MS = 24 * 60 * 60 * 1000;

let bridge: HttpServer | undefined;
let client: Client | undefined;
let folder: string | undefined;
let loginPath = "";
let token = "";
let clock = START;
let logged: string[] = [];

afterEach(async () => {
    await client?.close();
    await new Promise((resolve) => (bridge ? bridge.close(resolve) : resolve(undefined)));
    if (folder !== undefined) {
        rmSync(folder, { recursive: true, force: true });
    }

    client = undefined;
    bridge = undefined;
    folder = undefined;
});

// Starts a bridge with a fresh login that lasts a week from START.
async function start(ask: (text: string) => Promise<string>, askWaitMs = 200): Promise<string> {
    folder = mkdtempSync(join(tmpdir(), "voice-bridge-"));
    loginPath = join(folder, "login.json");
    clock = START;
    logged = [];

    const login = issueLogin(7, START);
    token = login.token;
    saveLogin(loginPath, login.record);

    bridge = createBridge({ loginPath, ask, askWaitMs, log: (line) => logged.push(line), now: () => clock });
    await new Promise<void>((resolve) => bridge?.listen(0, "127.0.0.1", resolve));
    const { port } = bridge.address() as AddressInfo;

    return `http://127.0.0.1:${port}`;
}

async function connectClient(base: string): Promise<Client> {
    client = new Client({ name: "claude-ai-stand-in", version: "0.0.0" });
    const transport = new StreamableHTTPClientTransport(new URL(`${base}${MCP_PATH}`), {
        requestInit: { headers: { "cf-connecting-ip": ANTHROPIC_CALLER, authorization: headerValue(token) } },
    });
    await client.connect(transport);

    return client;
}

// One raw request, as claude.ai's servers would send it. Pass null as the
// authorisation to send no header at all.
async function post(base: string, authorisation: string | null, caller = ANTHROPIC_CALLER): Promise<Response> {
    const headers: Record<string, string> = {
        "cf-connecting-ip": caller,
        "content-type": "application/json",
        accept: "application/json, text/event-stream",
    };
    if (authorisation !== null) {
        headers.authorization = authorisation;
    }

    return fetch(`${base}${MCP_PATH}`, {
        method: "POST",
        headers,
        body: JSON.stringify({
            jsonrpc: "2.0",
            id: 1,
            method: "initialize",
            params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "t", version: "0" } },
        }),
    });
}

// One request written byte for byte, for shapes that fetch would tidy up
// before sending. Resolves with the status code of the answer.
function raw(base: string, requestLine: string, headerLines: string[]): Promise<number> {
    const { port } = new URL(base);

    return new Promise((resolve, reject) => {
        const socket = connect(Number(port), "127.0.0.1");
        let answer = "";

        socket.on("connect", () => {
            socket.write([requestLine, "Host: localhost", "Connection: close", ...headerLines, "", ""].join("\r\n"));
        });
        // The status line is all that is wanted, and an accepted GET is a
        // stream the server keeps open, so hang up as soon as it is read.
        socket.on("data", (chunk) => {
            answer += chunk.toString("utf8");
            const status = /^HTTP\/1\.1 (\d{3})/.exec(answer)?.[1];
            if (status !== undefined) {
                socket.destroy();
                resolve(Number(status));
            }
        });
        socket.on("error", reject);
        socket.on("close", () => reject(new Error("The connection closed before any status line.")));
    });
}

function alarms(): number {
    return logged.filter((line) => line.startsWith("alarm:")).length;
}

function textOf(result: unknown): string {
    const content = (result as { content: { type: string; text: string }[] }).content;

    return content.map((part) => part.text).join("");
}

test("the wrong path gets a 404 and reaches no tool", async () => {
    let asked = false;
    const base = await start(async () => {
        asked = true;
        return "";
    });

    for (const path of ["/", "/wrong/mcp", "/mcp/", "/mcp/extra", "/MCP", "/authorize", "/.well-known/oauth-protected-resource"]) {
        const response = await fetch(`${base}${path}`, {
            method: "POST",
            headers: {
                "cf-connecting-ip": ANTHROPIC_CALLER,
                "content-type": "application/json",
                authorization: headerValue(token),
            },
            body: "{}",
        });

        assert.equal(response.status, 404, path);
    }

    assert.equal(asked, false);
});

test("a caller outside Anthropic's ranges gets a 403, even with the right token", async () => {
    const base = await start(async () => "");

    const outside = await post(base, headerValue(token), OUTSIDE_CALLER);
    const missing = await fetch(`${base}${MCP_PATH}`, { method: "POST", headers: { authorization: headerValue(token) } });

    assert.equal(outside.status, 403);
    assert.equal(missing.status, 403);
});

test("a call with no token gets a 401 with the header, and reaches no tool", async () => {
    let asked = false;
    const base = await start(async () => {
        asked = true;
        return "";
    });

    const response = await post(base, null);

    assert.equal(response.status, 401);
    assert.match(response.headers.get("www-authenticate") ?? "", /^Bearer /);
    assert.equal(asked, false);
});

test("a wrong token, and a token of the wrong shape, are refused", async () => {
    const base = await start(async () => "");
    const other = issueLogin(7, START).token;

    for (const authorisation of [headerValue(other), token, `bearer ${token}`, `Basic ${token}`, `Bearer ${token}x`, ""]) {
        const response = await post(base, authorisation);
        assert.equal(response.status, 401, authorisation === "" ? "(empty)" : authorisation.slice(0, 12));
    }
});

test("every method needs the token, not only POST", async () => {
    const base = await start(async () => "");

    for (const method of ["GET", "DELETE", "PUT", "OPTIONS"]) {
        const response = await fetch(`${base}${MCP_PATH}`, { method, headers: { "cf-connecting-ip": ANTHROPIC_CALLER } });
        assert.equal(response.status, 401, method);
    }
});

test("the right token reaches the bridge, and stops working when it expires", async () => {
    const base = await start(async () => "");

    assert.equal((await post(base, headerValue(token))).status, 200);

    clock = new Date(START.getTime() + 7 * DAY_MS);
    assert.equal((await post(base, headerValue(token))).status, 401);
});

test("many wrong tokens raise one alarm in the log, and never shut the right token out", async () => {
    const base = await start(async () => "");
    const other = headerValue(issueLogin(7, START).token);

    for (let count = 0; count < WRONG_TOKEN_ALARM_COUNT - 1; count += 1) {
        assert.equal((await post(base, other)).status, 401);
    }
    assert.equal(alarms(), 0);

    for (let count = 0; count < WRONG_TOKEN_ALARM_COUNT * 3; count += 1) {
        assert.equal((await post(base, other)).status, 401);
    }
    assert.equal(alarms(), 1);

    assert.equal((await post(base, headerValue(token))).status, 200);
});

test("a missing or expired token does not count towards the alarm", async () => {
    const base = await start(async () => "");

    for (let count = 0; count < WRONG_TOKEN_ALARM_COUNT + 2; count += 1) {
        assert.equal((await post(base, null)).status, 401);
    }

    clock = new Date(START.getTime() + 7 * DAY_MS);
    for (let count = 0; count < WRONG_TOKEN_ALARM_COUNT + 2; count += 1) {
        assert.equal((await post(base, headerValue(token))).status, 401);
    }

    assert.equal(alarms(), 0);
});

test("a caller outside Anthropic's ranges cannot raise the alarm", async () => {
    const base = await start(async () => "");
    const other = headerValue(issueLogin(7, START).token);

    for (let count = 0; count < WRONG_TOKEN_ALARM_COUNT + 2; count += 1) {
        assert.equal((await post(base, other, OUTSIDE_CALLER)).status, 403);
    }

    assert.equal(alarms(), 0);
    assert.equal((await post(base, headerValue(token))).status, 200);
});

// Node drops the spaces around a header's value before the bridge sees
// it, so they are no part of the secret. Everything between them must
// still match exactly.
test("spaces around the header are dropped by Node, and the rest must match exactly", async () => {
    const base = await start(async () => "");
    const caller = `cf-connecting-ip: ${ANTHROPIC_CALLER}`;
    const send = (authorisation: string): Promise<number> =>
        raw(base, `GET ${MCP_PATH} HTTP/1.1`, [caller, "Accept: text/event-stream", `Authorization:${authorisation}`]);

    assert.notEqual(await send(`   Bearer ${token}  `), 401);
    assert.notEqual(await send(`Bearer ${token}\t`), 401);

    assert.equal(await send(` Bearer  ${token}`), 401);
    assert.equal(await send(` bearer ${token}`), 401);
    assert.equal(await send(` Bearer ${token}x`), 401);
    assert.equal(await send(` Bearer ${token.slice(0, -1)}`), 401);
});

test("a request target that cannot be read as a path gets a 404, not an error", async () => {
    const base = await start(async () => "");
    const headers = [`cf-connecting-ip: ${ANTHROPIC_CALLER}`, `Authorization: ${headerValue(token)}`];

    for (const target of ["//", "///", "http://[::1"]) {
        assert.equal(await raw(base, `GET ${target} HTTP/1.1`, headers), 404, target);
    }

    assert.equal(logged.some((line) => line.startsWith("error:")), false);
});

test("the server drops slow connections and limits how many are open", async () => {
    await start(async () => "");

    assert.equal(bridge?.headersTimeout, HEADERS_TIMEOUT_MS);
    assert.equal(bridge?.requestTimeout, REQUEST_TIMEOUT_MS);
    assert.equal(bridge?.maxConnections, MAX_CONNECTIONS);
    assert.ok(HEADERS_TIMEOUT_MS <= 10_000 && REQUEST_TIMEOUT_MS <= 30_000 && MAX_CONNECTIONS <= 64);
});

test("deleting the login refuses the next call, and a new login lets the new token in", async () => {
    const base = await start(async () => "");
    assert.equal((await post(base, headerValue(token))).status, 200);

    unlinkSync(loginPath);
    assert.equal((await post(base, headerValue(token))).status, 401);

    const next = issueLogin(7, START);
    saveLogin(loginPath, next.record);
    assert.equal((await post(base, headerValue(token))).status, 401);
    assert.equal((await post(base, headerValue(next.token))).status, 200);
});

test("the token never appears in the log", async () => {
    const mcp = await connectClient(await start(async () => "fine"));
    const base = `http://127.0.0.1:${(bridge?.address() as AddressInfo).port}`;

    await mcp.callTool({ name: "ask", arguments: { text: "hello" } });
    await post(base, headerValue(issueLogin(7, START).token));
    await post(base, null);

    assert.ok(logged.length > 0);
    assert.equal(logged.some((line) => line.includes(token) || line.toLowerCase().includes("bearer ")), false);
});

test("an MCP request is answered as an event stream", async () => {
    const base = await start(async () => "");

    const response = await post(base, headerValue(token));

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
