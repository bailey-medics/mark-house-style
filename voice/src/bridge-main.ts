// Starts the bridge on loopback. It will not start without a login that
// is valid and has not expired; scripts/voice-init.ts makes one.
//
//   node src/bridge-main.ts

import { createBridge } from "./bridge.ts";
import { isExpired, loadLogin, loginFilePath, LoginError } from "./login.ts";
import { askChannel } from "./socket-client.ts";
import { socketPath } from "./socket.ts";

const port = Number(process.env.VOICE_BRIDGE_PORT ?? "8787");
const askWaitSeconds = Number(process.env.VOICE_ASK_WAIT_SECONDS ?? "25");
if (!Number.isInteger(port) || port < 1024 || port > 65535 || !(askWaitSeconds > 0)) {
    console.error("VOICE_BRIDGE_PORT or VOICE_ASK_WAIT_SECONDS is not valid.");
    process.exit(2);
}

let loginPath: string;
try {
    loginPath = loginFilePath(process.env);

    if (isExpired(loadLogin(loginPath), new Date())) {
        throw new LoginError("The login has expired. Run scripts/voice-init.ts --replace to make a new one.");
    }
} catch (error) {
    if (!(error instanceof LoginError)) {
        throw error;
    }

    console.error(error.message);
    process.exit(2);
}

const channel = socketPath(process.env.XDG_RUNTIME_DIR);
const log = (line: string): void => console.error(`${new Date().toISOString()} ${line}`);

const bridge = createBridge({
    loginPath,
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
