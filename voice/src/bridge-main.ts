// Starts the bridge on loopback. scripts/test-window.sh runs it, with a
// fresh path secret each time:
//
//   VOICE_BRIDGE_PATH_SECRET=<32 hex characters> node src/bridge-main.ts

import { createBridge, isPathSecret } from "./bridge.ts";
import { askChannel } from "./socket-client.ts";
import { socketPath } from "./socket.ts";

const pathSecret = process.env.VOICE_BRIDGE_PATH_SECRET;
if (!isPathSecret(pathSecret)) {
    console.error("VOICE_BRIDGE_PATH_SECRET must be 32 lowercase hex characters.");
    process.exit(2);
}

const port = Number(process.env.VOICE_BRIDGE_PORT ?? "8787");
const askWaitSeconds = Number(process.env.VOICE_ASK_WAIT_SECONDS ?? "25");
if (!Number.isInteger(port) || port < 1024 || port > 65535 || !(askWaitSeconds > 0)) {
    console.error("VOICE_BRIDGE_PORT or VOICE_ASK_WAIT_SECONDS is not valid.");
    process.exit(2);
}

const channel = socketPath(process.env.XDG_RUNTIME_DIR);
const log = (line: string): void => console.error(`${new Date().toISOString()} ${line}`);

const bridge = createBridge({
    pathSecret,
    ask: (text) => askChannel(channel, text),
    askWaitMs: askWaitSeconds * 1000,
    log,
});

bridge.listen(port, "127.0.0.1", () => log(`bridge listening on 127.0.0.1:${port}`));

const stop = (): void => {
    bridge.close();
    process.exit(0);
};

process.on("SIGTERM", stop);
process.on("SIGINT", stop);
