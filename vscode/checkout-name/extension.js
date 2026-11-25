// @ts-check
"use strict";

// Gives VS Code a title variable, ${checkoutName}, holding a short name for
// the checkout the window has open, such as Quill-2. package.json makes that
// variable the window's title, and the search box in the title bar shows the
// title whenever it has been changed from VS Code's own.
//
// It also opens two kinds of terminal, a Claude session and a plain tmux
// shell, each with its own icon and coloured for the project. VS Code sets a
// terminal's icon only as it opens and has no way to change it afterwards,
// so a terminal has to be opened from here to carry one: from the panel
// behind the icon in the activity bar, from the buttons above the editor
// tabs, or from the Command Palette.

const path = require("node:path");
const vscode = require("vscode");
const { checkoutName } = require("./names");
const { KINDS, terminalSpec } = require("./terminals");

/** The variable's name in `window.title`, and the context key behind it. */
const VARIABLE = "checkoutName";

/** The panel behind the activity bar icon. The id matches package.json. */
const SESSIONS_VIEW = "checkoutName.sessions";

/**
 * The terminal profiles and commands, by kind. The ids match package.json.
 * @type {ReadonlyArray<{kind: import("./terminals").TerminalKind, profile: string, command: string}>}
 */
const TERMINALS = [
    { kind: "claude", profile: "checkoutName.claude", command: "checkoutName.openClaude" },
    { kind: "tmux", profile: "checkoutName.tmux", command: "checkoutName.openTmux" },
];

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
 * The options a terminal of one kind opens with, for the window's checkout.
 * @param {import("./terminals").TerminalKind} kind
 * @returns {import("vscode").TerminalOptions}
 */
function terminalOptions(kind) {
    const spec = terminalSpec(kind, openFolder());

    return {
        shellPath: spec.shellPath,
        shellArgs: spec.shellArgs,
        cwd: firstFolder()?.uri,
        iconPath: new vscode.ThemeIcon(spec.icon),
        color: new vscode.ThemeColor(spec.colour),
    };
}

/**
 * Opens a terminal of one kind as a tab in the editor area, beside the files.
 * @param {import("./terminals").TerminalKind} kind
 * @returns {void}
 */
function openInEditor(kind) {
    const terminal = vscode.window.createTerminal({
        ...terminalOptions(kind),
        location: vscode.TerminalLocation.Editor,
    });

    terminal.show();
}

/**
 * One row of the panel: a kind of terminal, with its icon in the project's
 * colour. Clicking the row opens the terminal.
 * @param {typeof TERMINALS[number]} entry
 * @returns {import("vscode").TreeItem}
 */
function sessionRow({ kind, command }) {
    const { label } = KINDS[kind];
    const spec = terminalSpec(kind, openFolder());
    const row = new vscode.TreeItem(label);

    row.iconPath = new vscode.ThemeIcon(spec.icon, new vscode.ThemeColor(spec.colour));
    row.command = { command, title: label };

    return row;
}

/**
 * The panel's rows, one for each kind of terminal.
 * @type {import("vscode").TreeDataProvider<typeof TERMINALS[number]>}
 */
const sessionRows = {
    getTreeItem: sessionRow,
    getChildren: (entry) => (entry === undefined ? [...TERMINALS] : []),
};

/**
 * Runs as the window starts. The name is set before the variable is made
 * known, so the title never shows a variable with nothing behind it.
 * @param {import("vscode").ExtensionContext} context
 * @returns {Promise<void>}
 */
async function activate(context) {
    await update();
    await vscode.commands.executeCommand("registerWindowTitleVariable", VARIABLE, VARIABLE);

    context.subscriptions.push(
        vscode.workspace.onDidChangeWorkspaceFolders(update),
        vscode.window.registerTreeDataProvider(SESSIONS_VIEW, sessionRows),
    );

    for (const { kind, profile, command } of TERMINALS) {
        context.subscriptions.push(
            vscode.window.registerTerminalProfileProvider(profile, {
                provideTerminalProfile: () => new vscode.TerminalProfile(terminalOptions(kind)),
            }),
            vscode.commands.registerCommand(command, () => openInEditor(kind)),
        );
    }
}

/** @returns {void} */
function deactivate() {}

module.exports = { activate, deactivate };
