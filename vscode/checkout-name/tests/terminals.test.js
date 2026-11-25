// @ts-check
"use strict";

// Tests for terminals.js, which says how each kind of terminal opens and
// which colour its icon takes in each project.

const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const { KINDS, OTHER_COLOUR, PROJECT_COLOURS, projectColour, terminalSpec } = require("../terminals");

/**
 * @typedef {object} Manifest
 * @property {object} contributes
 * @property {{command: string, icon: string}[]} contributes.commands
 * @property {{activitybar: {id: string, icon: string}[]}} contributes.viewsContainers
 * @property {Record<string, {id: string}[]>} contributes.views
 * @property {Record<string, {command: string}[]>} contributes.menus
 * @property {{profiles: {id: string, icon: string}[]}} contributes.terminal
 */

/** @type {Manifest} */
const manifest = JSON.parse(readFileSync(path.join(__dirname, "..", "package.json"), "utf8"));

/** @type {ReadonlyArray<readonly [string, string]>} */
const COLOURED = [
    ["quillmedical", "terminal.ansiBlue"],
    ["quillmedical-6", "terminal.ansiBlue"],
    ["turva-2", "terminal.ansiMagenta"],
    ["juttu-messaging-3", "terminal.ansiYellow"],
    ["arnie", "terminal.ansiCyan"],
    ["digest", "terminal.ansiGreen"],
    ["mark-house-style", "terminal.ansiRed"],
    ["quillmedical-owl", "terminal.ansiWhite"],
    ["some-other-project", "terminal.ansiWhite"],
];

for (const [folder, colour] of COLOURED) {
    test(`${folder} is coloured ${colour}`, () => {
        assert.equal(projectColour(folder), colour);
    });
}

test("a Claude terminal has the robot icon and runs the Claude session", () => {
    const spec = terminalSpec("claude", "quillmedical-2");

    assert.equal(spec.icon, "robot");
    assert.equal(spec.colour, "terminal.ansiBlue");
    assert.deepEqual([spec.shellPath, ...spec.shellArgs], ["bash", "-lc", "just -g claude-session"]);
});

test("a tmux terminal has the binary icon and runs a plain tmux shell", () => {
    const spec = terminalSpec("tmux", "turva");

    assert.equal(spec.icon, "file-binary");
    assert.equal(spec.colour, "terminal.ansiMagenta");
    assert.deepEqual([spec.shellPath, ...spec.shellArgs], ["bash", "-lc", "just -g tmux-window"]);
});

test("a window with no folder open still gets a colour", () => {
    assert.equal(terminalSpec("claude", "").colour, OTHER_COLOUR);
});

test("every colour is one of the eight VS Code paints a terminal tab's icon in", () => {
    const painted = new Set(
        ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"].map(
            (name) => `terminal.ansi${name}`,
        ),
    );

    for (const colour of [...PROJECT_COLOURS.values(), OTHER_COLOUR]) {
        assert.ok(painted.has(colour), `${colour} would leave the tab's icon plain`);
    }
});

test("no two projects share a colour", () => {
    const colours = [...PROJECT_COLOURS.values(), OTHER_COLOUR];

    assert.equal(new Set(colours).size, colours.length);
});

test("the extension declares no colours of its own", () => {
    assert.equal("colors" in manifest.contributes, false);
});

test("each profile in package.json shows the icon its kind opens with", () => {
    const icons = manifest.contributes.terminal.profiles.map((profile) => profile.icon).sort();

    assert.deepEqual(icons, Object.values(KINDS).map((kind) => kind.icon).sort());
});

test("a terminal is given no name, so its tab reads as tmux titles it", () => {
    assert.equal("name" in terminalSpec("claude", "quillmedical"), false);
    assert.equal("name" in terminalSpec("tmux", "quillmedical"), false);
});

test("each command's button shows the icon its kind opens with", () => {
    const icons = manifest.contributes.commands.map((command) => command.icon).sort();

    assert.deepEqual(icons, Object.values(KINDS).map((kind) => `$(${kind.icon})`).sort());
});

test("both commands have a button above the editor tabs", () => {
    const buttons = manifest.contributes.menus["editor/title"].map((button) => button.command).sort();

    assert.deepEqual(buttons, manifest.contributes.commands.map((command) => command.command).sort());
});

test("the activity bar icon opens a panel with the sessions view in it", () => {
    const [container] = manifest.contributes.viewsContainers.activitybar;

    assert.equal(container.icon, "$(robot)");
    assert.deepEqual(manifest.contributes.views[container.id], [
        { id: "checkoutName.sessions", name: "Open a session" },
    ]);
});
