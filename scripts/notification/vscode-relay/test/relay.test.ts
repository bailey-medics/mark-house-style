// Tests for the banner relay's logic. The parts that need VS Code, reading
// the box's file and running the Mac's scripts, are left to a real window.

import assert from "node:assert/strict";
import { test } from "node:test";

import {
    boxFromAuthority,
    isBox,
    lastLines,
    lockLine,
    mayRelay,
    queueFromFolders,
    startedLine,
    stateFile,
} from "../src/relay.ts";

test("an SSH connection gives the host as the box", () => {
    assert.equal(boxFromAuthority("ssh-remote+devbox"), "devbox");
});

test("a tunnel connection keeps its prefix, so a click looks for a tunnel window", () => {
    assert.equal(boxFromAuthority("tunnel+devbox-tunnel"), "tunnel+devbox-tunnel");
});

test("any other connection, or none, gives no box", () => {
    assert.equal(boxFromAuthority(undefined), undefined);
    assert.equal(boxFromAuthority("wsl+Ubuntu"), undefined);
    assert.equal(boxFromAuthority("dev-container+abc"), undefined);
});

test("a box name that could reach a program as an option or command is refused", () => {
    assert.equal(boxFromAuthority("ssh-remote+-oProxyCommand=x"), undefined);
    assert.equal(boxFromAuthority("ssh-remote+box;reboot"), undefined);
    assert.equal(isBox("tunnel+-x"), false);
    assert.equal(isBox("devbox"), true);
});

test("the queue is found under the home of an open remote folder", () => {
    assert.equal(
        queueFromFolders(["/home/dev/github/turva-5"]),
        "/home/dev/.local/state/quill-notify/banners.jsonl",
    );
    assert.equal(queueFromFolders(["/root/work"]), "/root/.local/state/quill-notify/banners.jsonl");
});

test("with no folder under a home, there is no queue", () => {
    assert.equal(queueFromFolders([]), undefined);
    assert.equal(queueFromFolders(["/srv/app", "/tmp"]), undefined);
});

test("only the last lines are passed on, blank ones dropped", () => {
    assert.deepEqual(lastLines("a\nb\n\nc\nd\n", 2), ["c", "d"]);
    assert.deepEqual(lastLines("", 20), []);
});

test("a window may relay when there is no lock, or the lock is its own", () => {
    assert.equal(mayRelay(undefined, "me", 1000, 15000), true);
    assert.equal(mayRelay(lockLine("me", 0), "me", 1000, 15000), true);
});

test("another window's fresh lock keeps this one out", () => {
    assert.equal(mayRelay(lockLine("other", 10_000), "me", 20_000, 15_000), false);
});

test("another window's stale or unreadable lock is taken over", () => {
    assert.equal(mayRelay(lockLine("other", 0), "me", 20_000, 15_000), true);
    assert.equal(mayRelay("rubbish", "me", 20_000, 15_000), true);
});

test("the shown record is shared with Quill Medical's listener when it is installed", () => {
    assert.equal(stateFile("/Users/m", true), "/Users/m/Library/Caches/quill-notifier/last-shown");
});

test("otherwise the shown record is shared with this repository's listener", () => {
    assert.equal(stateFile("/Users/m", false), "/Users/m/Library/Caches/turva-notifier/last-shown");
});

test("the Output panel's first line names the version that started", () => {
    assert.equal(startedLine("0.2.1"), "Banner relay 0.2.1 started.");
});

test("a version that is missing or not a plain version is called unknown", () => {
    assert.equal(startedLine(undefined), "Banner relay started, version unknown.");
    assert.equal(startedLine(21), "Banner relay started, version unknown.");
    assert.equal(startedLine("0.2.1\nNo banner scripts"), "Banner relay started, version unknown.");
});
