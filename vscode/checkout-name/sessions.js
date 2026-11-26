// @ts-check
"use strict";

// The sessions a window can have open as tabs, each by a short key: "claude"
// for the checkout's Claude session, "tmux" for its first plain shell, and
// "tmux-2" to "tmux-99" for the shells beside it. Kept apart from
// extension.js so it can be tested without VS Code.
//
// A window keeps the keys of its open tabs in its saved state, because a tab
// cannot survive a reload with its picture: VS Code restores a terminal
// without its icon. So the tabs are not restored at all, and the extension
// opens them again from the keys as the window starts.
//
// The keys say which tabs were open, not where each one was. So a window
// with shells and Claude open gets them back in one fixed place: the shells
// on the left and Claude on the right.

/**
 * The side of the editor area a reopened tab is sent to.
 * @typedef {"left" | "right"} Side
 */

/** The key of the checkout's Claude session. */
const CLAUDE = "claude";

/** The key of the checkout's first plain shell. */
const FIRST_SHELL = "tmux";

/** The numbers a shell beside the first can take, as `just tw` allows. */
const SECOND_SHELL = 2;
const LAST_SHELL = 99;

/** A later shell's key, with its number in the one group. */
const LATER_SHELL = /^tmux-([2-9]|[1-9][0-9])$/;

/**
 * Whether a string is a session's key.
 * @param {unknown} key
 * @returns {key is string}
 */
function isSessionKey(key) {
    return typeof key === "string" && (key === CLAUDE || key === FIRST_SHELL || LATER_SHELL.test(key));
}

/**
 * The global just recipe, with its argument, that takes a terminal to a
 * session.
 * @param {string} key
 * @returns {string}
 */
function sessionRecipe(key) {
    if (!isSessionKey(key)) {
        throw new Error(`"${key}" is not a session: expected claude, tmux, or tmux-2 to tmux-99`);
    }

    if (key === CLAUDE) {
        return "claude-session";
    }

    const number = LATER_SHELL.exec(key)?.[1];

    return number === undefined ? "tmux-window" : `tmux-window ${number}`;
}

/**
 * The key of the first shell beside the first that the window has no tab
 * for, from 2 up, or undefined when it has a tab for every one.
 * @param {Iterable<string>} open
 * @returns {string | undefined}
 */
function nextShellKey(open) {
    const taken = new Set(open);

    for (let number = SECOND_SHELL; number <= LAST_SHELL; number++) {
        const key = `tmux-${number}`;
        if (!taken.has(key)) {
            return key;
        }
    }

    return undefined;
}

/**
 * The session keys in a window's saved state, in order, without repeats.
 * Anything that is not a key is dropped: the state is read back from disk,
 * and may be from another version of the extension.
 * @param {unknown} stored
 * @returns {string[]}
 */
function storedSessions(stored) {
    if (!Array.isArray(stored)) {
        return [];
    }

    return [...new Set(stored.filter(isSessionKey))];
}

/**
 * The tabs to open again as a window starts, in the order to open them, each
 * with the side it goes to. With shells and Claude both saved, the shells
 * come first, on the left, and Claude last, on the right, whatever order
 * they were first opened in. Given no side, VS Code opens each tab in the
 * column that is active as the window starts, and the two were seen to
 * come back on each other's side. A window with only shells, or only
 * Claude, has nothing to set side by side, so its tabs get no side and
 * open where VS Code puts them.
 * @param {unknown} stored
 * @returns {Array<{session: string, side: Side | undefined}>}
 */
function reopenedTabs(stored) {
    const sessions = storedSessions(stored);
    const shells = sessions.filter((session) => session !== CLAUDE);

    if (shells.length === 0 || shells.length === sessions.length) {
        return sessions.map((session) => ({ session, side: undefined }));
    }

    /** @type {Array<{session: string, side: Side | undefined}>} */
    const tabs = shells.map((session) => ({ session, side: "left" }));
    tabs.push({ session: CLAUDE, side: "right" });

    return tabs;
}

module.exports = { CLAUDE, FIRST_SHELL, isSessionKey, nextShellKey, reopenedTabs, sessionRecipe, storedSessions };
