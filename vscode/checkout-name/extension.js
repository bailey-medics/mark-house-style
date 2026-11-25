// @ts-check
"use strict";

// Gives VS Code a title variable, ${checkoutName}, holding a short name for
// the checkout the window has open, such as Quill-2. package.json makes that
// variable the window's title, and the search box in the title bar shows the
// title whenever it has been changed from VS Code's own.

const path = require("node:path");
const vscode = require("vscode");
const { checkoutName } = require("./names");

/** The variable's name in `window.title`, and the context key behind it. */
const VARIABLE = "checkoutName";

/**
 * The name of the first folder the window has open, or "" with none open.
 * @returns {string}
 */
function openFolder() {
    const folder = vscode.workspace.workspaceFolders?.[0];

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
 * Runs as the window starts. The name is set before the variable is made
 * known, so the title never shows a variable with nothing behind it.
 * @param {import("vscode").ExtensionContext} context
 * @returns {Promise<void>}
 */
async function activate(context) {
    await update();
    await vscode.commands.executeCommand("registerWindowTitleVariable", VARIABLE, VARIABLE);

    context.subscriptions.push(vscode.workspace.onDidChangeWorkspaceFolders(update));
}

/** @returns {void} */
function deactivate() {}

module.exports = { activate, deactivate };
