// @ts-check
"use strict";

// The short name each checkout shows in VS Code's title bar, worked out from
// its folder's name. Kept apart from extension.js so it can be tested without
// VS Code.

/**
 * Checkouts with a name all of their own, by folder.
 * @type {ReadonlyMap<string, string>}
 */
const OWN_NAMES = new Map([["quillmedical-owl", "Owl"]]);

/**
 * Each repository's folder, and the short name its checkouts show. A worktree
 * is the folder with a hyphen and more after it, such as quillmedical-2, and
 * keeps what follows: Quill-2.
 * @type {ReadonlyMap<string, string>}
 */
const SHORT_NAMES = new Map([
    ["quillmedical", "Quill"],
    ["turva", "Turva"],
    ["juttu-messaging", "Juttu"],
    ["arnie", "Arnie"],
    ["digest", "Digest"],
    ["mark-house-style", "Mark House Style"],
]);

/**
 * The repository a folder is a checkout of, or "" for a folder that is no
 * known repository's. A checkout with a name of its own, such as Owl's, is
 * its own project, so its folder comes back whole.
 * @param {string} folder
 * @returns {string}
 */
function checkoutProject(folder) {
    if (OWN_NAMES.has(folder)) {
        return folder;
    }

    // The longest repository that fits, so a repository whose folder starts
    // with another's name is never taken for a worktree of it.
    let repository = "";

    for (const candidate of SHORT_NAMES.keys()) {
        const isCheckout = folder === candidate || folder.startsWith(`${candidate}-`);
        if (isCheckout && candidate.length > repository.length) {
            repository = candidate;
        }
    }

    return repository;
}

/**
 * The name a checkout shows, from the name of its folder. A folder that is
 * no known repository's keeps its own name.
 * @param {string} folder
 * @returns {string}
 */
function checkoutName(folder) {
    const own = OWN_NAMES.get(folder);

    if (own !== undefined) {
        return own;
    }

    const repository = checkoutProject(folder);
    const shortName = SHORT_NAMES.get(repository);

    if (shortName === undefined) {
        return folder;
    }

    return shortName + folder.slice(repository.length);
}

module.exports = { checkoutName, checkoutProject };
