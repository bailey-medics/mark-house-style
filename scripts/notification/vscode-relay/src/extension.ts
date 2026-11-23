// Banner relay: shows the dev box's finished-response banners on the Mac,
// through the connection VS Code already holds to the box.
//
// notification-listen.sh fetches banners over SSH, which needs the Mac to
// reach the box directly. Where that is blocked, VS Code's own connection,
// over Remote-SSH or a VS Code tunnel, still works. This extension runs on
// the Mac side of it ("extensionKind": ["ui"]), reads the queue file on the
// box through that connection every few seconds, and pipes the last lines
// to the Mac's notification-queue.py, which checks every field, skips what
// it has already shown, and calls notification-show.sh. It shares that
// script's record of what was shown with the SSH listener, so a banner
// shows once whichever way it arrives.
//
// The box still never connects to the Mac, and what it sends is text.

import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import * as vscode from "vscode";

import { boxFromAuthority, isBox, lastLines, lockLine, mayRelay, queueFromFolders, stateFile } from "./relay.ts";

const LINES = 20;
const STALE_MS = 15_000;
const SHOW_TIMEOUT_MS = 60_000;

let running = false;
const warned = new Set<string>();

export function activate(context: vscode.ExtensionContext): void {
    // Only on a Mac, and only in a window connected to a box.
    if (process.platform !== "darwin" || vscode.env.remoteName === undefined) {
        return;
    }

    const output = vscode.window.createOutputChannel("Banner relay");
    const seconds = vscode.workspace.getConfiguration("bannerRelay").get<number>("intervalSeconds", 3);
    const timer = setInterval(() => void tick(output), Math.max(1, seconds) * 1000);

    context.subscriptions.push(output, { dispose: () => clearInterval(timer) });
}

export function deactivate(): void {}

function warnOnce(output: vscode.OutputChannel, key: string, message: string): void {
    if (!warned.has(key)) {
        warned.add(key);
        output.appendLine(message);
    }
}

async function tick(output: vscode.OutputChannel): Promise<void> {
    if (running) {
        return;
    }

    running = true;

    try {
        await relay(output);
    } catch (error) {
        warnOnce(output, "error", `Relay stopped a round: ${String(error)}`);
    } finally {
        running = false;
    }
}

async function relay(output: vscode.OutputChannel): Promise<void> {
    const config = vscode.workspace.getConfiguration("bannerRelay");

    // The connection comes from an open remote folder's address, such as
    // vscode-remote://tunnel+devbox-tunnel/home/..., which VS Code's public
    // API offers where it does not offer the window's own.
    const remote = (vscode.workspace.workspaceFolders ?? []).filter(
        (folder) => folder.uri.scheme === "vscode-remote",
    );
    const authority = remote[0]?.uri.authority;
    if (authority === undefined) {
        warnOnce(output, "folder", "No remote folder open, so no box to relay from.");
        return;
    }

    const box = config.get<string>("box") || boxFromAuthority(authority);
    if (box === undefined || !isBox(box)) {
        warnOnce(output, "box", `No box name for "${authority}"; set bannerRelay.box.`);
        return;
    }

    // Its own copy of the banner scripts, from `t nri`, so it never depends
    // on which listener the Mac has, or on an older copy of them.
    const scripts = config.get<string>("scriptsDir") || join(homedir(), "Library", "Application Support", "banner-relay");
    const queueScript = join(scripts, "notification-queue.py");
    const showScript = join(scripts, "notification-show.sh");
    if (!existsSync(queueScript) || !existsSync(showScript)) {
        warnOnce(output, "scripts", `No banner scripts in ${scripts}; run \`t nri\` on the Mac again.`);
        return;
    }

    if (!claimLock()) {
        return;
    }

    const folders = remote
        .filter((folder) => folder.uri.authority === authority)
        .map((folder) => folder.uri.path);
    const queue = config.get<string>("queuePath") || queueFromFolders(folders);
    if (queue === undefined) {
        warnOnce(output, "queue", "No remote folder open to find the box's home from; set bannerRelay.queuePath.");
        return;
    }

    let text: string;
    try {
        const bytes = await vscode.workspace.fs.readFile(
            vscode.Uri.from({ scheme: "vscode-remote", authority, path: queue }),
        );
        text = new TextDecoder().decode(bytes);
    } catch {
        return;
    }

    const lines = lastLines(text, LINES);
    if (lines.length > 0) {
        const state = stateFile(
            homedir(),
            existsSync(join(homedir(), "Library", "Application Support", "quill-notify")),
        );
        await show(queueScript, showScript, box, state, lines);
    }
}

// Take, or keep, the turn to relay for this VS Code window.
function claimLock(): boolean {
    const lock = join(homedir(), "Library", "Caches", "turva-notifier", "relay-lock");
    const me = vscode.env.sessionId;
    const now = Date.now();

    let current: string | undefined;
    try {
        current = readFileSync(lock, "utf8");
    } catch {
        current = undefined;
    }

    if (!mayRelay(current, me, now, STALE_MS)) {
        return false;
    }

    try {
        mkdirSync(dirname(lock), { recursive: true });
        writeFileSync(lock, lockLine(me, now));
    } catch {
        return false;
    }

    return true;
}

// The lines go to notification-queue.py on stdin, never through a shell.
function show(
    queueScript: string,
    showScript: string,
    box: string,
    state: string,
    lines: readonly string[],
): Promise<void> {
    return new Promise((resolve) => {
        const child = spawn("python3", [queueScript, "show", "--show-script", showScript, "--box", box, "--state", state], {
            stdio: ["pipe", "ignore", "ignore"],
            env: { ...process.env, PATH: `/opt/homebrew/bin:/usr/local/bin:${process.env.PATH ?? "/usr/bin:/bin"}` },
        });
        const timer = setTimeout(() => child.kill(), SHOW_TIMEOUT_MS);

        child.on("error", () => resolve());
        child.on("close", () => {
            clearTimeout(timer);
            resolve();
        });

        child.stdin.end(lines.join("\n") + "\n");
    });
}
