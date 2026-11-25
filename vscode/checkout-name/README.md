# Checkout name

A small VS Code extension that shows a short name for the checkout a window
has open. The search box in the middle of the title bar reads `Quill-2`,
where it used to read the folder's name and the name of the connection.
The window's own title, in the operating system's list of windows, reads
the same.

It also opens a Claude session or a plain tmux shell as a terminal, with
the project's banner icon on its tab.

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

There are three kinds. Where one is chosen, in the panel and on the
buttons, a robot stands for Claude and a binary icon of 0s and 1s for
tmux:

- **Claude** runs `just -g claude-session`.
- **Tmux** runs `just -g tmux-window`, the checkout's first shell.
- **Another tmux shell** runs
  `just -g tmux-window next`. That is the first shell from 2 up that no
  terminal is showing: `Quill-6 Tmux-2`, then `Quill-6 Tmux-3`. A shell
  whose tab was closed is come back to before a new one is made.

Each opens as a tab in the editor area, and its tab reads as tmux titles
it, such as `Quill-6` and a topic. The extension sets that up for every
window: by default VS Code leads a tab with the name of the program
running in it, which for these is `just`. There are three ways to open one:

- **The robot in the activity bar**, the strip of icons down the side of
  the window. It opens a panel, "Sessions", with a row for each kind.
  Click a row.
- **The two buttons above the editor tabs**, at the right, beside the split
  button. They show whenever an editor tab is open. Click the tmux button
  with Alt held down, Option on a Mac, for another tmux shell.
- **The list beside the "+"** of the terminal panel, as "Claude" and "Tmux".

The commands behind them are kept out of the Command Palette, which
would only list them a third time. A keyboard shortcut can still be given
to one by its id in `keybindings.json`: `checkoutName.openClaude`,
`checkoutName.openTmux` or `checkoutName.openAnotherTmux`.

A terminal has to be opened in one of these ways to carry its icon. VS Code
sets a terminal's icon and colour only as the terminal opens, and has no
way to change them afterwards. So `just cc` or `just tw` typed into a plain
terminal still works, but keeps that terminal's own icon.

### The icon on the tab

A terminal's tab carries its project's banner icon, the picture its
notification banners show, so a tab says which project it belongs to
wherever it is dragged. Worktrees share their project's icon, and Owl and
any other folder have the general one, a bell. A Claude tab and a tmux tab
of one project look alike, and their titles tell them apart: `Quill-6` and
a topic, against `Quill-6 Tmux`.

The pictures are in `icons/` beside this file, and `install.sh` packs
them into the extension. `tab-icons.sh` makes them from the banners' own,
in `scripts/notification/icons/`, each as the same small rounded square,
so the tabs of different projects share one outline. A banner icon with a
see-through background is set on white first: Quill's feather is dark
navy, and a dark tab would hide it. Which picture each project takes is in
`terminals.js`.

After adding or changing a banner icon, make the tab pictures again,
commit them and install:

```bash
just -g checkout-name-icons
just -g checkout-name-install
```

Making them needs Pillow, which the script sets up once in
`~/.venvs/notifier` when the machine's Python lacks it. Installing does
not.

### The colour in the panel

In the Sessions panel, each row's icon is in the terminal colour nearest
the project's banner icon:

| Project | Colour |
| --- | --- |
| Quill | blue |
| Turva | magenta |
| Juttu | yellow |
| Arnie | cyan |
| Digest | green |
| Mark House Style | red |
| Owl and others | white |

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
- **`terminals.js`** says what each kind of terminal opens with: the
  picture on its tab, its icon and colour in the panel, and the command it
  runs. A terminal is given
  no name, because VS Code shows a name it was given in place of the title
  tmux sends.
- **`package.json`** makes `${sequence}`, the title a shell sends, the
  default of VS Code's `terminal.integrated.tabs.title` setting, and
  empties `terminal.integrated.tabs.description`, so no repository needs
  those lines in a `.vscode/settings.json` of its own. A repository's or
  your own setting still wins.
- **`package.json`** also declares the activity bar icon and its panel,
  and the buttons above the editor tabs. It makes
  `${checkoutName}` the default of VS Code's
  `window.title` setting. The search box shows the window's title whenever
  that setting has been changed from VS Code's own, so the box shows the
  name. No setting is added by hand, and a `window.title` of your own in
  VS Code's settings still wins.
- **`tab-icons.sh`** makes the pictures in `icons/` from the banner icons.
- **`install.sh`** packs the folder and those pictures as a `.vsix`,
  VS Code's package for an extension, in a scratch folder, and installs
  it.

## What to expect

- **The box reads "Search" for a moment** after a window opens, until the
  extension has started. A variable VS Code does not yet know is left out
  of the title, and an empty title shows as "Search".
- **A window with no folder open** reads "Search" all the time.
- **It needs VS Code 1.95 or later**, the first version checked to have
  `registerWindowTitleVariable`.
