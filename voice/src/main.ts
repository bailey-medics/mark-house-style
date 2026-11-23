// Starts the voice channel. Claude Code runs this itself, over stdio, when
// a session is started with
// --dangerously-load-development-channels server:voice. Nothing may be
// written to stdout but MCP messages, so notes go to stderr.

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createChannel } from "./channel.ts";
import { listenOnSocket, socketPath } from "./socket.ts";

const channel = createChannel();
const path = socketPath(process.env.XDG_RUNTIME_DIR);

await channel.server.connect(new StdioServerTransport());
const socketServer = await listenOnSocket(channel, path);
console.error(`voice channel listening on ${path}`);

const stop = (): void => {
    socketServer.close();
    process.exit(0);
};

process.stdin.on("close", stop);
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
