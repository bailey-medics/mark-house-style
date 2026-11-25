# Terminal tab icons plan

The checkout name extension, in `vscode/checkout-name/`, opens Claude and tmux sessions as terminal tabs in VS Code's editor area, each with its project's banner icon on the tab. The pictures showed at first and then stopped in every window, leaving a blank space on the tab. All the windows run on the Mac and reach the dev box through a VS Code tunnel, so the extension runs on the box and the window draws on the Mac. Two separate faults are behind it, and both are now found. The window fetches each picture from the box over the tunnel, and some of those requests stick open for ever: six stuck requests fill VS Code's allowance of connections, and after that no picture loads in any window until VS Code is quit. And a tab restored by "Developer: Reload Window" loses its icon whatever happens to the fetch.

The outcome wanted is a picture on every tab the extension opens, that survives a reload. Phases 1 and 2 record what was built, what was ruled out and how the faults were found, on the box and then on the Mac. Phase 3 is the fix: stop fetching the picture at all, and open the tabs afresh after a reload.

## Open questions

- [x] **Why is a newly opened tab blank in a tunnel window, when the same build draws it in a window on one machine?** - Its picture is fetched through the tunnel, and the request can stick open with no answer. A window on one machine reads the file from its own disk. Answered on 25 November 2026 by Claude on the Mac, from VS Code's web cache and process list, and confirmed to the second by the tunnel's log on the box. Phase 2 has the detail.

- [ ] **Does VS Code take a `data:` address as a terminal's icon?** From reading 1.144.1's code it should, but it is untested. Phase 3's first step tries it, and the rest of that phase depends on the answer.

- [ ] **Should the tabs keep full-colour pictures, or fall back to a built-in icon in one of VS Code's eight terminal colours?** The built-in icons (a robot for Claude, 0s and 1s for tmux) drew in every window and survived reloads. Mark's to decide, if the `data:` address does not work.

## Before running /f

- [ ] **This plan is not for `/f` as it stands.** Phase 3's first step has to be tried in a real tunnel window on the Mac, and somebody has to look at the tab. Tick this once that step is done and the steps after it are settled.

## Phase 1: What was built, and what was ruled out on the box

- [x] Open each session with a picture on its tab. `terminals.js` names a picture for each project (`quill.png`, `turva.png`, `juttu.png`, `arnie.png`, `digest.png`, `mark-house-style.png`, and `general.png` for Owl and anything else), and `extension.js` passes it as the terminal's `iconPath`: `vscode.Uri.joinPath(context.extensionUri, "icons", spec.image)`. The terminal has no `name`, because VS Code shows a name it was given in place of the title tmux sends. First shipped as version 0.6.0 of the extension.

- [x] Learn how VS Code draws a picture on an editor-area terminal tab, from its source at the build the windows run (1.144.1, commit `261c84cb1eddf11235f9e2c921425e9663fbe556`). Three things have to hold, and each can be checked in the window:

  - **The tab's label carries two classes**, `terminal-uri-icon-<key>` and `terminal-uri-icon`. `getUriClasses` in `terminalIcon.ts` adds them only when the terminal's icon is a real `URI` object in the window. The key is a hash of the picture's path, in base 36, so it changes with every installed version of the extension.
  - **A style rule exists for that class.** `updateStyles` in `terminalService.ts` writes `.monaco-workbench .terminal-tab.<class>::before {content: ''; background-image: url(...)}` for each terminal whose icon is `instanceof URI`.
  - **The picture loads from that URL.** Otherwise the rule applies and draws nothing. This is the one that fails.

  A third rule explains the blank space: `terminal.css` has `.monaco-workbench .terminal-tab:not(.terminal-uri-icon)::before { background-image: none !important; }`. So a terminal tab with no picture class gets no icon at all, and the space stays.

- [x] Check the picture files. All seven were in every installed version under `~/.vscode-server/extensions/local.checkout-name-<version>/icons/`, and the VS Code server on the box returned each with `200 image/png` when asked for it as a window would, through `/vscode-remote-resource?path=...`. Mark suspected the rounded corners added in 0.6.3, so the pictures from 0.6.2 were copied over the installed 0.6.4 ones and a Turva window reloaded: still blank. That test proved nothing either way, as Phase 2 shows: every request was hanging by then, whatever the picture. The rounding is cleared by other evidence, in Phase 2.

- [x] Rule out the extension's code. `extension.js` and `terminals.js` are the same in 0.6.2 and 0.6.3 apart from a comment. Only the pictures and the folder's name changed.

- [x] Rule out the style rule. The exact rule, built as `cssValue.className` and `cssValue.asCSSUrl` build it, was run in headless Chrome on the box for all seven pictures in three versions. All 21 rules parsed and applied. The hash is negative for some paths, which gives a class with a double hyphen, and the working and failing cases first seemed to follow its sign. They do not.

- [x] Rule out the tab's title length. An earlier VS Code bug hid the icon on a narrow editor tab. A Turva tmux tab was given a long title from the box, with `tmux set-option -t "=turva-tmux:" set-titles-string "..."`, and stayed blank.

- [x] Rule out the settings. Quill Medical, Turva and Juttu each set `terminal.integrated.tabs.title` to `${sequence}` and empty `terminal.integrated.tabs.description` in their own `.vscode/settings.json`, and from 0.6.4 the extension sets both as defaults for every window. Nothing in any of them touches tab icons.

- [x] Reproduce in a lab on the box, and find the reload fault. VS Code 1.147.0 is installed on the box as a desktop app. It was run on a hidden screen (`xvfb-run`) with a scratch profile, a scratch extensions folder holding the extension, and `--remote-debugging-port`, and its window was read through Chrome's debugging protocol. The lab copy of the extension ran `sleep 900` in place of the `just` recipe, and had a file trigger for commands, because key presses sent through the debugger did not reach VS Code's key bindings. Findings:

  - **A newly opened tab is right.** Both classes on the label, the rule in the page, and the picture loaded. The lab window reads the picture from its own disk, which is why it never saw the sticking fetch.
  - **A tab restored by "Developer: Reload Window" loses its picture.** After the reload its label has neither class and the page has no rule for it. Claude on the Mac confirmed why in 1.144.1's code: the icon becomes a real `URI` only in `resolveShellLaunchConfig`, as the terminal's process is created, and a restored terminal attaches to its old process and skips that. This is VS Code's fault, not the extension's, and it stands on its own: any picture tab goes blank at the next reload.
  - **A tab opened after the reload is right again.**

- [x] Record the state this left on the box. The installed 0.6.4 holds the square pictures from 0.6.2, not the rounded ones in the repository. `~/.venvs/notifier` now exists on the box, with Pillow, made by `tab-icons.sh`. The Turva window had several tabs attached to the same sessions, from testing.

## Phase 2: Find where the picture is lost, on the Mac

- [x] Take the reading from the Mac. The console line first written here was dropped: it waits for the picture to load, so with a stuck request it would never have returned. Claude on the Mac read VS Code's web cache, logs and process list instead, on 25 November 2026:

  - **A new tab had its classes and its style rule, and the window did ask for the picture.** The request neither failed nor finished, so nothing was logged on the Mac.
  - **At 15:50, VS Code's network process held 8 picture requests open and empty.**
  - **The same 8 addresses, fetched with `curl` from the Mac through the same local tunnel port at about 15:55, each gave `200 image/png` in 0.13 seconds.** 27 of 27 fetches worked. So the box, the tunnel, the files, the path and the token were all fine then.
  - **VS Code allows 6 web connections to one host, and nothing loaded after the sixth stuck request.** The inference is that six stuck requests filled the pool and every later one queued behind them, in every window on that tunnel.
  - **A full quit of VS Code cleared it.** Quill's 0.6.4 picture then loaded, with a 200, at 16:08:37. "Reload Window" would not have cleared it, since the network process outlives a window.

- [x] Set the Mac's picture requests beside the tunnel's log on the box. Each stuck request has a warning in the log in the same second, each good one has none, and the two queued ones never reached the box. The log is `journalctl --user -u code-tunnel.service`, and every line below is on `rpc.37`, the one connection that carried all the Mac's windows from 14:27:49 (`rpc.18` before that):

  - **14:22:53 - loaded, 0.6.0 quill.** `Attached to server` at 14:22:53.336. No warning.
  - **14:28:18 - stuck, 0.6.1 quill.** `warn error handling call: NoAttachedServerError` at 14:28:18.455.
  - **14:30:03 - stuck, 0.6.1 turva.** The same warning at 14:30:03.192.
  - **14:31:52 - stuck, 0.6.2 arnie.** The same warning at 14:31:52.369.
  - **14:36:01 - loaded, 0.6.3 arnie, rounded.** `Attached to server` at 14:36:01.474. No warning.
  - **14:36:45 - stuck, 0.6.3 turva.** The same warning at 14:36:45.165.
  - **14:38:03 - loaded, 0.6.3 juttu, rounded.** `Attached to server` at 14:38:03.410. No warning.
  - **14:40:19 - stuck, 0.6.4 arnie.** The same warning at 14:40:19.177.
  - **14:43:34 - stuck, 0.6.4 juttu, the sixth.** The same warning at 14:43:34.192.
  - **15:08:43 and 15:11:16 - stuck, 0.6.4 turva and quill.** Nothing in the log at either time, which fits requests queued on the Mac and never sent.

- [x] Read what the warning means, in the tunnel's source (`cli/src/tunnels/control_server.rs` at 1.147.0, the version the tunnel ran until 16:02). `NoAttachedServerError` is raised in two places: `handle_call_server_http`, when the connection has no server, and `handle_server_message`, when bytes arrive for a socket that has no bridge to the server registered. `Attached to server` is logged by `attach_server_bridge` each time a new socket to the server is bridged. So a picture that loaded opened a new socket, and one that stuck sent its request down a socket whose far end was no longer there. The tunnel answered that with an error on its own channel, and nothing closed the Mac's end of the connection, which waited with no timeout. The likely trigger, not tested, is a kept-alive connection: the server on the box closes an idle one, the Mac's end of the forwarded port stays open, and the next request reuses it.

- [x] Clear the tunnel's update of blame. The tunnel tool updated itself to 1.148.0 at 14:28:07.177, and its file was replaced at 14:28:08.432, eleven seconds before the first stuck request. But the running tunnel kept 1.147.0 in memory until 16:02:47, and the same warning is in the log before the update: at 13:31:00.890, 14:27:26.469 and 14:27:45.714, and six times in the first minute after the tunnel started at 06:55. The fault is older than the update and older than the pictures. Built-in icons need no fetch, which is why it never showed before 0.6.0.

- [x] Drop two steps this overturned. Installing 0.6.2 again is not needed: 0.6.1 and 0.6.2 stuck too, so the fault does not follow the extension's version. And the rounding is cleared: two rounded pictures loaded, at 14:36:01 and 14:38:03.

- [x] Record the tunnel going offline, since it muddied the afternoon. At 16:02:47, when the last window closed, the tunnel shut to finish its update and started its new version, which found the old process still alive and attached to it instead of taking over. The service still showed as running with no tunnel hosted. `systemctl --user restart code-tunnel.service` at 16:06:44 brought it back. No tmux session was lost: the tmux server belongs to another service. The restart also cleared the server's obsolete extension versions, so only 0.6.4 is installed now.

## Phase 3: Make the pictures last

- [ ] Give the terminal its picture as a `data:` address, so nothing is fetched and nothing can stick. In `extension.js`, read the picture's bytes as the extension starts (`fs.readFileSync` on the file under `context.extensionUri.fsPath`), and pass `vscode.Uri.parse("data:image/png;base64," + bytes.toString("base64"))` as `iconPath`. Use a smaller picture: the address goes into a style rule in the page and into the terminal's saved state, and the tab draws it at 16 pixels, so have `tab-icons.sh` write 64 pixel pictures in place of 256. Try it first in the lab on the box, as in Phase 1, reading the tab's classes, rule and computed background. Then try it in a tunnel window on the Mac. Things to watch: the rule's address passes through `CSS.escape`, which puts a backslash before most punctuation, and a `data:` address is nearly all letters, digits, `+`, `/` and `=`; and the class key is a hash of the address's path, which for a `data:` address is the whole picture. Write the result into the open question above.

- [ ] If the pictures must stay fetched, bump the extension's version whenever a picture changes. The server sends `Cache-Control: public, max-age=31536000` for an extension's files, and the address holds the version, so the Mac keeps each picture for a year for each version. Installing the same version again shows nothing new on the Mac: it holds the square 0.6.4 quill now. A `data:` address makes this step moot.

- [ ] Stop a reload blanking the tabs. This is needed whatever the first step finds. VS Code offers no way to set an icon on a terminal it has restored, so the tab has to be opened afresh. Open each terminal with `isTransient: true`, so VS Code does not restore it, keep the list of open sessions in the extension's `workspaceState`, and open them again as the window starts. tmux holds the sessions, so each tab comes back where it left off. Decide what "open" means when a tab is closed by hand: the list should drop it, or it will come back at the next reload.

- [ ] Stop each click opening another tab onto a session that already has one in the window. The Turva window ended the day with six tabs on one Claude session. A click on a session that is already open in the window should show that tab. The extension can keep the `Terminal` it made for each session and call `show()` on it.

- [ ] If a `data:` address is not accepted, go back to built-in icons. Version 0.5.0 gave Claude a robot and tmux the 0s and 1s (`robot` and `file-binary`), each in the project's colour from VS Code's eight terminal colours. Those drew in every window, need no fetch, and survived a reload. The colour table is still in `terminals.js`, used for the Sessions panel.

## Phase 4: Tidy up

- [ ] Install the repository's version on the box with a new version number, `just -g checkout-name-install`, and reload each window. The number has to change so the Mac does not show its cached square pictures for 0.6.4.

- [ ] Close the spare tabs in each window, then check `tmux list-sessions -F '#{session_name} #{session_attached}'` shows one client for each session.

- [ ] Update `vscode/checkout-name/README.md` for whatever Phase 3 changed, including why the picture is not fetched and that a restored tab cannot keep an icon.

## Decisions

- **Avoid the fetch, rather than mend it** - the sticking request is a fault in VS Code's tunnel, in code this repository does not own, and a fix there would take a release to arrive, if it came. Carrying the picture in the address removes the request altogether. The fault is still worth reporting to VS Code, with the timings in Phase 2 as evidence, since anything else fetched through a tunnel can stick the same way.

- **The pictures are made, not hand-edited** - `tab-icons.sh` builds each tab picture from its banner icon as the same rounded square, and `just -g checkout-name-icons` runs it. The rounding was suspected of breaking the icons and is cleared: two rounded pictures loaded.

- **Read the window, do not guess at it** - several rounds of "reload and look" each tested one guess, and each guess was wrong. The lab on the box found the reload fault in minutes by reading the tab's own classes and rules, and the Mac found the sticking fetch by reading VS Code's own cache and processes. Neither needed anybody to describe what they saw.
