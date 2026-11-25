# Terminal tab icons plan

The checkout name extension, in `vscode/checkout-name/`, opens Claude and tmux sessions as terminal tabs in VS Code's editor area, each with its project's banner icon on the tab. The pictures showed at first, in Quill Medical, Turva and Arnie windows, and then stopped in every window: the tab keeps a blank space where the icon was. All the windows run on the Mac and reach the dev box through a VS Code tunnel, so the extension runs on the box and the window draws on the Mac. Everything that could be tested from the box has been, and the fault has not been found there.

The outcome wanted is a picture on every tab the extension opens, that survives "Developer: Reload Window". This plan records what was built, what was ruled out and how, and then the one reading still needed, which can only be taken from a window on the Mac. The fix depends on that reading, so Phase 3 sets out the choices rather than one answer.

## Open questions

- [ ] **Why is a newly opened tab blank in a tunnel window, when the same build draws it in a window on one machine?** Phase 2 answers it.

- [ ] **Should the tabs keep full-colour pictures, or fall back to a built-in icon in one of VS Code's eight terminal colours?** The built-in icons (a robot for Claude, 0s and 1s for tmux) worked in every window and survived reloads. Mark's to decide, once Phase 2 shows whether the pictures can be made to work.

## Before running /f

- [ ] **This plan is not for `/f` as it stands.** Phase 2 needs a window on the Mac and somebody to look at it. Tick this only once Phase 2 is done and Phase 3 has been rewritten as steps `/f` can build.

## Phase 1: What was built, and what was ruled out

- [x] Open each session with a picture on its tab. `terminals.js` names a picture for each project (`quill.png`, `turva.png`, `juttu.png`, `arnie.png`, `digest.png`, `mark-house-style.png`, and `general.png` for Owl and anything else), and `extension.js` passes it as the terminal's `iconPath`: `vscode.Uri.joinPath(context.extensionUri, "icons", spec.image)`. The terminal has no `name`, because VS Code shows a name it was given in place of the title tmux sends. First shipped as version 0.6.0 of the extension, and it worked: a new tab in a Quill Medical window showed the feather, and Turva and Arnie tabs showed theirs under 0.6.2.

- [x] Learn how VS Code draws a picture on an editor-area terminal tab, from its source at the build the windows run (1.144.1, commit `261c84cb1eddf11235f9e2c921425e9663fbe556`). Three things have to hold, and each can be checked in the window:

  - **The tab's label carries two classes**, `terminal-uri-icon-<key>` and `terminal-uri-icon`. `getUriClasses` in `terminalIcon.ts` adds them only when the terminal's icon is a real `URI` object in the window. The key is a hash of the picture's path, in base 36, so it changes with every installed version of the extension.
  - **A style rule exists for that class.** `updateStyles` in `terminalService.ts` writes `.monaco-workbench .terminal-tab.<class>::before {content: ''; background-image: url(...)}` for each terminal whose icon is `instanceof URI`.
  - **The picture loads from that URL.** Otherwise the rule applies and draws nothing.

  A third rule explains the blank space: `terminal.css` has `.monaco-workbench .terminal-tab:not(.terminal-uri-icon)::before { background-image: none !important; }`. So a terminal tab with no picture class gets no icon at all, and the space stays.

- [x] Rule out the picture files. All seven are in every installed version under `~/.vscode-server/extensions/local.checkout-name-<version>/icons/`, and the VS Code server on the box returns each with `200 image/png` when asked for it as a window would, through `/vscode-remote-resource?path=...`. Mark suspected the rounded corners added in 0.6.3, so the pictures from 0.6.2 were copied over the installed 0.6.4 ones and a Turva window reloaded: still blank. One caveat: the URL did not change in that test, so a cache on the Mac could have served the earlier picture.

- [x] Rule out the extension's code. `extension.js` and `terminals.js` are the same in the installed 0.6.2, where Turva and Arnie showed their pictures, and 0.6.3, where Turva's went blank, apart from a comment. Only the pictures and the folder's name changed.

- [x] Rule out the style rule. The exact rule, built as `cssValue.className` and `cssValue.asCSSUrl` build it, was run in headless Chrome on the box for all seven pictures in three versions. All 21 rules parsed and applied. The hash is negative for some paths, which gives a class with a double hyphen, and the working and failing cases first seemed to follow its sign. They do not: a later failure had a negative hash.

- [x] Rule out the tab's title length. An earlier VS Code bug hid the icon on a narrow editor tab. A Turva tmux tab was given a long title from the box, with `tmux set-option -t "=turva-tmux:" set-titles-string "..."`, and stayed blank.

- [x] Rule out the settings. Quill Medical, Turva and Juttu each set `terminal.integrated.tabs.title` to `${sequence}` and empty `terminal.integrated.tabs.description` in their own `.vscode/settings.json`, and from 0.6.4 the extension sets both as defaults for every window. Nothing in any of them touches tab icons.

- [x] Reproduce in a lab on the box, and find one real fault. VS Code 1.147.0 is installed on the box as a desktop app. It was run on a hidden screen (`xvfb-run`) with a scratch profile, a scratch extensions folder holding the extension, and `--remote-debugging-port`, and its window was read through Chrome's debugging protocol. The lab copy of the extension ran `sleep 900` in place of the `just` recipe, and had a file trigger for commands, because key presses sent through the debugger did not reach VS Code's key bindings. Findings:

  - **A newly opened tab is right.** Both classes on the label, the rule in the page, and the picture loaded.
  - **A tab restored by "Developer: Reload Window" loses its picture.** After the reload its label has neither class and the page has no rule for it. VS Code brings the terminal back from its saved state, and the icon comes back as something that is not a `URI` object, so both checks above fail. This is VS Code's fault, not the extension's, and it stands on its own: any picture tab goes blank at the next reload.
  - **A tab opened after the reload is right again.** This is where the lab and the real windows differ.

- [x] Record what the lab did not reproduce. In the real windows a tab opened after a reload is blank too. Mark closed every terminal tab in a window, reloaded, and opened one session from the button: still blank. The lab window ran on one machine, where the picture's address is a `vscode-file:` one. The real windows go through the tunnel, where the extension runs in a remote extension host and the picture's address is a `vscode-remote:` one, loaded through VS Code's remote resource loader. A second lab was started to copy that, `code serve-web` at the windows' own commit with headless Chrome as the window, but it was stopped before it gave a result: the extension, copied by hand into the server's extensions folder, had not set the window's title, so it may not have been loaded.

- [x] Record the state this left on the box, so nobody is misled by it. The installed 0.6.4 holds the square pictures from 0.6.2, not the rounded ones in the repository; `just -g checkout-name-install` puts the repository's back. `~/.venvs/notifier` now exists on the box, with Pillow, made by `tab-icons.sh`. The Turva window has several tabs attached to the same sessions, from testing.

## Phase 2: Read a real window on the Mac

- [ ] Take one reading from a tunnel window with a blank tab open, and write the result into this step. It shows which of the three things in Phase 1 fails. Two ways to take it:

  - **By hand.** In the window, "Help", "Toggle Developer Tools", "Console". Type `allow pasting` and press Enter if the console refuses a paste. Paste the line below and press Enter. It prints nothing and puts its result on the clipboard.

    ```js
    copy(JSON.stringify(await(async()=>{const o=[];for(const l of document.querySelectorAll('.tabs-container .tab .monaco-icon-label.terminal-tab')){const b=getComputedStyle(l,'::before');const u=(b.backgroundImage.match(/url\("(.*)"\)/)||[])[1];let img='no url';if(u){img=await new Promise(r=>{const i=new Image();i.onload=()=>r('loaded '+i.naturalWidth);i.onerror=()=>r('FAILED');i.src=u})}o.push({title:l.textContent.slice(0,30),classes:[...l.classList].filter(n=>/uri/.test(n)),image:(u||b.backgroundImage).replace(/tkn=[^&"]*/,'tkn=hidden').slice(0,220),load:img})}const rules=[...document.querySelectorAll('style')].flatMap(s=>s.textContent.match(/terminal-uri-icon-[^{]*\{[^}]*\}/g)||[]).map(r=>r.replace(/tkn\\?=[^&'\\]*/,'tkn=hidden').slice(0,240));return{tabs:o,rules,version:(navigator.userAgent.match(/Code\/[\d.]+/)||[])[0]}})(),null,1))
    ```

  - **From a session on the Mac.** Quit VS Code, start it with `code --remote-debugging-port=9333`, and open the tunnel window. `http://127.0.0.1:9333/json` lists the pages; the window is the one whose address ends `workbench.html`. Connect to its `webSocketDebuggerUrl` and send `Runtime.evaluate` with `awaitPromise` and `returnByValue` set, and the same code without its `copy(JSON.stringify(await` wrapper. Node's own `WebSocket` and `fetch` are enough; no package is needed.

  The result lists each terminal tab's title, its picture classes, the picture's address and whether it loaded, then the picture rules in the page. It hides the connection token. The address may still hold the tunnel's name, which must not go into this file: write `<the tunnel's name>` in its place.

- [ ] Read the result against the three checks, for a tab opened after the reload:

  - **No classes and no rule** - the icon did not reach the window as a `URI`. The fault is on the way from the remote extension host, or in how the window keeps the terminal. Look next at what the extension sends: try `iconPath` as `{ light, dark }` with the same picture in both, and try the picture as a `data:` address built from the file's bytes, which needs no fetch from the box.
  - **Classes and a rule, and the load says FAILED** - the window asks for the picture and does not get it. Compare the address with the path on the box. A `data:` address would avoid the fetch altogether.
  - **Classes, a rule and a loaded picture, yet a blank tab** - something else covers or hides it. Read the label's other `::before` styles in the same console.

- [ ] Check whether the fault follows the version or the window, by installing 0.6.2 again and opening a tab in a window with no terminal tabs. 0.6.2 is the last version known to show a picture on a new tab. Its folder is still on the box, at `~/.vscode-server/extensions/local.checkout-name-0.6.2`, marked obsolete. If 0.6.2 shows the picture today, step forward one version at a time. If it does not, the cause is not in the extension's versions at all, and something in the windows or on the Mac changed during the afternoon of 25 November 2026.

## Phase 3: Make the pictures last

- [ ] Fix the new-tab fault, from what Phase 2 finds. Write the steps here once the cause is known.

- [ ] Stop a reload blanking the tabs. This is needed whatever Phase 2 finds, since the lab showed it on one machine. VS Code offers no way to set an icon on a terminal it has restored, so the tab has to be opened afresh. Open each terminal with `isTransient: true`, so VS Code does not restore it, keep the list of open sessions in the extension's `workspaceState`, and open them again as the window starts. tmux holds the sessions, so each tab comes back where it left off. Decide what "open" means when a tab is closed by hand: the list should drop it, or it will come back at the next reload.

- [ ] Stop each click opening another tab onto a session that already has one in the window. The Turva window ended the day with six tabs on one Claude session. A click on a session that is already open in the window should show that tab. The extension can keep the `Terminal` it made for each session and call `show()` on it.

- [ ] If the pictures cannot be made to work through the tunnel, go back to built-in icons. Version 0.5.0 gave Claude a robot and tmux the 0s and 1s (`robot` and `file-binary`), each in the project's colour from VS Code's eight terminal colours. Those drew in every window and survived a reload. The colour table is still in `terminals.js`, used for the Sessions panel.

## Phase 4: Tidy up

- [ ] Install the repository's version again on the box, `just -g checkout-name-install`, so the installed pictures match `vscode/checkout-name/icons/`, and reload each window.

- [ ] Close the spare tabs in each window, then check `tmux list-sessions -F '#{session_name} #{session_attached}'` shows one client for each session.

- [ ] Update `vscode/checkout-name/README.md` for whatever Phase 3 changed, including the limit that a restored tab cannot keep a picture.

## Decisions

- **The pictures are made, not hand-edited** - `tab-icons.sh` builds each tab picture from its banner icon as the same 256 pixel rounded square, and `just -g checkout-name-icons` runs it. The rounding was suspected of breaking the icons and was cleared by the revert test in Phase 1, so it stays.

- **A lab on the box, not more tests on the Mac by hand** - several rounds of "reload and look" each tested one guess and each guess was wrong. Reading the window's own classes and rules settled in minutes what the rounds had not. Phase 2 asks for the same reading from a real window for that reason.
