// @ts-check
"use strict";

// Tests for names.js, which turns a checkout's folder name into the short
// name VS Code's title bar shows.

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { checkoutName, checkoutProject } = require("../names");

/** @type {ReadonlyArray<readonly [string, string]>} */
const SHOWN = [
    ["quillmedical", "Quill"],
    ["quillmedical-2", "Quill-2"],
    ["quillmedical-12", "Quill-12"],
    ["quillmedical-owl", "Owl"],
    ["turva", "Turva"],
    ["turva-3", "Turva-3"],
    ["juttu-messaging", "Juttu"],
    ["juttu-messaging-3", "Juttu-3"],
    ["arnie", "Arnie"],
    ["digest", "Digest"],
    ["kaiku", "Kaiku"],
    ["kaiku-2", "Kaiku-2"],
    ["mark-house-style", "Mark House Style"],
];

for (const [folder, name] of SHOWN) {
    test(`${folder} shows as ${name}`, () => {
        assert.equal(checkoutName(folder), name);
    });
}

test("a folder that is no known repository's keeps its own name", () => {
    assert.equal(checkoutName("some-other-project"), "some-other-project");
});

test("a folder that only starts with a repository's letters keeps its own name", () => {
    assert.equal(checkoutName("quillmedicalx"), "quillmedicalx");
    assert.equal(checkoutName("digestive"), "digestive");
});

test("a folder that only ends with a repository's name keeps its own name", () => {
    assert.equal(checkoutName("clinical-safety-digest"), "clinical-safety-digest");
});

test("each checkout's project is the repository it is a checkout of", () => {
    assert.equal(checkoutProject("quillmedical"), "quillmedical");
    assert.equal(checkoutProject("quillmedical-6"), "quillmedical");
    assert.equal(checkoutProject("juttu-messaging-3"), "juttu-messaging");
});

test("Owl's checkout is a project of its own, not Quill's", () => {
    assert.equal(checkoutProject("quillmedical-owl"), "quillmedical-owl");
});

test("a folder that is no known repository's has no project", () => {
    assert.equal(checkoutProject("digestive"), "");
});
