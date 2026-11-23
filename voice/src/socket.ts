// The private door into the channel: a Unix socket in a folder only Mark's
// user can open. No network port. Each connection sends one line of JSON,
// {"text": "..."}, waits, and gets back one line, {"reply": "..."} or
// {"error": "..."}.

import { chmod, lstat, mkdir, unlink } from "node:fs/promises";
import { connect, createServer, type Server, type Socket } from "node:net";
import { join } from "node:path";
import type { Channel } from "./channel.ts";
import { MAX_LINE_BYTES, parseMessage } from "./limits.ts";

export const SOCKET_FOLDER_NAME = "voice-channel";

export const SOCKET_FILE_NAME = "channel.sock";

// Linux keeps a socket's path in 108 bytes, one of them for the end marker.
export const MAX_SOCKET_PATH_BYTES = 107;

// Where the socket lives: in the user's runtime folder, never a shared one.
export function socketPath(runtimeDir: string | undefined): string {
    if (runtimeDir === undefined || runtimeDir === "") {
        throw new Error("XDG_RUNTIME_DIR is not set, so there is no private place for the socket.");
    }

    const path = join(runtimeDir, SOCKET_FOLDER_NAME, SOCKET_FILE_NAME);
    if (Buffer.byteLength(path) > MAX_SOCKET_PATH_BYTES) {
        throw new Error(`${path} is longer than a socket path can be (${MAX_SOCKET_PATH_BYTES} bytes).`);
    }

    return path;
}

function send(socket: Socket, body: { reply: string } | { error: string }): void {
    socket.end(`${JSON.stringify(body)}\n`);
}

function handleConnection(channel: Channel, socket: Socket): void {
    const abort = new AbortController();
    let buffer = Buffer.alloc(0);
    let handled = false;

    socket.on("close", () => abort.abort(new Error("The caller hung up.")));
    socket.on("error", () => abort.abort(new Error("The connection failed.")));

    socket.on("data", (chunk: Buffer) => {
        if (handled) {
            return;
        }

        buffer = Buffer.concat([buffer, chunk]);
        const newline = buffer.indexOf(0x0a);

        if (newline === -1) {
            if (buffer.length > MAX_LINE_BYTES) {
                handled = true;
                send(socket, { error: "message is too long" });
            }
            return;
        }

        handled = true;
        const message = parseMessage(buffer.subarray(0, newline).toString("utf8"));
        if (!message.ok) {
            send(socket, { error: message.reason });
            return;
        }

        channel.ask(message.text, abort.signal).then(
            (reply) => send(socket, { reply }),
            () => {
                if (!socket.destroyed) {
                    send(socket, { error: "the message could not be delivered" });
                }
            },
        );
    });
}

// Says whether something is already listening on the socket path.
function isListening(path: string): Promise<boolean> {
    return new Promise((resolve) => {
        const probe = connect(path);
        probe.once("connect", () => {
            probe.destroy();
            resolve(true);
        });
        probe.once("error", () => resolve(false));
    });
}

// Clears a socket file left by a channel that has gone, and refuses to
// start beside one that is still running.
async function clearStaleSocket(path: string): Promise<void> {
    let isSocket: boolean;

    try {
        isSocket = (await lstat(path)).isSocket();
    } catch {
        return;
    }

    if (!isSocket) {
        throw new Error(`${path} exists and is not a socket, so it is left alone.`);
    }

    if (await isListening(path)) {
        throw new Error(`Another voice channel is already listening on ${path}.`);
    }

    await unlink(path);
}

export async function listenOnSocket(channel: Channel, path: string): Promise<Server> {
    const folder = join(path, "..");

    await mkdir(folder, { recursive: true, mode: 0o700 });
    await chmod(folder, 0o700);
    await clearStaleSocket(path);

    const server = createServer((socket) => handleConnection(channel, socket));

    await new Promise<void>((resolve, reject) => {
        server.once("error", reject);
        server.listen(path, () => resolve());
    });
    await chmod(path, 0o600);

    return server;
}
