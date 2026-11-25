// @ts-check
"use strict";

// The two kinds of terminal the extension opens: a Claude session and a plain
// tmux shell. The icon's shape says which kind it is, and its colour says
// which project. Kept apart from extension.js so it can be tested without
// VS Code.

const { checkoutProject } = require("./names");

/**
 * @typedef {"claude" | "tmux"} TerminalKind
 */

/**
 * What a terminal is opened with: a VS Code icon name, the id of one of
 * VS Code's terminal colours, and the command it runs. It has no
 * name: VS Code shows a name it was given in place of the title tmux sends,
 * and the tab is to read as tmux titles it, such as "Quill-6" and a topic.
 * @typedef {object} TerminalSpec
 * @property {string} icon
 * @property {string} colour
 * @property {string} shellPath
 * @property {string[]} shellArgs
 */

/**
 * Each kind's label in the panel, its icon and the global just recipe it
 * runs.
 * @type {Readonly<Record<TerminalKind, {label: string, icon: string, recipe: string}>>}
 */
const KINDS = {
    claude: { label: "Claude session", icon: "robot", recipe: "claude-session" },
    tmux: { label: "Tmux shell", icon: "file-binary", recipe: "tmux-window" },
};

/**
 * Each project's colour id, by the folder checkoutProject gives. Each is one
 * of VS Code's eight basic terminal colours, the nearest to the project's
 * banner icon. VS Code paints a terminal tab's icon in those eight only: any
 * other colour is taken without complaint and the icon is left plain. The
 * shade is the theme's.
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
 * The colour id for a checkout, from its folder's name.
 * @param {string} folder
 * @returns {string}
 */
function projectColour(folder) {
    return PROJECT_COLOURS.get(checkoutProject(folder)) ?? OTHER_COLOUR;
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
        icon,
        colour: projectColour(folder),
        shellPath: "bash",
        shellArgs: ["-lc", `just -g ${recipe}`],
    };
}

module.exports = { KINDS, OTHER_COLOUR, PROJECT_COLOURS, projectColour, terminalSpec };
