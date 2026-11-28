// @ts-check
"use strict";

// What each terminal the extension opens is opened with: the picture on its
// tab, and the command it runs. A terminal's tab carries its project's banner
// icon. In the panel and on the buttons, the icon's shape says whether it is
// Claude or tmux. Kept apart from extension.js so it can be tested without
// VS Code.

const { checkoutProject } = require("./names");
const { CLAUDE, sessionRecipe } = require("./sessions");

/**
 * The three things a row in the panel or a button can open.
 * @typedef {"claude" | "tmux" | "anotherTmux"} TerminalKind
 */

/**
 * What a session's terminal is opened with: the picture on its tab, the
 * built-in icon that stands in if the picture cannot be read, and
 * the command it runs. It has no name: VS Code shows a name it was given in
 * place of the title tmux sends, and the tab is to read as tmux titles it,
 * such as "Quill-6" and a topic.
 * @typedef {object} TerminalSpec
 * @property {string} image
 * @property {string} icon
 * @property {string} shellPath
 * @property {string[]} shellArgs
 */

/** The built-in icons: a robot for Claude, 0s and 1s for a tmux shell. */
const CLAUDE_ICON = "robot";
const SHELL_ICON = "file-binary";

/**
 * Each kind's label in the panel, and its icon there and on its button.
 * @type {Readonly<Record<TerminalKind, {label: string, icon: string}>>}
 */
const KINDS = {
    claude: { label: "Claude session", icon: CLAUDE_ICON },
    tmux: { label: "Tmux shell", icon: SHELL_ICON },
    anotherTmux: { label: "Another tmux shell", icon: SHELL_ICON },
};

/**
 * Each project's banner icon, by the folder checkoutProject gives: a file
 * in icons/ beside this file, which install.sh packs into the extension.
 * tab-icons.sh makes those pictures from the banners' own, in
 * scripts/notification/icons, each as the same rounded square so the tabs
 * share one outline.
 * @type {ReadonlyMap<string, string>}
 */
const PROJECT_IMAGES = new Map([
    ["quillmedical", "quill.png"],
    ["turva", "turva.png"],
    ["juttu-messaging", "juttu.png"],
    ["arnie", "arnie.png"],
    ["digest", "digest.png"],
    ["kaiku", "kaiku.png"],
    ["mark-house-style", "mark-house-style.png"],
]);

/** The picture for Owl and for any folder that is no known project's. */
const OTHER_IMAGE = "general.png";

/**
 * The file name of a checkout's banner icon, from its folder's name.
 * @param {string} folder
 * @returns {string}
 */
function projectImage(folder) {
    return PROJECT_IMAGES.get(checkoutProject(folder)) ?? OTHER_IMAGE;
}

/**
 * A picture's bytes as an address that holds the picture itself. A window
 * reached through a VS Code tunnel fetches a picture file from the dev box,
 * and such a fetch can stick open for ever: a connection left idle for a few
 * seconds is closed at the box, the window reuses it, and no answer comes.
 * Six stuck fetches use up the window's connections, and then no picture
 * loads anywhere. An address that carries the picture is never fetched.
 * @param {Uint8Array} bytes
 * @returns {string}
 */
function pictureAddress(bytes) {
    return `data:image/png;base64,${Buffer.from(bytes).toString("base64")}`;
}

/**
 * How to open a session's terminal for a checkout.
 * @param {string} session a session's key, as sessions.js sets out
 * @param {string} folder
 * @returns {TerminalSpec}
 */
function terminalSpec(session, folder) {
    const recipe = sessionRecipe(session);

    return {
        image: projectImage(folder),
        icon: session === CLAUDE ? CLAUDE_ICON : SHELL_ICON,
        shellPath: "bash",
        shellArgs: ["-lc", `just -g ${recipe}`],
    };
}

module.exports = {
    KINDS,
    OTHER_IMAGE,
    PROJECT_IMAGES,
    pictureAddress,
    projectImage,
    terminalSpec,
};
