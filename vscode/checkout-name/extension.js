// @ts-check
"use strict";

// Gives VS Code a title variable, ${checkoutName}, holding a short name for
// the checkout the window has open, such as Quill-2. package.json makes that
// variable the window's title, and the search box in the title bar shows the
// title whenever it has been changed from VS Code's own.
//
// It also opens a Claude session, the checkout's plain tmux shell, or
// another tmux shell beside it, each with the project's banner icon on its
// tab. VS Code sets a
// terminal's icon only as it opens and has no way to change it afterwards,
// so a terminal has to be opened from here to carry one: from the panel
// behind the icon in the activity bar, or from the buttons above the
// editor tabs. Another tmux shell is the tmux button clicked with Alt held
// down. package.json keeps the commands out of the Command Palette.

const path = require("node:path");
const vscode = require("vscode");
const { checkoutName } = require("./names");
const { KINDS, terminalSpec } = require("./terminals");

/** The variable's name in `window.title`, and the context key behind it. */
const VARIABLE = "checkoutName";

/** The folder of banner icons in the installed extension. */
const ICONS_FOLDER = "icons";

/** The panel behind the activity bar icon. The id matches package.json. */
const SESSIONS_VIEW = "checkoutName.sessions";

/**
 * Each kind's command, and its terminal profile where it has one. The ids
 * match package.json.
 * @type {ReadonlyArray<{kind: import("./terminals").TerminalKind, command: string, profile?: string}>}
 */
const TERMINALS = [
    { kind: "claude", command: "checkoutName.openClaude", profile: "checkoutName.claude" },
    { kind: "tmux", command: "checkoutName.openTmux", profile: "checkoutName.tmux" },
    { kind: "anotherTmux", command: "checkoutName.openAnotherTmux" },
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
 * Its tab's icon is the project's banner icon, from the installed
 * extension's icons folder.
 * @param {import("./terminals").TerminalKind} kind
 * @param {import("vscode").Uri} extensionUri
 * @returns {import("vscode").TerminalOptions}
 */
function terminalOptions(kind, extensionUri) {
    const spec = terminalSpec(kind, openFolder());

    return {
        shellPath: spec.shellPath,
        shellArgs: spec.shellArgs,
        cwd: firstFolder()?.uri,
        iconPath: vscode.Uri.joinPath(extensionUri, ICONS_FOLDER, spec.image),
    };
}

/**
 * Opens a terminal of one kind as a tab in the editor area, beside the files.
 * @param {import("./terminals").TerminalKind} kind
 * @param {import("vscode").Uri} extensionUri
 * @returns {void}
 */
function openInEditor(kind, extensionUri) {
    const terminal = vscode.window.createTerminal({
        ...terminalOptions(kind, extensionUri),
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

    const { extensionUri } = context;

    for (const { kind, profile, command } of TERMINALS) {
        context.subscriptions.push(
            vscode.commands.registerCommand(command, () => openInEditor(kind, extensionUri)),
        );

        if (profile !== undefined) {
            context.subscriptions.push(
                vscode.window.registerTerminalProfileProvider(profile, {
                    provideTerminalProfile: () =>
                        new vscode.TerminalProfile(terminalOptions(kind, extensionUri)),
                }),
            );
        }
    }
}

/** @returns {void} */
function deactivate() {}

module.exports = { activate, deactivate };
