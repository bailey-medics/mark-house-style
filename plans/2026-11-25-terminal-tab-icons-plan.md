# Terminal tab icons plan

The checkout name extension, in `vscode/checkout-name/`, opens Claude and tmux sessions as terminal tabs in VS Code's editor area, each with its project's banner icon on the tab. The pictures showed at first and then stopped in every window, leaving a blank space on the tab. All the windows run on the Mac and reach the dev box through a VS Code tunnel, so the extension runs on the box and the window draws on the Mac. Two separate faults are behind it, and both are now found. The window fetches each picture from the box over the tunnel, and a request that reuses a connection left idle for more than about five seconds gets no answer and waits for ever: six stuck requests fill VS Code's allowance of connections, and after that no picture loads in any window until VS Code is quit. And a tab restored by "Developer: Reload Window" loses its icon whatever happens to the fetch.

The outcome wanted is a picture on every tab the extension opens, that survives a reload. Phases 1 and 2 record what was built, what was ruled out and how the faults were found, on the box and then on the Mac. Phase 3 is the fix: stop fetching the picture at all, and open the tabs afresh after a reload.

## Open questions

- [x] **Why is a newly opened tab blank in a tunnel window, when the same build draws it in a window on one machine?** - Its picture is fetched through the tunnel, and the request can stick open with no answer. A window on one machine reads the file from its own disk. Answered on 25 November 2026 by Claude on the Mac, from VS Code's web cache and process list, and confirmed to the second by the tunnel's log on the box. The trigger, a reused idle connection, was reproduced outside VS Code the same afternoon. Phase 2 has the detail.

- [x] **Does VS Code take a `data:` address as a terminal's icon?** - Yes. In the lab on the box, VS Code 1.147.0, a new tab had both picture classes, a style rule whose address began `data:image/png;base64,`, and a 64 by 64 picture that loaded. Answered on 25 November 2026. Seen in tunnel windows on the Mac the same evening: Phase 3 has that step.

- [x] **Should the tabs keep full-colour pictures, or fall back to a built-in icon in one of VS Code's eight terminal colours?** - Keep the pictures. The `data:` address works through the tunnel, so there is nothing to fall back from. The built-in icons stay only for a picture whose file cannot be read. Settled on 25 November 2026 by the test in Phase 3.

## Before running /f

- [x] **This plan is not for `/f`.** Its steps needed a window on the Mac and somebody to look at it, so each was built and tried by hand as the cause came to light, on 25 November 2026. Nothing is left for `/f` to build.

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

- [x] Read what the warning means, in the tunnel's source (`cli/src/tunnels/control_server.rs` at 1.147.0, the version the tunnel ran until 16:02). `NoAttachedServerError` is raised in two places: `handle_call_server_http`, when the connection has no server, and `handle_server_message`, when bytes arrive for a socket that has no bridge to the server registered. `Attached to server` is logged by `attach_server_bridge` each time a new socket to the server is bridged. So a picture that loaded opened a new socket, and one that stuck sent its request down a socket whose far end was no longer there. The tunnel answered that with an error on its own channel, and nothing closed the Mac's end of the connection, which waited with no timeout. The likely trigger is a kept-alive connection: the server on the box closes an idle one, the Mac's end of the forwarded port stays open, and the next request reuses it. That was tested afterwards and holds: see the reproduction step further down this phase.

- [x] Clear the tunnel's update of blame. The tunnel tool updated itself to 1.148.0 at 14:28:07.177, and its file was replaced at 14:28:08.432, eleven seconds before the first stuck request. But the running tunnel kept 1.147.0 in memory until 16:02:47, and the same warning is in the log before the update: at 13:31:00.890, 14:27:26.469 and 14:27:45.714, and six times in the first minute after the tunnel started at 06:55. The fault is older than the update and older than the pictures. Built-in icons need no fetch, which is why it never showed before 0.6.0.

- [x] Drop two steps this overturned. Installing 0.6.2 again is not needed: 0.6.1 and 0.6.2 stuck too, so the fault does not follow the extension's version. And the rounding is cleared: two rounded pictures loaded, at 14:36:01 and 14:38:03.

- [x] Record the tunnel going offline, since it muddied the afternoon. At 16:02:47, when the last window closed, the tunnel shut to finish its update and started its new version, which found the old process still alive and attached to it instead of taking over. The service still showed as running with no tunnel hosted. `systemctl --user restart code-tunnel.service` at 16:06:44 brought it back. No tmux session was lost: the tmux server belongs to another service. The restart also cleared the server's obsolete extension versions, so only 0.6.4 is installed now.

- [x] See it stick again after the restart, on the new tunnel. Mark opened a Juttu window at 16:11:58 and a session tab in it: blank. On the Mac, the request for 0.6.4's `juttu.png` was made at 16:12:06, and VS Code's network process held it open and empty, as before. So the fault is in 1.148.0 too, and it needs no reload and no update, only a second picture. The Mac's own half of the tunnel names the connection. The Remote - Tunnels extension (`ms-vscode.remote-server` 1.5.4) runs a proxy on the Mac, `proxyServer.js`, and its log lists every connection it carries. It carried one at 16:08:34, for Quill's picture, and no new one for Juttu's request. So Juttu's request went down the connection Quill's had left open, three and a half minutes idle.

- [x] Reproduce it outside VS Code, with one connection and a pause. From the Mac, through the tunnel's local port, a short Python script opened one kept-alive connection, fetched a picture, waited, and fetched it again on the same connection:

  - **A pause of 1 second or 3 seconds** - the second fetch gave `200` in 0.07 seconds.
  - **A pause of 8 seconds or 30 seconds** - the second fetch had no answer in 15 seconds, and the connection was never closed.

  So the line falls between 3 and 8 seconds, which fits the 5 seconds a Node server keeps an idle connection by default. After that the server on the box has closed its end, and nothing tells the Mac. VS Code's network stack on the Mac (Chromium, in Electron 43.8.3) keeps an idle connection for reuse for about five minutes. That figure is Chromium's default and was not measured here. Together they give the rule the whole afternoon followed: a picture loads when it gets a new connection, and sticks when another fetch through the tunnel has left a connection idle in the last few minutes. The stuck request at 14:36:45 reused the connection the good one opened at 14:36:01, and the one at 14:40:19 reused the one from 14:38:03. `curl` always worked because it opens a new connection each time. This test is the one to send with a report to VS Code, since it needs no extension and no window.

- [x] Check the tunnel's log on the box for the same warning at three more times: 16:12:06, Juttu's stuck request, and within a few seconds of 16:15:07 and 16:15:52, the two test fetches that got no answer. The log since the 16:06 restart has exactly three `NoAttachedServerError` warnings, now on `rpc.0`. One is at 16:12:06.861, which ties Juttu's stuck request to the warning on the new tunnel, 1.148.0. The other two are at 16:15:47.700 and 16:16:32.889. Neither is within a few seconds of the Mac's times: each is 40.7 seconds after one of them. But they are 45.2 seconds apart, as the Mac's two times are 45 seconds apart, and nothing else was warned of in that quarter of an hour. So they are very likely the two test fetches, with the test's times taken about 40 seconds before each stuck fetch was sent: its start, perhaps, not the fetch after the pause. Worth a look at how the test took its times before the figures go into a report.

## Phase 3: Make the pictures last

- [x] Give the terminal its picture as a `data:` address, so nothing is fetched and nothing can stick. `extension.js` reads the picture's bytes from the file under `context.extensionUri.fsPath`, once for each picture, and `pictureAddress` in `terminals.js` turns them into `data:image/png;base64,...`, passed as `iconPath` through `vscode.Uri.parse`. `tab-icons.sh` now writes 64 pixel pictures in place of 256, each between 1.4 and 2.4 KB, and a test fails if one grows past 4 KB. Tried in the lab on the box, as in Phase 1: the tab had both classes, the rule's address came through `CSS.escape` intact at about 2,300 characters, and the picture loaded at 64 by 64. If a picture's file cannot be read, the tab opens with the built-in icon and the project's colour, and the reason is logged. Shipped as 0.7.0.

- [x] Try 0.7.0 in a tunnel window on the Mac. The test that counts is two tabs of different projects opened about a minute apart: with fetched pictures the second one sticks, as Phase 2 shows. Mark quit VS Code fully, opened windows on four different repositories on the box, two minutes between the first and the second, and opened sessions in each: every tab had its picture. Done on 25 November 2026. Still worth having: Claude on the Mac confirming that VS Code's web cache gained no entry for a picture, which would show that nothing was fetched and not merely that nothing stuck.

- [x] If the pictures must stay fetched, bump the extension's version whenever a picture changes. Not needed: nothing is fetched now. The reason stands as a warning for anything else an extension has a window fetch. The server sends `Cache-Control: public, max-age=31536000` for an extension's files, and the address holds the version, so the Mac keeps each file for a year for each version, and installing the same version again shows nothing new there.

- [x] Stop a reload blanking the tabs. VS Code offers no way to set an icon on a terminal it has restored, so the tabs are opened afresh. Each terminal opens with `isTransient: true`, which VS Code does not restore. The extension keeps the keys of the open sessions in its `workspaceState`, under `checkoutName.openSessions`, and opens them again as the window starts. `sessions.js` names the keys, `claude`, `tmux` and `tmux-2` to `tmux-99`, and drops anything else it reads back. A tab closed by hand leaves the list. A tab closed by the reload stays in it: VS Code gives the reason a terminal closed, `TerminalExitReason.Shutdown`, and as a second guard the list is rewritten a second and a half after a close, which a reload never reaches. One finding from the lab changed the build: four terminals opened in one burst as the window started left three with no process, blank tabs that never came to life. So they are opened one at a time, each waiting for the one before to start. In the lab, four tabs came back alive with their pictures after a reload, a tab closed by hand stayed closed after the next, and its number was the one "another tmux shell" then took.

- [x] Stop each click opening another tab onto a session that already has one in the window. The extension keeps the `Terminal` it made for each session and shows it on a second click. "Another tmux shell" is now the first number from 2 up that the window has no tab for, worked out in `nextShellKey`, where it used to run `just -g tmux-window next` and take whichever shell no terminal anywhere was showing. The extension has to know which shell a tab holds to open it again after a reload, and `next` did not say. `just tw next` is still there for a plain terminal. In the lab, a second click on Claude left one tab, and two clicks on "another" gave shells 2 and 3.

- [x] If a `data:` address is not accepted, go back to built-in icons. Not needed: the address is accepted, in the lab and through the tunnel. The robot and the 0s and 1s, in the project's colour, remain as what a tab gets when its picture's file cannot be read.

## Phase 4: Tidy up

- [x] Quit VS Code fully on the Mac once the fix is installed, and open it again. Done on 25 November 2026, before the test in Phase 3. It cleared the Juttu request stuck since 16:12:06, which only a full quit does.

- [x] Install the repository's version on the box with a new version number, `just -g checkout-name-install`. Done as 0.7.0 on 25 November 2026. Each window still needs a reload to take it up. A window's tabs from 0.6.4 come back blank that once, since VS Code restores them: close them and open the sessions again from the buttons.

- [ ] Close the spare tabs in each window, then check `tmux list-sessions -F '#{session_name} #{session_attached}'` shows one client for each session.

- [x] Update `vscode/checkout-name/README.md` for whatever Phase 3 changed, including why the picture is not fetched and that a restored tab cannot keep an icon. Done with 0.7.0.

## Decisions

- **Avoid the fetch, rather than mend it** - the sticking request is a fault in VS Code's tunnel, in code this repository does not own, and a fix there would take a release to arrive, if it came. Carrying the picture in the address removes the request altogether. The fault is still worth reporting to VS Code, with the test and the timings in Phase 2 as evidence, since anything else fetched through a tunnel can stick the same way.

- **No "Claude" and "Tmux" in the list beside the terminal panel's "+"** - 0.7.0 drops the two terminal profiles. VS Code opens a profile's terminal itself, so the extension cannot keep one tab for its session or open it again after a reload, and it would go blank at the next one. The buttons and the Sessions panel are the two ways in.

- **The pictures are made, not hand-edited** - `tab-icons.sh` builds each tab picture from its banner icon as the same rounded square, and `just -g checkout-name-icons` runs it. The rounding was suspected of breaking the icons and is cleared: two rounded pictures loaded.

- **Read the window, do not guess at it** - several rounds of "reload and look" each tested one guess, and each guess was wrong. The lab on the box found the reload fault in minutes by reading the tab's own classes and rules, and the Mac found the sticking fetch by reading VS Code's own cache and processes. Neither needed anybody to describe what they saw.
