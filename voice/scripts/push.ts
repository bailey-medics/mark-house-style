// Sends one message to the voice channel's socket by hand, and prints the
// reply. For testing the channel on the box:
//
//   node scripts/push.ts "What is in this folder?"

import { askChannel } from "../src/socket-client.ts";
import { socketPath } from "../src/socket.ts";

const text = process.argv.slice(2).join(" ");
if (text === "") {
    console.error('Usage: node scripts/push.ts "your message"');
    process.exit(2);
}

try {
    console.log(await askChannel(socketPath(process.env.XDG_RUNTIME_DIR), text));
} catch (error) {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
}
