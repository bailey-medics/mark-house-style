// @ts-check
"use strict";

// Tests for sessions.js, which names the sessions a window can have open as
// tabs and says how each is reached.

const assert = require("node:assert/strict");
const { test } = require("node:test");
const {
    CLAUDE,
    FIRST_SHELL,
    isSessionKey,
    nextShellKey,
    reopenedTabs,
    sessionRecipe,
    storedSessions,
} = require("../sessions");

test("the Claude session and the first shell have keys of their own", () => {
    assert.equal(CLAUDE, "claude");
    assert.equal(FIRST_SHELL, "tmux");
});

/** @type {ReadonlyArray<readonly [string, string]>} */
const RECIPES = [
    ["claude", "claude-session"],
    ["tmux", "tmux-window"],
    ["tmux-2", "tmux-window 2"],
    ["tmux-12", "tmux-window 12"],
    ["tmux-99", "tmux-window 99"],
];

for (const [session, recipe] of RECIPES) {
    test(`${session} is reached by just -g ${recipe}`, () => {
        assert.equal(sessionRecipe(session), recipe);
    });
}

test("only the keys just tw allows are sessions", () => {
    for (const key of ["tmux-1", "tmux-0", "tmux-02", "tmux-100", "tmux-", "claude-2", "Claude", "", " tmux"]) {
        assert.equal(isSessionKey(key), false, `"${key}" was taken for a session`);
    }

    for (const key of [undefined, null, 2, ["tmux"], { key: "tmux" }]) {
        assert.equal(isSessionKey(key), false);
    }
});

test("a recipe is refused for anything that is not a session, so nothing else reaches the shell", () => {
    assert.throws(() => sessionRecipe("tmux-2; rm -rf ~"), /is not a session/);
    assert.throws(() => sessionRecipe("next"), /is not a session/);
});

test("another shell is the second when the window has none beside the first", () => {
    assert.equal(nextShellKey([]), "tmux-2");
    assert.equal(nextShellKey(["claude", "tmux"]), "tmux-2");
});

test("another shell passes over the ones the window has a tab for", () => {
    assert.equal(nextShellKey(["tmux", "tmux-2"]), "tmux-3");
    assert.equal(nextShellKey(["tmux-2", "tmux-3", "tmux-4"]), "tmux-5");
});

test("another shell fills a gap left by a closed tab", () => {
    assert.equal(nextShellKey(["tmux-2", "tmux-4"]), "tmux-3");
    assert.equal(nextShellKey(["tmux-3"]), "tmux-2");
});

test("there is no other shell when the window has a tab for every one", () => {
    const every = Array.from({ length: 98 }, (_, index) => `tmux-${index + 2}`);

    assert.equal(nextShellKey(every), undefined);
});

test("the saved sessions come back in order", () => {
    assert.deepEqual(storedSessions(["tmux", "claude", "tmux-3"]), ["tmux", "claude", "tmux-3"]);
});

test("a repeated session is saved once, so it gets one tab", () => {
    assert.deepEqual(storedSessions(["claude", "tmux", "claude"]), ["claude", "tmux"]);
});

test("anything in the saved state that is not a session is dropped", () => {
    assert.deepEqual(storedSessions(["claude", "anotherTmux", 3, null, "tmux-2; ls", "tmux-2"]), ["claude", "tmux-2"]);
});

test("saved state that is not a list gives no sessions", () => {
    for (const stored of [undefined, null, "claude", 7, { 0: "claude" }]) {
        assert.deepEqual(storedSessions(stored), []);
    }
});

test("a shell and Claude come back side by side, the shell on the left and Claude on the right", () => {
    assert.deepEqual(reopenedTabs(["tmux", "claude"]), [
        { session: "tmux", side: "left" },
        { session: "claude", side: "right" },
    ]);
});

test("the sides do not follow which tab was opened first", () => {
    assert.deepEqual(reopenedTabs(["claude", "tmux"]), [
        { session: "tmux", side: "left" },
        { session: "claude", side: "right" },
    ]);
});

test("every shell comes back on the left, in the order they were opened, and Claude is opened last", () => {
    assert.deepEqual(reopenedTabs(["tmux-3", "claude", "tmux"]), [
        { session: "tmux-3", side: "left" },
        { session: "tmux", side: "left" },
        { session: "claude", side: "right" },
    ]);
});

test("a window with only Claude open gives its tab no side, so no column is made for it", () => {
    assert.deepEqual(reopenedTabs(["claude"]), [{ session: "claude", side: undefined }]);
});

test("a window with only shells open gives their tabs no side", () => {
    assert.deepEqual(reopenedTabs(["tmux", "tmux-2"]), [
        { session: "tmux", side: undefined },
        { session: "tmux-2", side: undefined },
    ]);
});

test("what is not a session in the saved state gets no tab, and does not make a window side by side", () => {
    assert.deepEqual(reopenedTabs(["claude", "anotherTmux", "claude", 3]), [{ session: "claude", side: undefined }]);
});

test("saved state with no session in it opens nothing again", () => {
    for (const stored of [undefined, null, [], ["next"], "claude"]) {
        assert.deepEqual(reopenedTabs(stored), []);
    }
});
