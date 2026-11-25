# Checkout name

A small VS Code extension that shows a short name for the checkout a window
has open. The search box in the middle of the title bar reads `Quill-2`,
where it used to read the folder's name and the name of the connection.
The window's own title, in the operating system's list of windows, reads
the same.

It also opens two kinds of terminal, a Claude session and a plain tmux
shell, each with an icon of its own, coloured for the project.

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

## The terminals

The icon's shape says which kind of terminal it is, and its colour says
which project:

- **Claude**, with a robot icon, runs `just -g claude-session`.
- **Tmux**, with a binary icon of 0s and 1s, runs `just -g tmux-window`.

Each opens as a tab in the editor area, and its tab reads as tmux titles
it, such as `Quill-6` and a topic. There are four ways to open one:

- **The robot in the activity bar**, the strip of icons down the side of
  the window. It opens a panel, "Sessions", with a row for each kind.
  Click a row.
- **The two buttons above the editor tabs**, at the right, beside the split
  button. They show whenever an editor tab is open.
- **The Command Palette**, as "Checkout: Open Claude session" and
  "Checkout: Open tmux shell", or a keyboard shortcut of your own for
  either.
- **The list beside the "+"** of the terminal panel, as "Claude" and "Tmux".

A terminal has to be opened in one of these ways to carry its icon. VS Code
sets a terminal's icon and colour only as the terminal opens, and has no
way to change them afterwards. So `just cc` or `just tw` typed into a plain
terminal still works, but keeps that terminal's own icon.

Each project takes the terminal colour nearest its banner icon. The
colour shows on the icon in the terminal's tab and on the rows of the
Sessions panel. Worktrees share their project's colour, and Owl and any
other folder are white.

| Project | Colour |
| --- | --- |
| Quill | blue |
| Turva | magenta |
| Juttu | yellow |
| Arnie | cyan |
| Digest | green |
| Mark House Style | red |
| Owl and others | white |

VS Code paints a terminal tab's icon in its eight basic terminal colours
only: black, red, green, yellow, blue, magenta, cyan and white. It takes
any other colour without complaint and leaves the icon plain, so a
project cannot have a shade of its own. The shade of each is the theme's,
the same one text in the terminal is drawn in. The colour each project
takes is in `terminals.js`.

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
  command. It also registers the two terminal profiles, the two commands
  that open them, and the rows of the Sessions panel.
- **`terminals.js`** says what each kind of terminal opens with: its icon,
  its colour for the project, and the command it runs. A terminal is given
  no name, because VS Code shows a name it was given in place of the title
  tmux sends.
- **`package.json`** declares the activity bar icon and its panel,
  and the buttons above the editor tabs. It makes
  `${checkoutName}` the default of VS Code's
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
