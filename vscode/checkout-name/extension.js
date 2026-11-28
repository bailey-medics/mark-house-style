// @ts-check
"use strict";

// Gives VS Code a title variable, ${checkoutName}, holding a short name for
// the checkout the window has open, such as Quill-2. package.json makes that
// variable the window's title, and the search box in the title bar shows the
// title whenever it has been changed from VS Code's own.
//
// It also opens the checkout's Claude session, its plain tmux shell, or
// another tmux shell beside it, as a tab in the editor area with the
// project's banner icon on it. VS Code sets a terminal's icon only as the
// terminal opens and has no way to change it afterwards, so a terminal has
// to be opened from here to carry one: from the panel behind the icon in the
// activity bar, or from the buttons above the editor tabs. Another tmux
// shell is the tmux button clicked with Alt held down. package.json keeps
// the commands out of the Command Palette.
//
// A session has one tab in a window: opening it again shows that tab. And
// the tabs come back after "Developer: Reload Window", which they could not
// do if VS Code restored them, because it restores a terminal without its
// icon. So they are opened as transient, which VS Code does not restore, and
// the window's saved state keeps which sessions were open, to be opened
// again as it starts. tmux holds each session, so a tab comes back where it
// left off. The saved state does not keep where a tab was, so shells and
// Claude come back side by side: sessions.js says which goes where.

const fs = require("node:fs");
const path = require("node:path");
const vscode = require("vscode");
const { checkoutName } = require("./names");
const { CLAUDE, FIRST_SHELL, nextShellKey, reopenedTabs } = require("./sessions");
const { KINDS, pictureAddress, terminalSpec } = require("./terminals");

/** The variable's name in `window.title`, and the context key behind it. */
const VARIABLE = "checkoutName";

/** The folder of banner icons in the installed extension. */
const ICONS_FOLDER = "icons";

/** The panel behind the activity bar icon. The id matches package.json. */
const SESSIONS_VIEW = "checkoutName.sessions";

/** Where the window's saved state keeps the keys of its open sessions. */
const OPEN_SESSIONS = "checkoutName.openSessions";

/**
 * How long a closed tab's session stays in the saved state, in milliseconds.
 * A reload closes the tabs too, and their sessions have to stay in the list
 * to be opened again. VS Code says when a tab closed because the window is
 * shutting down, and that is checked first. The wait covers a close it gives
 * no reason for: a reload ends the extension before the wait is over, and a
 * tab closed by hand does not.
 */
const FORGET_AFTER = 1500;

/**
 * How long to wait for a reopened tab's terminal to start before opening the
 * next, in milliseconds. Several terminals opened in one burst as a window
 * starts leave all but the last with no process behind them: a blank tab
 * that never comes to life. So they are opened one at a time.
 */
const START_WITHIN = 5000;

/**
 * The editor column for each side a reopened tab can be sent to. VS Code
 * makes the second column when the window has only one.
 * @type {Readonly<Record<import("./sessions").Side, import("vscode").ViewColumn>>}
 */
const COLUMNS = { left: vscode.ViewColumn.One, right: vscode.ViewColumn.Two };

/**
 * Each kind's command. The ids match package.json.
 * @type {ReadonlyArray<{kind: import("./terminals").TerminalKind, command: string}>}
 */
const KIND_COMMANDS = [
    { kind: "claude", command: "checkoutName.openClaude" },
    { kind: "tmux", command: "checkoutName.openTmux" },
    { kind: "anotherTmux", command: "checkoutName.openAnotherTmux" },
];

/**
 * The tabs this window has open, by their session's key.
 * @type {Map<string, import("vscode").Terminal>}
 */
const openTabs = new Map();

/**
 * Each picture already read, by its file name: its address, or undefined
 * for one that could not be read.
 * @type {Map<string, import("vscode").Uri | undefined>}
 */
const pictures = new Map();

/**
 * The first folder the window has open, or undefined with none open.
 * @returns {import("vscode").WorkspaceFolder | undefined}
 */
function firstFolder() {
    return vscode.workspace.workspaceFolders?.[0];
}

/**
 * The name of the first folder the window has open, or "" with none open.
 * @returns {string}
 */
function openFolder() {
    const folder = firstFolder();

    return folder ? path.posix.basename(folder.uri.path) : "";
}

/**
 * Hands VS Code the short name for what the window has open now.
 * @returns {Promise<void>}
 */
async function update() {
    const folder = openFolder();
    const name = folder === "" ? "" : checkoutName(folder);

    await vscode.commands.executeCommand("setContext", VARIABLE, name);
}

/**
 * A picture as an address that holds the picture itself, so the window has
 * nothing to fetch: terminals.js says why. Undefined when the file cannot be
 * read, and the terminal then opens with a built-in icon.
 * @param {string} image
 * @param {import("vscode").Uri} extensionUri
 * @returns {import("vscode").Uri | undefined}
 */
function picture(image, extensionUri) {
    if (pictures.has(image)) {
        return pictures.get(image);
    }

    /** @type {import("vscode").Uri | undefined} */
    let address;

    try {
        const bytes = fs.readFileSync(path.join(extensionUri.fsPath, ICONS_FOLDER, image));
        address = vscode.Uri.parse(pictureAddress(bytes), true);
    } catch (error) {
        const reason = error instanceof Error ? error.message : String(error);
        console.warn(`checkout-name: no picture for the tab, ${image}: ${reason}`);
    }

    pictures.set(image, address);

    return address;
}

/**
 * The options a session's terminal opens with, for the window's checkout: a
 * tab in the editor area, with the project's banner icon, that VS Code does
 * not restore. Given a side, the tab opens in that side's column without
 * taking the keyboard; given none, in the column that is active.
 * @param {string} session
 * @param {import("vscode").Uri} extensionUri
 * @param {import("./sessions").Side} [side]
 * @returns {import("vscode").TerminalOptions}
 */
function terminalOptions(session, extensionUri, side) {
    const spec = terminalSpec(session, openFolder());
    const address = picture(spec.image, extensionUri);

    return {
        shellPath: spec.shellPath,
        shellArgs: spec.shellArgs,
        cwd: firstFolder()?.uri,
        iconPath: address ?? new vscode.ThemeIcon(spec.icon),
        isTransient: true,
        location: side === undefined ? vscode.TerminalLocation.Editor : { viewColumn: COLUMNS[side], preserveFocus: true },
    };
}

/**
 * Writes the keys of the open tabs to the window's saved state.
 * @param {import("vscode").ExtensionContext} context
 * @returns {void}
 */
function remember(context) {
    // Nothing waits on the write: the state is read only as a window starts.
    void context.workspaceState.update(OPEN_SESSIONS, [...openTabs.keys()]);
}

/**
 * Shows a session's tab, opening it when the window has none for it. A side
 * says where a new tab opens, and does not move a tab that is already open.
 * @param {string} session
 * @param {import("vscode").ExtensionContext} context
 * @param {boolean} takeFocus
 * @param {import("./sessions").Side} [side]
 * @returns {import("vscode").Terminal}
 */
function showSession(session, context, takeFocus, side) {
    let tab = openTabs.get(session);

    if (tab === undefined) {
        tab = vscode.window.createTerminal(terminalOptions(session, context.extensionUri, side));
        openTabs.set(session, tab);
        remember(context);
    }

    tab.show(!takeFocus);

    return tab;
}

/**
 * Waits until a tab's terminal has started, or the wait runs out.
 * @param {import("vscode").Terminal} tab
 * @returns {Promise<void>}
 */
async function started(tab) {
    /** @type {NodeJS.Timeout | undefined} */
    let timer;
    const gaveUp = new Promise((resolve) => {
        timer = setTimeout(resolve, START_WITHIN);
    });

    await Promise.race([tab.processId, gaveUp]);
    clearTimeout(timer);
}

/**
 * Opens again the sessions that were open when the window last shut, one at
 * a time, the last of them in front, without taking the keyboard from the
 * editor. Shells and Claude come back side by side, as sessions.js sets out.
 * @param {import("vscode").ExtensionContext} context
 * @returns {Promise<void>}
 */
async function reopen(context) {
    for (const { session, side } of reopenedTabs(context.workspaceState.get(OPEN_SESSIONS))) {
        await started(showSession(session, context, false, side));
    }
}

/**
 * Opens what a row or a button stands for. Another tmux shell is the first
 * one, from 2 up, that the window has no tab for.
 * @param {import("./terminals").TerminalKind} kind
 * @param {import("vscode").ExtensionContext} context
 * @returns {void}
 */
function open(kind, context) {
    if (kind === "claude") {
        showSession(CLAUDE, context, true);
        return;
    }

    if (kind === "tmux") {
        showSession(FIRST_SHELL, context, true);
        return;
    }

    const session = nextShellKey(openTabs.keys());

    if (session === undefined) {
        void vscode.window.showWarningMessage("Every tmux shell of this checkout already has a tab in this window.");
        return;
    }

    showSession(session, context, true);
}

/**
 * Forgets a tab that has closed. Its session leaves the saved state too,
 * unless the window is shutting down: those are the tabs to open again.
 * @param {import("vscode").Terminal} closed
 * @param {import("vscode").ExtensionContext} context
 * @returns {void}
 */
function forget(closed, context) {
    for (const [session, tab] of openTabs) {
        if (tab === closed) {
            openTabs.delete(session);
        }
    }

    if (closed.exitStatus?.reason === vscode.TerminalExitReason.Shutdown) {
        return;
    }

    setTimeout(() => remember(context), FORGET_AFTER);
}

/**
 * One row of the panel: a kind of terminal, with its icon. Clicking the row
 * opens the terminal.
 * @param {typeof KIND_COMMANDS[number]} entry
 * @returns {import("vscode").TreeItem}
 */
function sessionRow({ kind, command }) {
    const { label, icon } = KINDS[kind];
    const row = new vscode.TreeItem(label);

    row.iconPath = new vscode.ThemeIcon(icon);
    row.command = { command, title: label };

    return row;
}

/**
 * The panel's rows, one for each kind of terminal.
 * @type {import("vscode").TreeDataProvider<typeof KIND_COMMANDS[number]>}
 */
const sessionRows = {
    getTreeItem: sessionRow,
    getChildren: (entry) => (entry === undefined ? [...KIND_COMMANDS] : []),
};

/**
 * Runs as the window starts. The name is set before the variable is made
 * known, so the title never shows a variable with nothing behind it. The
 * sessions that were open when the window last shut are then opened again,
 * which the start-up does not wait for.
 * @param {import("vscode").ExtensionContext} context
 * @returns {Promise<void>}
 */
async function activate(context) {
    await update();
    await vscode.commands.executeCommand("registerWindowTitleVariable", VARIABLE, VARIABLE);

    context.subscriptions.push(
        vscode.workspace.onDidChangeWorkspaceFolders(update),
        vscode.window.registerTreeDataProvider(SESSIONS_VIEW, sessionRows),
        vscode.window.onDidCloseTerminal((closed) => forget(closed, context)),
    );

    for (const { kind, command } of KIND_COMMANDS) {
        context.subscriptions.push(vscode.commands.registerCommand(command, () => open(kind, context)));
    }

    // Not awaited: each tab waits for the one before, and the window should
    // not wait on them to finish starting.
    void reopen(context);
}

/** @returns {void} */
function deactivate() {}

module.exports = { activate, deactivate };
