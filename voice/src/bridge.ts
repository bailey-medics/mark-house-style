// The bridge: an MCP server over Streamable HTTP, for claude.ai's custom
// connector. It listens on loopback only, and cloudflared is the door to
// it. Every request must come through the tunnel from Anthropic's ranges,
// and to a secret path; anything else gets nothing.

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

// The longest ping delay, for measuring how long voice mode will wait.
export const MAX_PING_SECONDS = 600;

// The largest request body the bridge reads. An MCP call with a spoken
// message is a few kilobytes at most.
export const MAX_BODY_BYTES = 64 * 1024;

export const STILL_WORKING =
    "Still working on that. Ask me to check for the reply in a little while.";

export const NOTHING_WAITING = "There is no reply waiting.";

export type BridgeOptions = {
    // 32 lowercase hex characters; the bridge serves only /<secret>/mcp.
    pathSecret: string;
    // Sends text to the voice session and resolves with its reply.
    ask: (text: string) => Promise<string>;
    // How long ask waits before saying it is still working.
    askWaitMs: number;
    log?: (line: string) => void;
};

type BridgeState = {
    lateReplies: string[];
    pending: number;
};

export function isPathSecret(value: string | undefined): value is string {
    return value !== undefined && /^[0-9a-f]{32}$/.test(value);
}

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

function refuse(res: ServerResponse, status: 403 | 404): void {
    res.writeHead(status, { "content-type": "text/plain" }).end(status === 403 ? "Forbidden\n" : "Not found\n");
}

export function createBridge(options: BridgeOptions): HttpServer {
    if (!isPathSecret(options.pathSecret)) {
        throw new Error("The path secret must be 32 lowercase hex characters.");
    }

    const state: BridgeState = { lateReplies: [], pending: 0 };
    const mcpPath = `/${options.pathSecret}/mcp`;

    const handle = async (req: IncomingMessage, res: ServerResponse): Promise<void> => {
        const verdict = checkCaller(req.socket.remoteAddress, req.headers[CALLER_HEADER]);
        if (!verdict.allowed) {
            options.log?.(`refused ${req.method} (${verdict.reason})`);
            refuse(res, 403);
            return;
        }

        const path = new URL(req.url ?? "/", "http://localhost").pathname;
        if (path !== mcpPath) {
            options.log?.(`refused ${req.method} from ${verdict.caller} (wrong path)`);
            refuse(res, 404);
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
                        ? String(message.method)
                        : "response",
                )
                .join(", ");
            options.log?.(`request: ${methods}`);
        }

        await server.connect(transport);
        await transport.handleRequest(req, res, parsed);
    };

    return createServer((req, res) => {
        handle(req, res).catch((error: unknown) => {
            options.log?.(`error: ${error instanceof Error ? error.message : String(error)}`);
            if (!res.headersSent) {
                res.writeHead(500, { "content-type": "text/plain" }).end("Internal error\n");
            }
        });
    });
}
