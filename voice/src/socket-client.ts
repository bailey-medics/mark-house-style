// Sends one message to the voice channel's socket and waits for the
// answer. Used by the bridge and by scripts/push.ts.

import { connect } from "node:net";

export class ChannelError extends Error {}

export function askChannel(path: string, text: string, signal?: AbortSignal): Promise<string> {
    return new Promise((resolve, reject) => {
        const socket = connect(path);
        let answer = "";

        signal?.addEventListener(
            "abort",
            () => {
                socket.destroy();
                reject(signal.reason);
            },
            { once: true },
        );

        socket.on("connect", () => socket.write(`${JSON.stringify({ text })}\n`));
        socket.on("data", (chunk: Buffer) => {
            answer += chunk.toString("utf8");
        });
        socket.on("error", (error) => {
            reject(new ChannelError(`Could not reach the voice channel: ${error.message}`));
        });
        socket.on("end", () => {
            if (answer.trim() === "") {
                reject(new ChannelError("The voice channel closed without answering."));
                return;
            }

            let body: unknown;
            try {
                body = JSON.parse(answer);
            } catch {
                reject(new ChannelError("The voice channel sent something that is not JSON."));
                return;
            }

            if (typeof body === "object" && body !== null && "reply" in body && typeof body.reply === "string") {
                resolve(body.reply);
                return;
            }

            const reason =
                typeof body === "object" && body !== null && "error" in body ? String(body.error) : answer.trim();
            reject(new ChannelError(`The voice channel refused the message: ${reason}`));
        });
    });
}
