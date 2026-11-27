// Tests for when a banner clears itself. Watching the window and running
// the Mac's script are left to a real window.

import assert from "node:assert/strict";
import { test } from "node:test";

import { groupForFolder, groupsForFolders, noteFile, shouldDismiss } from "../src/dismiss.ts";

test("a worktree's group is named after its folder, as notification.sh names it", () => {
    assert.equal(groupForFolder("/home/dev/github/quillmedical-5"), "turva-claude-quillmedical-5");
    assert.equal(groupForFolder("/home/dev/github/turva/"), "turva-claude-turva");
});

test("Juttu's folders are grouped by the session's short name", () => {
    assert.equal(groupForFolder("/home/dev/github/juttu-messaging"), "turva-claude-juttu");
    assert.equal(groupForFolder("/home/dev/github/juttu-messaging-2"), "turva-claude-juttu-2");
});

test("a folder that could not name a group gives none", () => {
    assert.equal(groupForFolder("/"), undefined);
    assert.equal(groupForFolder("/home/dev/my folder"), undefined);
    assert.equal(groupForFolder("/home/dev/a;b"), undefined);
});

test("a window with two folders of one worktree looks for its banner once", () => {
    assert.deepEqual(groupsForFolders(["/a/turva-4", "/b/turva-4", "/c/turva-5", "/"]), [
        "turva-claude-turva-4",
        "turva-claude-turva-5",
    ]);
});

test("the note is looked for where notification-show.sh leaves it", () => {
    assert.equal(noteFile("/Users/m", "turva-claude-turva-4"), "/Users/m/Library/Caches/turva-notifier/banners/turva-claude-turva-4");
});

test("a banner clears once the window and the banner have each been up five seconds", () => {
    assert.equal(shouldDismiss(0, 0, 5_000, 5_000), true);
    assert.equal(shouldDismiss(0, 1_000, 10_000, 5_000), true);
});

test("a banner for the window already in front waits five seconds from when it showed", () => {
    assert.equal(shouldDismiss(0, 8_000, 10_000, 5_000), false);
    assert.equal(shouldDismiss(0, 8_000, 13_000, 5_000), true);
});

test("switching to the window waits five seconds from the switch", () => {
    assert.equal(shouldDismiss(9_000, 0, 10_000, 5_000), false);
    assert.equal(shouldDismiss(9_000, 0, 14_000, 5_000), true);
});

test("nothing clears while the window is not in front, or with no banner up", () => {
    assert.equal(shouldDismiss(undefined, 0, 60_000, 5_000), false);
    assert.equal(shouldDismiss(0, undefined, 60_000, 5_000), false);
});
