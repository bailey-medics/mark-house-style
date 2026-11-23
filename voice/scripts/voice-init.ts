// Makes the voice bridge's login: one secret token, shown once.
//
//   node scripts/voice-init.ts [--days N] [--replace]
//
// Run it in a terminal of your own. It will not run unless its output is
// a terminal, so the token cannot land in a pipe, a log, or the record of
// a program that ran it. The box keeps only the token's hash.

import { lstatSync } from "node:fs";
import {
    DEFAULT_TOKEN_DAYS,
    headerValue,
    issueLogin,
    loginFilePath,
    LoginError,
    MAX_TOKEN_DAYS,
    saveLogin,
} from "../src/login.ts";

type Options = { days: number; replace: boolean };

function stop(message: string, status: 1 | 2): never {
    console.error(message);
    process.exit(status);
}

function readOptions(args: string[]): Options {
    const options: Options = { days: DEFAULT_TOKEN_DAYS, replace: false };

    for (let index = 0; index < args.length; index += 1) {
        const arg = args[index];

        if (arg === "--replace") {
            options.replace = true;
        } else if (arg === "--days") {
            index += 1;
            options.days = Number(args[index]);
        } else {
            stop("Usage: node scripts/voice-init.ts [--days N] [--replace]", 2);
        }
    }

    if (!Number.isInteger(options.days) || options.days < 1 || options.days > MAX_TOKEN_DAYS) {
        stop(`--days takes a whole number from 1 to ${MAX_TOKEN_DAYS}.`, 2);
    }

    return options;
}

function exists(path: string): boolean {
    try {
        lstatSync(path);
        return true;
    } catch {
        return false;
    }
}

if (!process.stdout.isTTY) {
    stop("voice-init shows a secret, so it only runs in a terminal. Nothing was made.", 2);
}

const options = readOptions(process.argv.slice(2));

try {
    const path = loginFilePath(process.env);
    const replaced = exists(path);
    if (replaced && !options.replace) {
        stop("A login already exists. Run again with --replace to make a new one. The old token stops at once.", 1);
    }

    const { token, record } = issueLogin(options.days, new Date());
    saveLogin(path, record);

    const ends = new Date(record.expiresAt).toLocaleString("en-GB", { dateStyle: "long", timeStyle: "short" });
    console.log("");
    console.log("New voice bridge login. The value below is shown once, and is not kept on this box.");
    console.log("");
    console.log("    Header name:   authorization");
    console.log(`    Header value:  ${headerValue(token)}`);
    console.log("");
    console.log(`It works until ${ends}.`);
    console.log("");
    console.log('In claude.ai: Settings, Connectors, Add custom connector. Choose "No sign-in",');
    console.log('and under "Request headers" add the header above.');
    console.log("");
    if (replaced) {
        console.log("The earlier token stopped working just now.");
    }
    console.log("Clear this terminal when you have pasted the value.");
    console.log("");
} catch (error) {
    if (!(error instanceof LoginError)) {
        throw error;
    }

    stop(error.message, 1);
}
