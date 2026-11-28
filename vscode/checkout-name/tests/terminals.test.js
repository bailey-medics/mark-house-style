// @ts-check
"use strict";

// Tests for terminals.js, which says what each session's terminal opens
// with, and for what package.json declares beside it.

const assert = require("node:assert/strict");
const { existsSync, readdirSync, readFileSync } = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const {
    KINDS,
    OTHER_IMAGE,
    PROJECT_IMAGES,
    pictureAddress,
    projectImage,
    terminalSpec,
} = require("../terminals");

/**
 * @typedef {object} Manifest
 * @property {object} contributes
 * @property {Record<string, string>} contributes.configurationDefaults
 * @property {{command: string, icon: string}[]} contributes.commands
 * @property {{activitybar: {id: string, icon: string}[]}} contributes.viewsContainers
 * @property {Record<string, {id: string}[]>} contributes.views
 * @property {Record<string, {command: string, group?: string, alt?: string, when?: string}[]>} contributes.menus
 */

/** @type {Manifest} */
const manifest = JSON.parse(readFileSync(path.join(__dirname, "..", "package.json"), "utf8"));

test("a Claude terminal has the robot icon and runs the Claude session", () => {
    const spec = terminalSpec("claude", "quillmedical-2");

    assert.equal(spec.icon, "robot");
    assert.deepEqual([spec.shellPath, ...spec.shellArgs], ["bash", "-lc", "just -g claude-session"]);
});

test("a tmux terminal has the binary icon and runs a plain tmux shell", () => {
    const spec = terminalSpec("tmux", "turva");

    assert.equal(spec.icon, "file-binary");
    assert.deepEqual([spec.shellPath, ...spec.shellArgs], ["bash", "-lc", "just -g tmux-window"]);
});

test("a terminal carries no project colour", () => {
    assert.equal("colour" in terminalSpec("claude", "quillmedical"), false);
});

test("the extension declares no colours of its own", () => {
    assert.equal("colors" in manifest.contributes, false);
});

test("a later tmux shell has the binary icon and runs that shell by its number", () => {
    const spec = terminalSpec("tmux-3", "quillmedical-6");

    assert.equal(spec.icon, "file-binary");
    assert.deepEqual([spec.shellPath, ...spec.shellArgs], ["bash", "-lc", "just -g tmux-window 3"]);
});

test("a terminal is refused for anything that is not a session", () => {
    for (const session of ["anotherTmux", "tmux-1", "tmux-100", "tmux-2; rm -rf ~", ""]) {
        assert.throws(() => terminalSpec(session, "quillmedical"), /is not a session/);
    }
});

test("the extension offers no terminal profiles, which could not come back after a reload", () => {
    assert.equal("terminal" in manifest.contributes, false);
});

test("a picture's address holds the picture itself, so the window fetches nothing", () => {
    const bytes = readFileSync(path.join(__dirname, "..", "icons", "quill.png"));
    const address = pictureAddress(bytes);
    const prefix = "data:image/png;base64,";

    assert.ok(address.startsWith(prefix));
    assert.deepEqual(Buffer.from(address.slice(prefix.length), "base64"), bytes);
});

test("every tab picture is small enough to carry in its address", () => {
    for (const image of readdirSync(path.join(__dirname, "..", "icons"))) {
        const size = readFileSync(path.join(__dirname, "..", "icons", image)).length;

        assert.ok(size < 4096, `${image} is ${size} bytes: make it again with just -g checkout-name-icons`);
    }
});

test("a terminal is given no name, so its tab reads as tmux titles it", () => {
    assert.equal("name" in terminalSpec("claude", "quillmedical"), false);
    assert.equal("name" in terminalSpec("tmux", "quillmedical"), false);
});

test("each command's button shows the icon its kind opens with", () => {
    const icons = manifest.contributes.commands.map((command) => command.icon).sort();

    assert.deepEqual(icons, Object.values(KINDS).map((kind) => `$(${kind.icon})`).sort());
});

test("Claude and tmux each have a button above the editor tabs", () => {
    const buttons = manifest.contributes.menus["editor/title"].map((button) => button.command).sort();

    assert.deepEqual(buttons, ["checkoutName.openClaude", "checkoutName.openTmux"]);
});

test("the tmux button opens another shell when clicked with Alt held", () => {
    const alts = manifest.contributes.menus["editor/title"].map((button) => [button.command, button.alt]);

    assert.deepEqual(alts, [
        ["checkoutName.openTmux", "checkoutName.openAnotherTmux"],
        ["checkoutName.openClaude", undefined],
    ]);
});

test("the tmux button sits to the left of the Claude one", () => {
    const placed = manifest.contributes.menus["editor/title"].map((button) => [button.command, button.group]);

    assert.deepEqual(placed, [
        ["checkoutName.openTmux", "navigation@1"],
        ["checkoutName.openClaude", "navigation@2"],
    ]);
});

test("every command in package.json is one a kind opens", () => {
    const commands = manifest.contributes.commands.map((command) => command.command).sort();

    assert.deepEqual(commands, [
        "checkoutName.openAnotherTmux",
        "checkoutName.openClaude",
        "checkoutName.openTmux",
    ]);
});

test("the activity bar icon opens a panel with the sessions view in it", () => {
    const [container] = manifest.contributes.viewsContainers.activitybar;

    assert.equal(container.icon, "$(robot)");
    assert.deepEqual(manifest.contributes.views[container.id], [
        { id: "checkoutName.sessions", name: "Open a session" },
    ]);
});

/** @type {ReadonlyArray<readonly [string, string]>} */
const PICTURED = [
    ["quillmedical", "quill.png"],
    ["quillmedical-6", "quill.png"],
    ["turva-2", "turva.png"],
    ["juttu-messaging-3", "juttu.png"],
    ["arnie", "arnie.png"],
    ["digest", "digest.png"],
    ["mark-house-style", "mark-house-style.png"],
    ["quillmedical-owl", "general.png"],
    ["some-other-project", "general.png"],
    ["", "general.png"],
];

for (const [folder, image] of PICTURED) {
    test(`a terminal in ${folder || "a window with no folder"} has ${image} on its tab`, () => {
        assert.equal(projectImage(folder), image);
        assert.equal(terminalSpec("claude", folder).image, image);
        assert.equal(terminalSpec("tmux", folder).image, image);
    });
}

const TAB_ICONS = path.join(__dirname, "..", "icons");
const BANNER_ICONS = path.join(__dirname, "..", "..", "..", "scripts", "notification", "icons");

test("every picture a tab shows is in icons/, which install.sh packs", () => {
    for (const image of [...PROJECT_IMAGES.values(), OTHER_IMAGE]) {
        assert.ok(existsSync(path.join(TAB_ICONS, image)), `${image} is not in icons/`);
    }
});

test("every banner icon has a tab picture made from it", () => {
    const banners = readdirSync(BANNER_ICONS).filter((file) => file.endsWith(".png"));

    assert.ok(banners.length > 0);

    for (const banner of banners) {
        assert.ok(
            existsSync(path.join(TAB_ICONS, banner)),
            `${banner} has no tab picture: run just -g checkout-name-icons`,
        );
    }
});

test("no command is listed in the Command Palette", () => {
    const hidden = manifest.contributes.menus.commandPalette.map((entry) => [entry.command, entry.when]);

    assert.deepEqual(
        hidden.sort(),
        manifest.contributes.commands.map((command) => [command.command, "false"]).sort(),
    );
});

test("a terminal tab reads as its shell titles it, and nothing else, in every window", () => {
    const defaults = manifest.contributes.configurationDefaults;

    assert.equal(defaults["terminal.integrated.tabs.title"], "${sequence}");
    assert.equal(defaults["terminal.integrated.tabs.description"], "");
});
