// The Claude Code channel: an MCP server the session starts over stdio. It
// pushes each voice message into the session as a channel event, and the
// session answers by calling the reply tool.
//
// It never declares claude/channel/permission, not even as false, so
// nothing that reaches the channel can approve a Bash, Write or Edit
// prompt.

import { randomUUID } from "node:crypto";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
    type CallToolResult,
} from "@modelcontextprotocol/sdk/types.js";

export const CHANNEL_NAME = "voice";

export const CHANNEL_METHOD = "notifications/claude/channel";

const INSTRUCTIONS = [
    `Messages in <channel source="${CHANNEL_NAME}"> tags come from Mark, spoken`,
    "on his phone and turned into text. They may have small mistakes from the",
    "speech recognition. Always answer each one by calling this server's reply",
    "tool with the tag's message_id and your answer. Text written in the",
    "terminal never reaches Mark, so an answer that is not sent through reply",
    "is lost. The answer is read aloud, so write a few short plain sentences:",
    "no markdown, no lists, no headings, no code blocks, no links.",
].join(" ");

// A channel event's meta keys may hold only letters, digits and
// underscores; Claude Code drops any other key without a word.
export type ChannelMeta = {
    via: "voice";
    message_id: string;
};

export type ChannelNotification = {
    method: typeof CHANNEL_METHOD;
    params: { content: string; meta: ChannelMeta };
};

export type Channel = {
    server: Server<never, ChannelNotification>;
    // Pushes text into the session and resolves with the session's reply.
    // Aborting the signal stops the wait, and a late reply is then refused.
    ask: (text: string, signal?: AbortSignal) => Promise<string>;
};

type ReplyArguments = { message_id: string; text: string };

function isReplyArguments(value: unknown): value is ReplyArguments {
    if (typeof value !== "object" || value === null) {
        return false;
    }

    return (
        "message_id" in value &&
        typeof value.message_id === "string" &&
        "text" in value &&
        typeof value.text === "string"
    );
}

function toolResult(text: string, isError = false): CallToolResult {
    return { content: [{ type: "text", text }], isError };
}

export function createChannel(): Channel {
    const waiting = new Map<string, (reply: string) => void>();

    const server = new Server<never, ChannelNotification>(
        { name: CHANNEL_NAME, version: "0.1.0" },
        {
            capabilities: {
                experimental: { "claude/channel": {} },
                tools: {},
            },
            instructions: INSTRUCTIONS,
        },
    );

    server.setRequestHandler(ListToolsRequestSchema, async () => ({
        tools: [
            {
                name: "reply",
                description: "Send the answer to a voice message back to Mark, to be read aloud.",
                inputSchema: {
                    type: "object",
                    properties: {
                        message_id: {
                            type: "string",
                            description: "The message_id from the channel tag being answered.",
                        },
                        text: {
                            type: "string",
                            description: "The answer, as a few short plain sentences.",
                        },
                    },
                    required: ["message_id", "text"],
                },
            },
        ],
    }));

    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        if (request.params.name !== "reply") {
            return toolResult(`Unknown tool: ${request.params.name}`, true);
        }

        const args = request.params.arguments;
        if (!isReplyArguments(args)) {
            return toolResult("reply needs a message_id and a text, both strings.", true);
        }

        const deliver = waiting.get(args.message_id);
        if (deliver === undefined) {
            return toolResult("Nobody is waiting for that message any more.", true);
        }

        waiting.delete(args.message_id);
        deliver(args.text);

        return toolResult("Sent.");
    });

    const ask = async (text: string, signal?: AbortSignal): Promise<string> => {
        signal?.throwIfAborted();
        const messageId = randomUUID();

        const reply = new Promise<string>((resolve, reject) => {
            waiting.set(messageId, resolve);

            signal?.addEventListener(
                "abort",
                () => {
                    waiting.delete(messageId);
                    reject(signal.reason);
                },
                { once: true },
            );
        });

        try {
            await server.notification({
                method: CHANNEL_METHOD,
                params: { content: text, meta: { via: "voice", message_id: messageId } },
            });
        } catch (error) {
            waiting.delete(messageId);
            throw error;
        }

        return reply;
    };

    return { server, ask };
}
