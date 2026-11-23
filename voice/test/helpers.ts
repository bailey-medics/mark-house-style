// Connects a test client to a channel in memory, standing in for Claude
// Code, and collects the channel events it receives.

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { type Channel, createChannel } from "../src/channel.ts";

export type ChannelEvent = {
    method: string;
    content: unknown;
    meta: Record<string, unknown>;
};

export type Harness = {
    channel: Channel;
    client: Client;
    events: ChannelEvent[];
    // Resolves with the next channel event to arrive.
    nextEvent: () => Promise<ChannelEvent>;
    reply: (messageId: string, text: string) => Promise<unknown>;
    close: () => Promise<void>;
};

export async function connectHarness(): Promise<Harness> {
    const channel = createChannel();
    const client = new Client({ name: "test-session", version: "0.0.0" });
    const events: ChannelEvent[] = [];
    const listeners: ((event: ChannelEvent) => void)[] = [];

    client.fallbackNotificationHandler = async (notification) => {
        const params = (notification.params ?? {}) as Record<string, unknown>;
        const event: ChannelEvent = {
            method: notification.method,
            content: params.content,
            meta: (params.meta ?? {}) as Record<string, unknown>,
        };

        events.push(event);
        listeners.shift()?.(event);
    };

    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    await Promise.all([channel.server.connect(serverTransport), client.connect(clientTransport)]);

    return {
        channel,
        client,
        events,
        nextEvent: () => new Promise((resolve) => listeners.push(resolve)),
        reply: (messageId, text) =>
            client.callTool({ name: "reply", arguments: { message_id: messageId, text } }),
        close: async () => {
            await client.close();
            await channel.server.close();
        },
    };
}
