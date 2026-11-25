// @ts-check
"use strict";

// The kinds of terminal the extension opens: a Claude session, the
// checkout's plain tmux shell, and another tmux shell beside it. A
// terminal's tab carries its project's banner icon. In the panel and on the
// buttons, the icon's shape says whether it is Claude or tmux, and in the
// panel its colour says which project. Kept apart from extension.js so it can be tested without
// VS Code.

const { checkoutProject } = require("./names");

/**
 * @typedef {"claude" | "tmux" | "anotherTmux"} TerminalKind
 */

/**
 * What a terminal is opened with: the picture on its tab, the VS Code icon
 * name and colour id of its row in the panel, and the command it runs. It
 * has no name: VS Code shows a name it was given in place of the title tmux
 * sends, and the tab is to read as tmux titles it, such as "Quill-6" and a
 * topic.
 * @typedef {object} TerminalSpec
 * @property {string} image
 * @property {string} icon
 * @property {string} colour
 * @property {string} shellPath
 * @property {string[]} shellArgs
 */

/**
 * Each kind's label in the panel, its icon and the global just recipe it
 * runs. "next" takes another tmux shell to the first one, from 2 up, that
 * no terminal is showing, so a shell whose tab was closed is come back to
 * before a new one is made.
 * @type {Readonly<Record<TerminalKind, {label: string, icon: string, recipe: string}>>}
 */
const KINDS = {
    claude: { label: "Claude session", icon: "robot", recipe: "claude-session" },
    tmux: { label: "Tmux shell", icon: "file-binary", recipe: "tmux-window" },
    anotherTmux: { label: "Another tmux shell", icon: "file-binary", recipe: "tmux-window next" },
};

/**
 * Each project's colour id, by the folder checkoutProject gives, for its
 * rows in the panel. Each is one of VS Code's eight basic terminal colours,
 * the nearest to the project's banner icon, and the shade is the theme's.
 * @type {ReadonlyMap<string, string>}
 */
const PROJECT_COLOURS = new Map([
    ["quillmedical", "terminal.ansiBlue"],
    ["turva", "terminal.ansiMagenta"],
    ["juttu-messaging", "terminal.ansiYellow"],
    ["arnie", "terminal.ansiCyan"],
    ["digest", "terminal.ansiGreen"],
    ["mark-house-style", "terminal.ansiRed"],
]);

/** The colour for Owl and for any folder that is no known project's. */
const OTHER_COLOUR = "terminal.ansiWhite";

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
    ["mark-house-style", "mark-house-style.png"],
]);

/** The picture for Owl and for any folder that is no known project's. */
const OTHER_IMAGE = "general.png";

/**
 * The colour id for a checkout, from its folder's name.
 * @param {string} folder
 * @returns {string}
 */
function projectColour(folder) {
    return PROJECT_COLOURS.get(checkoutProject(folder)) ?? OTHER_COLOUR;
}

/**
 * The file name of a checkout's banner icon, from its folder's name.
 * @param {string} folder
 * @returns {string}
 */
function projectImage(folder) {
    return PROJECT_IMAGES.get(checkoutProject(folder)) ?? OTHER_IMAGE;
}

/**
 * How to open a terminal of one kind for a checkout.
 * @param {TerminalKind} kind
 * @param {string} folder
 * @returns {TerminalSpec}
 */
function terminalSpec(kind, folder) {
    const { icon, recipe } = KINDS[kind];

    return {
        image: projectImage(folder),
        icon,
        colour: projectColour(folder),
        shellPath: "bash",
        shellArgs: ["-lc", `just -g ${recipe}`],
    };
}

module.exports = {
    KINDS,
    OTHER_COLOUR,
    OTHER_IMAGE,
    PROJECT_COLOURS,
    PROJECT_IMAGES,
    projectColour,
    projectImage,
    terminalSpec,
};
