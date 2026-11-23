// The bridge: an MCP server over Streamable HTTP, for claude.ai's custom
// connector. It listens on loopback only, and cloudflared is the door to
// it. Every request must come through the tunnel from Anthropic's ranges,
// to the one path, and carry the login's token; anything else gets
// nothing. There is no way to switch the login off.

import { createServer, type IncomingMessage, type Server as HttpServer, type ServerResponse } from "node:http";
import { setTimeout as sleep } from "node:timers/promises";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
    type CallToolResult,
    type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { CALLER_HEADER, checkCaller } from "./caller.ts";
import { MAX_TEXT_LENGTH } from "./limits.ts";
import { checkToken, loadLogin, LoginError } from "./login.ts";
import { createWrongTokenAlarm, WRONG_TOKEN_ALARM_COUNT } from "./alarm.ts";

// The one path the bridge serves.
export const MCP_PATH = "/mcp";

// The longest ping delay, for measuring how long voice mode will wait.
export const MAX_PING_SECONDS = 600;

// The largest request body the bridge reads. An MCP call with a spoken
// message is a few kilobytes at most.
export const MAX_BODY_BYTES = 64 * 1024;

// How long a connection may take to send its headers, and its whole
// request, before it is dropped, and how many connections may be open at
// once. Without these, anything on the box could hold connections open
// half-sent until the bridge ran out of memory, with no token needed. The
// only real caller is cloudflared, which is quick. These time the request
// coming in, not the answer going out, so a slow tool is not cut short.
export const HEADERS_TIMEOUT_MS = 10_000;
export const REQUEST_TIMEOUT_MS = 30_000;
export const MAX_CONNECTIONS = 64;
const CONNECTION_CHECK_MS = 5_000;

export const STILL_WORKING =
    "Still working on that. Ask me to check for the reply in a little while.";

export const NOTHING_WAITING = "There is no reply waiting.";

export type BridgeOptions = {
    // Where the login record is kept. It is read afresh for every request,
    // so a new token, or deleting the file, takes effect at once.
    loginPath: string;
    // Sends text to the voice session and resolves with its reply.
    ask: (text: string) => Promise<string>;
    // How long ask waits before saying it is still working.
    askWaitMs: number;
    log?: (line: string) => void;
    // The clock, so that tests can move it.
    now?: () => Date;
};

type BridgeState = {
    lateReplies: string[];
    pending: number;
};

function toolResult(text: string, isError = false): CallToolResult {
    return { content: [{ type: "text", text }], isError };
}

function stringArgument(args: Record<string, unknown> | undefined, name: string): string | null {
    const value = args?.[name];

    return typeof value === "string" ? value : null;
}

async function ping(args: Record<string, unknown> | undefined): Promise<CallToolResult> {
    const raw = args?.delay_seconds ?? 0;
    if (typeof raw !== "number" || !Number.isFinite(raw) || raw < 0 || raw > MAX_PING_SECONDS) {
        return toolResult(`delay_seconds must be a number from 0 to ${MAX_PING_SECONDS}.`, true);
    }

    await sleep(raw * 1000);

    return toolResult(`The dev box says pong, after ${raw} seconds.`);
}

async function ask(
    options: BridgeOptions,
    state: BridgeState,
    args: Record<string, unknown> | undefined,
): Promise<CallToolResult> {
    const text = stringArgument(args, "text");
    if (text === null || text.trim() === "") {
        return toolResult("ask needs some text.", true);
    }

    if (text.length > MAX_TEXT_LENGTH) {
        return toolResult(`That is longer than ${MAX_TEXT_LENGTH} characters.`, true);
    }

    state.pending += 1;
    const reply = options.ask(text).finally(() => {
        state.pending -= 1;
    });

    type Outcome = { kind: "answer"; answer: string } | { kind: "error"; error: unknown } | { kind: "timeout" };
    const first: Outcome = await Promise.race([
        reply.then(
            (answer): Outcome => ({ kind: "answer", answer }),
            (error: unknown): Outcome => ({ kind: "error", error }),
        ),
        sleep(options.askWaitMs).then((): Outcome => ({ kind: "timeout" })),
    ]);

    if (first.kind === "answer") {
        return toolResult(first.answer);
    }

    if (first.kind === "error") {
        const message = first.error instanceof Error ? first.error.message : String(first.error);
        return toolResult(message, true);
    }

    reply.then(
        (answer) => state.lateReplies.push(answer),
        (error: unknown) =>
            state.lateReplies.push(
                `The session could not answer: ${error instanceof Error ? error.message : String(error)}`,
            ),
    );

    return toolResult(STILL_WORKING);
}

function checkReply(state: BridgeState): CallToolResult {
    if (state.lateReplies.length > 0) {
        const replies = state.lateReplies.splice(0);
        return toolResult(replies.join("\n\n"));
    }

    return toolResult(state.pending > 0 ? STILL_WORKING : NOTHING_WAITING);
}

const PING_TITLE = "Ping the dev box";
const ASK_TITLE = "Ask the dev box session";
const CHECK_REPLY_TITLE = "Check for a late reply";

// Every tool carries a title and honest hints, as Anthropic's connector
// docs ask. claude.ai may run a read-only tool without asking first, so a
// hint must never say read-only of a tool that can change something. The
// title is given twice because older clients read it from the annotations.
export const TOOLS: Tool[] = [
    {
        name: "ping",
        title: PING_TITLE,
        description: "Check the dev box is reachable. Waits delay_seconds before answering.",
        inputSchema: {
            type: "object",
            properties: {
                delay_seconds: {
                    type: "number",
                    description: `Seconds to wait before answering, 0 to ${MAX_PING_SECONDS}.`,
                },
            },
        },
        annotations: { title: PING_TITLE, readOnlyHint: true },
    },
    {
        name: "ask",
        title: ASK_TITLE,
        description: "Send what Mark said to his Claude Code session on the dev box, and return its answer.",
        inputSchema: {
            type: "object",
            properties: {
                text: { type: "string", description: "What Mark said, word for word." },
            },
            required: ["text"],
        },
        // Not read-only, and marked destructive: the words can lead the
        // session to change or delete things.
        annotations: { title: ASK_TITLE, readOnlyHint: false, destructiveHint: true },
    },
    {
        name: "check_reply",
        title: CHECK_REPLY_TITLE,
        description: "Fetch an answer from the dev box session that took too long for ask.",
        inputSchema: { type: "object", properties: {} },
        annotations: { title: CHECK_REPLY_TITLE, readOnlyHint: true },
    },
];

function buildMcpServer(options: BridgeOptions, state: BridgeState): Server {
    const server = new Server(
        { name: "dev-box-voice", version: "0.1.0" },
        {
            capabilities: { tools: { listChanged: true } },
        },
    );

    server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const { name, arguments: args } = request.params;
        options.log?.(`tool ${name}`);

        switch (name) {
            case "ping":
                return ping(args);
            case "ask":
                return ask(options, state, args);
            case "check_reply":
                return checkReply(state);
            default:
                return toolResult(`Unknown tool: ${name}`, true);
        }
    });

    return server;
}

type Refusal = 401 | 403 | 404;

const REFUSALS: Record<Refusal, string> = {
    401: "Unauthorised\n",
    403: "Forbidden\n",
    404: "Not found\n",
};

// The path of a request, or null when its target cannot be read as one.
function pathOf(target: string | undefined): string | null {
    try {
        return new URL(target ?? "/", "http://localhost").pathname;
    } catch {
        return null;
    }
}

function refuse(res: ServerResponse, status: Refusal): void {
    const headers: Record<string, string> = { "content-type": "text/plain" };
    if (status === 401) {
        headers["www-authenticate"] = 'Bearer realm="voice"';
    }

    res.writeHead(status, headers).end(REFUSALS[status]);
}

type LoginCheck = { ok: true } | { ok: false; reason: string; wrongToken: boolean };

// Checks the request's token against the login on disk. Anything that
// stops the login being read is a refusal, never a pass. The reason goes
// to the log only, and the header itself is never logged.
function checkLogin(loginPath: string, header: string | undefined, now: Date): LoginCheck {
    let record;
    try {
        record = loadLogin(loginPath);
    } catch (error) {
        if (error instanceof LoginError) {
            return { ok: false, reason: `no usable login: ${error.message}`, wrongToken: false };
        }

        throw error;
    }

    const verdict = checkToken(record, header, now);
    if (verdict.ok) {
        return { ok: true };
    }

    return { ok: false, reason: `${verdict.reason} token`, wrongToken: verdict.reason === "wrong" };
}

export function createBridge(options: BridgeOptions): HttpServer {
    const state: BridgeState = { lateReplies: [], pending: 0 };
    const alarm = createWrongTokenAlarm();
    const now = options.now ?? ((): Date => new Date());

    // The checks run in this order, and each one answers before the body
    // is read: the caller's address, the path, the token. A wrong token is
    // refused and counted for the alarm, and nothing is ever locked: the
    // right token always works.
    const handle = async (req: IncomingMessage, res: ServerResponse): Promise<void> => {
        const verdict = checkCaller(req.socket.remoteAddress, req.headers[CALLER_HEADER]);
        if (!verdict.allowed) {
            options.log?.(`refused ${req.method} (${verdict.reason})`);
            refuse(res, 403);
            return;
        }

        if (pathOf(req.url) !== MCP_PATH) {
            options.log?.(`refused ${req.method} from ${verdict.caller} (wrong path)`);
            refuse(res, 404);
            return;
        }

        const login = checkLogin(options.loginPath, req.headers.authorization, now());
        if (!login.ok) {
            options.log?.(`refused ${req.method} from ${verdict.caller} (${login.reason})`);
            if (login.wrongToken && alarm.wrong(now())) {
                options.log?.(`alarm: ${WRONG_TOKEN_ALARM_COUNT} wrong tokens within the hour. Somebody may be trying the bridge.`);
            }

            refuse(res, 401);
            return;
        }

        const accept = req.headers.accept ?? "-";
        const version = req.headers["mcp-protocol-version"] ?? "-";
        options.log?.(`${req.method} from ${verdict.caller} (accept: ${accept}; protocol: ${version})`);
        res.on("finish", () => options.log?.(`answered ${req.method} with ${res.statusCode}`));

        const server = buildMcpServer(options, state);
        // Each request stands alone. Answers come as an event stream, as
        // the servers claude.ai is known to work with send them.
        const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });

        res.on("close", () => {
            void transport.close();
            void server.close();
        });

        let parsed: unknown;
        if (req.method === "POST") {
            const chunks: Buffer[] = [];
            let size = 0;

            for await (const chunk of req) {
                size += (chunk as Buffer).length;
                if (size > MAX_BODY_BYTES) {
                    res.writeHead(413, { "content-type": "text/plain" }).end("Too large\n");
                    return;
                }
                chunks.push(chunk as Buffer);
            }

            try {
                parsed = JSON.parse(Buffer.concat(chunks).toString("utf8"));
            } catch {
                res.writeHead(400, { "content-type": "text/plain" }).end("Not JSON\n");
                return;
            }

            const methods = (Array.isArray(parsed) ? parsed : [parsed])
                .map((message: unknown) =>
                    typeof message === "object" && message !== null && "method" in message
                        ? typeof message.method === "string"
                            ? message.method
                            : "unreadable"
                        : "response",
                )
                .join(", ");
            options.log?.(`request: ${methods}`);
        }

        await server.connect(transport);
        await transport.handleRequest(req, res, parsed);
    };

    const server = createServer(
        {
            headersTimeout: HEADERS_TIMEOUT_MS,
            requestTimeout: REQUEST_TIMEOUT_MS,
            connectionsCheckingInterval: CONNECTION_CHECK_MS,
        },
        (req, res) => {
            handle(req, res).catch((error: unknown) => {
                options.log?.(`error: ${error instanceof Error ? error.message : String(error)}`);
                if (!res.headersSent) {
                    res.writeHead(500, { "content-type": "text/plain" }).end("Internal error\n");
                }
            });
        },
    );
    server.maxConnections = MAX_CONNECTIONS;

    return server;
}
