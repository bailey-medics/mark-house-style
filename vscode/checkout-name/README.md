# Checkout name

A small VS Code extension that shows a short name for the checkout a window
has open. The search box in the middle of the title bar reads `Quill-2`,
where it used to read the folder's name and the name of the connection.
The window's own title, in the operating system's list of windows, reads
the same.

## The names

A repository's folder shows as its short name. A worktree, whose folder is
the repository's with a hyphen and more after it, keeps what follows.

- **`quillmedical`** shows as `Quill`, and `quillmedical-2` as `Quill-2`.
- **`quillmedical-owl`** shows as `Owl`.
- **`turva`** shows as `Turva`, and `turva-2` as `Turva-2`.
- **`juttu-messaging`** shows as `Juttu`, and `juttu-messaging-3` as
  `Juttu-3`.
- **`arnie`** shows as `Arnie`, and `digest` as `Digest`.
- **`mark-house-style`** shows as `Mark House Style`.
- **Any other folder** keeps its own name.

The names are in `names.js`. To add one, add a line to `SHORT_NAMES` there,
or to `OWN_NAMES` for a checkout with a name all of its own, add a test to
`tests/names.test.js`, and install again.

## Installing

```bash
just -g checkout-name-install
```

Then run "Developer: Reload Window" in each VS Code window that is open.
`just -g checkout-name-remove` takes it out again, and the title bar goes
back to what it showed before.

- **On a machine VS Code reaches from elsewhere**, through a tunnel or SSH,
  the extension goes into VS Code's server on that machine. That is where
  the extensions for those windows run, so every window opened on that
  machine gets its name.
- **Anywhere else** it goes into VS Code itself, through its `code` command,
  and names the windows opened on that machine's own folders.

Installing needs `zip`. The tests need Node and bats:

```bash
just -g checkout-name-test
```

## How it works

- **`extension.js`** runs as a window starts. It works out the name from the
  first folder the window has open, and gives VS Code a title variable,
  `${checkoutName}`, through VS Code's `registerWindowTitleVariable`
  command.
- **`package.json`** makes `${checkoutName}` the default of VS Code's
  `window.title` setting. The search box shows the window's title whenever
  that setting has been changed from VS Code's own, so the box shows the
  name. No setting is added by hand, and a `window.title` of your own in
  VS Code's settings still wins.
- **`install.sh`** packs the folder as a `.vsix`, VS Code's package for an
  extension, in a scratch folder, and installs it.

## What to expect

- **The box reads "Search" for a moment** after a window opens, until the
  extension has started. A variable VS Code does not yet know is left out
  of the title, and an empty title shows as "Search".
- **A window with no folder open** reads "Search" all the time.
- **It needs VS Code 1.95 or later**, the first version checked to have
  `registerWindowTitleVariable`.
