# Voice bridge build plan

Mark wants to talk out loud, back and forth, with a Claude Code session on
the dev box, from the Claude app on his phone. Remote Control and Projects
both take dictation only, and no route inside Anthropic's own system carries
a voice conversation into a running session. The one way to get it is a
bridge: voice mode in an ordinary claude.ai chat calls a custom connector (a
remote MCP server), which passes Mark's words into a session through a
Claude Code channel, and brings the answer back to be read aloud.

This repository is public, so the plan names no address, device or private
repository, and the code holds no secret. The outcome is a test first: a
channel on the box alone, then one 10 minute window through a Cloudflare
tunnel on Mark's own domain, with no login, to prove the whole pipeline
works. Only then the real bridge, behind a login, and off by default. The
code lives in `voice/` in this repository. This repository takes direct
commits to `main`, so the build is done by hand, not by `/t-f`.

## Open questions

- [x] **Is the bridge to be built at all?** - Build what is needed to test the pipeline end to end, and drop the login for a 10 minute test window. Answered in `/t-g`, 21 November 2026.

- [x] **Where does the code live?** - In `voice/` at the top level of `mark-house-style`, with its own `package.json` and README. The repository is public on purpose, and the code holds no secret or address. Answered in `/t-g`, 21 November 2026.

- [x] **Where does this plan live?** - Here, in `mark-house-style/plans/`, with every mention of the private repository and other identifying details taken out. Answered in `/t-g`, 21 November 2026.

- [x] **Python or TypeScript?** - TypeScript, run with Node. Answered in `/t-g`, 21 November 2026.

- [x] **In what order does the test run?** - Mark's no-code DeepWiki test first, then the channel test on the box only (Phase 2), then one 10 minute tunnel window with both `ping` and `ask` (Phase 3), so the door opens only once. Answered in `/t-g`, 21 November 2026.

- [x] **Which guards stay for the 10 minute test?** - The free ones: a random, unguessable URL path; callers outside Anthropic's two address ranges refused by the bridge; the test session in an empty scratch folder in default permission mode, so every command asks first; and the door closing by itself after 10 minutes. Answered in `/t-g`, 21 November 2026.

- [x] **Which door for the test?** - A Cloudflare quick tunnel: a throwaway `trycloudflare.com` address, no domain or account, changing every run. It has no filter at Cloudflare's edge, so the bridge does the address check. Answered in `/t-g`, 21 November 2026.

- [x] **Which door for the real bridge: a tunnel, or a relay hosted elsewhere?** - A named Cloudflare tunnel, on a domain Mark already owns, moved to Cloudflare for free. A fixed address, and an address filter at Cloudflare's edge as well as in the bridge. Answered in `/t-g`, 21 November 2026.

- [x] **Which session can voice reach?** - One dedicated voice session, started by hand in a folder of its own with nothing else in it. Never a project's own session. Answered in `/t-g`, 21 November 2026.

- [x] **Is "voice can discuss but never `implement`" agreed?** - No. A spoken `implement` counts like a typed one. Messages are still tagged as voice, so the session and the log can tell them apart. Answered in `/t-g`, 21 November 2026.

- [x] **How long idle before voice switches itself off?** - Two hours. Answered in `/t-g`, 21 November 2026.

- [x] **Can the voice session start by itself at boot?** - No. It is the dedicated session, started by hand, so the two start-up dialogs a development channel brings are answered by Mark at the keyboard. It is left out of the boot script. Settled from the answers above, 21 November 2026.

- [x] **How does the plan get past the blocked live test?** - Move it to a named Cloudflare tunnel on Mark's own domain, still with no login for 10 minutes, and with a filter at Cloudflare's edge as well as in the bridge. Research on 21 November 2026 found that Cloudflare most likely refuses claude.ai's second client on throwaway `trycloudflare.com` addresses. Answered in `/t-g`, 21 November 2026.

- [x] **One tool or three?** - Keep three. Users report that since 15 November 2026 voice mode loads only one tool from each custom connector, which looks like a fault on Anthropic's side. The live test notes which tools voice mode can see, and this question comes back if it sees only one. Answered in `/t-g`, 21 November 2026.

- [x] **How is `ask` marked?** - Honestly: not read-only, because its words can lead the session to change things. `ping` and `check_reply` are read-only. Anthropic's connector docs say a tool that is not read-only asks before each call, so the live test notes how often voice mode asks, and this question comes back if that makes voice unusable. Answered in `/t-g`, 21 November 2026.

- [x] **Which permission mode does the real voice session use?** - Auto mode, Mark's usual default, so spoken work flows without a tap to approve each step. Answered in `/t-g`, 21 November 2026.

- [x] **How far can the voice session reach?** - Its own folder only. It cannot read or change anything else on the box, so it knows nothing of Mark's projects, and a spoken `implement` can only change files in `~/voice-session`. Answered in `/t-g`, 21 November 2026.

- [x] **Can the voice session message Mark's other sessions?** - No. It is kept fully apart, with the messaging tools denied in its folder's settings. Answered in `/t-g`, 21 November 2026.

- [x] **How long before Mark has to sign in again?** - A week. The access token lasts one hour and the refresh token seven days. Answered in `/t-g`, 21 November 2026.

- [x] **How is the sign-in page guarded?** - By two separate checks. Cloudflare Access stands in front and emails Mark a one-time code before the page loads. Then the bridge asks for its own password, and locks an address out for an hour after five wrong tries. Answered in `/t-g`, 21 November 2026.

- [x] **Do the support reference codes stay in this public plan?** - No. They point to the connection attempts on Mark's account, and only Anthropic can look them up. Mark holds them. Answered in `/t-g`, 21 November 2026.

- [x] **Is the login written by hand?** - No. The MCP SDK ships an OAuth server for Express, `mcpAuthRouter`, and Express and `express-rate-limit` are already installed with it. The bridge supplies only the password page and the storage. The SDK offers a registration address only when the storage has a `registerClient` method, and this one has none. Settled from the code, 21 November 2026.

## Before running /f

- [x] **Run the DeepWiki test, before Phase 3's live test.** In claude.ai, open Settings, then Connectors, and add a custom connector with the address `https://mcp.deepwiki.com/mcp` and no sign in. On the phone, start voice mode in an ordinary chat and say: "Use DeepWiki to tell me what the modelcontextprotocol python-sdk repository is." Note whether it calls the tool and reads the answer aloud, then remove the connector. If voice mode will not call it, stop: the bridge cannot work. Half done on 21 November 2026: the connector was added and connected, and the voice part is still to do. Overtaken on 23 November 2026: the live test showed voice mode calling a custom connector, which is all this test was for.
- [x] **Add the test connector when Phase 3 asks for it.** Only Mark can do that, from his own account, with "No sign in". Done on 23 November 2026: it connected at the first try on the named tunnel.
- [x] **Move the domain to Cloudflare, before Phase 3's named tunnel step.** Point the domain Mark already owns at Cloudflare's name servers, on the free plan. Done on 23 November 2026: the registry lists Cloudflare's name servers, and Cloudflare shows the domain as active. The domain's old forward was dropped, by Mark's choice, so it now holds only a mail policy record.
- [x] **Authorise `cloudflared` for the domain, when Phase 3 asks for it.** Run `cloudflared tunnel login` on the box and pick the domain in the browser page it opens. Done on 23 November 2026: the certificate is in `~/.cloudflared/`, mode `0600`, and `cloudflared tunnel list` answers.
- [ ] **Allow claude.ai's client in the Cloudflare zone, if Phase 3's check shows it blocked.** The check on 23 November 2026 showed it is not blocked, so there is nothing to do here unless the live test fails. In the Cloudflare dashboard, set the zone's bot and AI agent settings so that the user agent `Claude-User` is let through on `<the voice subdomain>`, and switch Bot Fight Mode off for it.
- [x] **Add the edge filter, when Phase 3 asks for it.** In the Cloudflare dashboard, add a custom rule on `<the voice subdomain>` that blocks every caller outside `160.79.104.0/21` and `153.61.208.0/20`. Done on 23 November 2026, and checked from the box.
- [ ] **Check two-factor sign-in is on for the claude.ai account, before Phase 5**, since that account becomes a key to the voice session.
- [ ] **Set the sign-in password and make the client secret, at the end of Phase 4.** In `voice/`, run `node scripts/voice-init.ts`. It asks for a password, which Mark takes from the password manager, and prints a new client ID and client secret once: put both in the password manager. The bridge keeps only hashes, in a file outside the repository.
- [ ] **Set up Cloudflare Access for the sign-in page, when Phase 5 asks for it.** In Cloudflare's Zero Trust dashboard, on the free plan, add a self-hosted application for `<the voice subdomain>` on the path `/authorize`, with a policy that allows only Mark's own email address, by one-time code. Leave every other path out of Access, because Anthropic's servers call those.
- [ ] **Re-cut the edge filter for the login, when Phase 5 asks for it.** Edit the rule from Phase 3 so that it no longer covers the path `/authorize`, which has to open in Mark's browser. Every other path stays limited to Anthropic's two ranges.
- [ ] **Add the real connector in claude.ai when Phase 5 asks for it**, with "Use your own OAuth client", the client ID and the client secret.

## Phase 1: Prepare, changing nothing

Read-only. No file is written outside this plan, no service is started, and
nothing is opened to the network.

- [x] Read the earlier findings on voice chat with a Claude Code session, in Mark's private notes, top to bottom, including what stays risky even with every guard. Done 21 November 2026. The findings are not copied here.

- [x] Read the channel docs, <https://code.claude.com/docs/en/channels-reference.md> and <https://code.claude.com/docs/en/channels.md>, and the custom connector page, <https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp>. Read 21 November 2026; neither shows a last-updated date. Channels are a research preview, so read them again before each phase. What matters for the build:
  - **The session starts the channel itself, over stdio**, from an MCP config. The channel is a child process of the session, not a service. It declares `capabilities.experimental['claude/channel']: {}` and pushes `notifications/claude/channel` with `content` (a string) and `meta` (a string map). Claude answers by calling an ordinary tool the channel exposes, such as `reply`.
  - **A `meta` key may hold only letters, digits and underscores.** Any other key is silently dropped. Claude Code sets the `source` attribute itself.
  - **A custom channel needs `--dangerously-load-development-channels server:<name>`, and brings two dialogs at start.** The development-channel warning ("I am using this for local development"), and, on the first run in a folder, the MCP consent dialog ("New MCP server found in this project"). The docs give no way to accept either ahead of time.
  - **The flag works in interactive sessions only.** With `-p` it is ignored. It does not appear in `claude --help` during the preview.
  - **Nothing is said about `--remote-control` or `--continue` with a channel.** Phase 2 has to test it.
  - **Approving tool use from a channel is a separate capability, `claude/channel/permission`.** A server that leaves it out can never approve a Bash, Write or Edit prompt. Before 2.1.234, setting it to `false` counted as declaring it, so the channel leaves the key out altogether.
  - **A connector must be served on port 443**, and calls come from Anthropic's published ranges, `160.79.104.0/21` and `153.61.208.0/20` (<https://platform.claude.com/docs/en/api/ip-addresses>). The connector page says nothing about voice mode or a time limit for a tool call.

- [x] Check whether the Python MCP SDK can declare the channel capability and send the custom notification. Checked 21 November 2026 against the SDK's `main` branch. It takes any experimental capability and has a generic `notify(method, params)`, but `main` is mid-rewrite and the public route for a custom notification is unconfirmed. TypeScript, run with Node, was chosen instead: the docs need only `@modelcontextprotocol/sdk` and a Node-compatible runtime, and Node 26 is on the box. Bun, which the docs' examples use, is not needed.

- [x] Read the boot script that starts the box's sessions. Read 21 November 2026. Every session starts inside tmux, at boot, with nobody at the keyboard, as `claude --continue --remote-control <label> || claude --remote-control <label>`. The voice session cannot join it while the two dialogs need a person, and it is started by hand instead.

- [x] Write the files and tests the next phases need into their steps. Done 21 November 2026.

- [x] Tell Mark the preparation is done, list the open questions still unanswered, and stop. Done 21 November 2026; every open question was then answered in `/t-g`.

## Phase 2: Channel test, on the box only

Nothing in this phase is reachable from outside the box. Every path is under
`voice/`.

- [x] Set up the package: `package.json` and `package-lock.json`, with one dependency, `@modelcontextprotocol/sdk`, pinned to an exact version (1.32.2, with TypeScript 7.0.2 and `@types/node` as development dependencies), and a `test` script running `node --test`. Node 26 runs `.ts` files directly, so there is no build step. `tsconfig.json` is strict and used only for `tsc --noEmit`. Add `voice-test` and `voice-typecheck` recipes to `just/justfile`. Done 21 November 2026; the recipes are `just -g voice-test` and `just -g voice-typecheck`, which work from any folder.

- [x] Write the smallest possible channel, in `src/channel.ts`, with the stdio start-up in `src/main.ts` so tests can build the channel without starting it. It declares `experimental['claude/channel']` and `tools`, and never declares `claude/channel/permission`, not even as `false`. Its `instructions` string tells Claude that messages arrive from Mark by voice, and that each answer goes back through `reply` as short plain sentences for reading aloud. It exposes one tool, `reply(message_id, text)`. Each event carries a `message_id` in its `meta`, so two messages waiting at once each get their own answer. Done 21 November 2026.

- [x] Write the private door into the channel, in `src/socket.ts`, with the checks in `src/limits.ts` so tests can reach them. It makes a folder under `$XDG_RUNTIME_DIR` with mode `0700`, and a socket in it with mode `0600`, so only Mark's user can open it. No network port. It reads one line of JSON, `{"text": "..."}`, caps its length, and pushes it as `notifications/claude/channel` with `meta` set to `{"via": "voice"}`. It holds the connection open until `reply` answers, then writes the answer back on it. It refuses to start beside a running channel, and refuses a socket path over the 107 bytes Linux allows. Done 21 November 2026.

- [x] Write the tests. Done 21 November 2026: `just -g voice-test` ran 22 tests, 22 passed, and `just -g voice-typecheck` was clean. A smoke test of `src/main.ts` over stdio showed the real `initialize` answer and a correct `notifications/claude/channel` event.
  - **`test/channel.test.ts`** - the server declares `claude/channel` and has no `claude/channel/permission` key at all. `tools/list` returns `reply` alone. A pushed message goes out with method `notifications/claude/channel`, a string `content`, and only valid `meta` keys.
  - **`test/socket.test.ts`** - the folder is `0700` and the socket `0600`. A message goes in and its reply comes back on the same connection. An over-long message is refused and nothing is pushed. A line that is not valid JSON, or has no `text`, is refused. Two clients waiting at once each get their own answer.
  - **`test/limits.test.ts`** - a message exactly at the cap passes and one character over fails. Empty text is refused.

- [x] Write `scripts/push.ts`, the hand test client: it sends one message to the socket and prints the reply. Write `README.md`: what the channel is, how to start the test session, and how to stop it. Done 21 November 2026.

- [x] Start a throwaway Claude session in an empty scratch folder, in default permission mode, with the channel loaded (`--dangerously-load-development-channels server:<name>`), together with `--remote-control` and `--continue`. The `.mcp.json` that names the server lives in that scratch folder, not in the repository. Nobody documents this combination. If the channel does not load, or Remote Control stops working, stop and tell Mark: the fallback is typing into tmux with guard rails, which is less safe and needs its own decision. Done 21 November 2026, in `~/voice-test`: the channel loaded and Remote Control stayed active, both on a fresh start and with `--continue`. The session came up in auto mode, Mark's global default, and was switched to manual mode with Shift+Tab before any message was sent.

- [x] Push a message in with `scripts/push.ts` and check the answer comes back through `reply` as plain text. Done 21 November 2026, at the third try. The first time, Claude answered in the terminal and never called `reply`, so the channel's instructions now say that text in the terminal never reaches Mark. The second time, it called `reply`, but manual mode stopped for approval and the push client had given up. The test folder's `.claude/settings.json` now allows `mcp__voice__reply` alone, and every other tool still asks. The third time, after a restart with `--continue`, the answer came straight back: "This folder holds only a hidden Claude settings folder and a small MCP config file, with no other files."

- [x] See what the start-up dialogs do. Found 21 November 2026: a new folder also asks whether to trust it, so the first start has three dialogs. The trust and MCP consent answers are remembered, but the channel warning comes back on every start, so a start with nobody at the keyboard would sit at it. The voice session is started by hand, as already agreed, and stays out of the boot script.

## Phase 3: The whole pipeline, in one 10 minute window

The only phase with no login. Everything else stays closed, and the door
shuts by itself after 10 minutes.

- [x] Write the bridge, in `src/bridge.ts`, started by `src/bridge-main.ts`: an MCP server over Streamable HTTP, bound to `127.0.0.1` only. It serves only at a random path, `/<32 random hex characters>/mcp`, made fresh each run, printed once and never written to a file. Every other path gets a 404. Three tools:
  - **`ping(delay_seconds)`** - waits, then returns a fixed sentence. Touches nothing.
  - **`ask(text)`** - sends the words to the channel's socket and waits for the reply. There is one dedicated voice session, so the tool takes no session name.
  - **`check_reply()`** - returns an answer that came back after `ask` gave up waiting.

  Done 21 November 2026. Each request stands alone, with no session ID. It logs each request's caller, method, `Accept` and `MCP-Protocol-Version` headers, and the status it answered with, and reads at most 64 KB of body. `src/socket-client.ts` holds the socket client that `ask` and `scripts/push.ts` share.

- [x] Write the caller check, in `src/caller.ts`. A quick tunnel has no filter at Cloudflare's edge, so the bridge refuses any caller outside `160.79.104.0/21` and `153.61.208.0/20`. It reads the caller from the `CF-Connecting-IP` header, and trusts that header only on a connection from loopback, where `cloudflared` is the only thing that can connect. A request with no header, or a bad one, is refused. Done 21 November 2026. Through the tunnel, a request from the box itself was refused with 403 every time, and claude.ai's requests came from `160.79.106.x`, inside the first range.

- [x] Write the tests. Done 21 November 2026: `npm test` ran 39 tests, 39 passed, and `npx tsc --noEmit` was clean.
  - **`test/caller.test.ts`** - an address inside each range passes, one just outside each range is refused, a missing or malformed header is refused, and the header is ignored on a connection that is not from loopback.
  - **`test/bridge.test.ts`** - the wrong path gets a 404 and reaches no tool. `ping` waits as asked. `ask` returns the channel's reply. When the reply is slow, `ask` says "still working" at its time limit and `check_reply` returns the answer later.

- [x] Write `scripts/test-window.sh`. It starts the bridge, then `cloudflared tunnel --url http://127.0.0.1:<port>` under `timeout 600`, prints the full connector address with its random path, and stops both when the 10 minutes are up or on Ctrl+C. No account, no domain, nothing left running afterwards. Done 21 November 2026. `VOICE_WINDOW_SECONDS` sets the length. Mark asked for 30 minutes on the day, to have time to set up the connector, and the window ran for that long without a login.

- [x] Try the live test through the quick tunnel: start the throwaway session from Phase 2, run the window, and have Mark add the printed address in claude.ai as a custom connector with "No sign in". **It failed on 21 November 2026: claude.ai would not connect.** Five tries each gave "Couldn't reach" (Mark holds the five support references). Each time, claude.ai sent one `initialize` (sometimes twice, from two addresses), protocol `2025-11-25`, and the bridge answered 200 with a correct result in under 15 ms. claude.ai then sent nothing more: no `notifications/initialized`, no `tools/list`, and no other request reached the bridge or showed in the tunnel's log. Ruled out:
  - **claude.ai and the account** - DeepWiki, `https://mcp.deepwiki.com/mcp`, connected with "No sign in" during the same window.
  - **The tunnel and the bridge** - the official MCP SDK client, run on the box and let through for one test, connected through the quick tunnel, listed the three tools and got a ping back.
  - **The answer's form** - event stream and plain JSON both failed, with and without `listChanged`, and with and without `instructions`. DeepWiki answers as an event stream, statelessly, with no session ID, much as the bridge does.

  What was left was the `trycloudflare.com` address itself, or something only Anthropic's side can see. Research the same day found the likely cause. claude.ai connects with two clients, and Cloudflare's shared quick-tunnel zone appears to refuse the second, whose user agent is `Claude-User`, before it reaches the tunnel. Three open issues on `anthropics/claude-ai-mcp` (1214, 1241 and 1328) describe the same failure on quick tunnels since 3 November 2026, with no reply from Anthropic. So the test moves to a named tunnel, in the steps below.

- [x] Give each tool a `title` and honest annotations, in `src/bridge.ts`, with a test in `test/bridge.test.ts`. `ping` and `check_reply` are `readOnlyHint: true`. `ask` is `readOnlyHint: false` and `destructiveHint: true`, because its words can lead the session to change or delete things. Anthropic's connector docs ask for a title and the right hint on every tool, and say a read-only tool runs without asking. Done 23 November 2026. The title is given twice, at the top of the tool and in its annotations, because older clients read it from the annotations. `just -g voice-test` ran 40 tests, 40 passed, and `just -g voice-typecheck` was clean.

- [x] Confirm the cause before moving. Open a quick tunnel with nothing behind it, so nothing on the box is exposed, and send it the same request twice, changing only the user agent: once as `curl`, once as `Claude-User`. If Cloudflare answers the first with a 502, because there is no server behind the tunnel, and the second with its own 403, "Your request was blocked", the cause is confirmed. If both get the same answer, the block is not Cloudflare's. Stop and tell Mark: the fault would then be on Anthropic's side, and a named tunnel might not help. Done 23 November 2026, and **the cause is confirmed**. On a quick tunnel with nothing behind it, the request sent as `curl` and as `python-httpx` got Cloudflare's 502 each time, so it reached the tunnel. The same request sent as `Claude-User` got a 403 with the body "Your request was blocked.", twice, and never reached the tunnel.

- [x] Set up the named tunnel, with Mark at the keyboard for the browser step. Run `cloudflared tunnel login`, then `cloudflared tunnel create voice` and `cloudflared tunnel route dns voice <the voice subdomain>`. **This changes things outside the repository**: it makes a tunnel and a DNS record in Mark's Cloudflare account. Both can be deleted again. The tunnel's credentials stay in `~/.cloudflared/`, and the host name is kept in a file outside the repository, `~/.config/voice-bridge/host`, so neither is ever in a commit. Done 23 November 2026. The tunnel is named `voice`. The host file is mode `0600` in a folder of mode `0700`. A lookup made on the box just before the record existed left the box's own resolver answering "no such name" for up to 30 minutes; public resolvers had the name at once.

- [x] Change `scripts/test-window.sh` to run the named tunnel in place of the quick tunnel: `cloudflared tunnel run --url http://127.0.0.1:<port> voice`, under the same `timeout`, with the host name read from the file outside the repository. It still makes a fresh secret path each run, and still closes after 10 minutes. With a named tunnel the address stays in DNS when the window closes, but nothing answers at it. Done 23 November 2026. The script waits for the tunnel to connect before it prints the address, and refuses to start if the host file is missing or does not hold a host name. `VOICE_WINDOW_NO_SESSION=1` opens the window with no voice session running, for the two checks below that only read the bridge's log.

- [x] Check that Cloudflare lets claude.ai's client through on Mark's zone, before any rule is added. Run the window and send one request from the box with the user agent `Claude-User`. It should reach the bridge and get the bridge's own 403 from the caller check, which shows in the bridge's log. If Cloudflare blocks it first, Mark allows that client in the zone's settings, as set out under "Before running /f", and the check is run again. Done 23 November 2026, and **it gets through**. With the window open and no session, a request from the box as `curl` and one as `Claude-User` each reached the bridge, got the bridge's own 403 "Forbidden", and showed in its log as refused for being outside Anthropic's ranges. One limit: the test copies the user agent from an address that is not Anthropic's, so the live test is the real proof.

- [x] Have Mark add the edge filter, as set out under "Before running /f", then check that a request from the box is now refused by Cloudflare and no longer reaches the bridge's log. Done 23 November 2026. With the window open and no session, a request from the box as `curl` and one as `Claude-User` each got Cloudflare's own 403 block page, and the bridge's log showed no request at all.

- [ ] Run the live test on the named tunnel: start the throwaway session from Phase 2, run the window, and have Mark add the printed address in claude.ai as a custom connector with "No sign in". In voice mode on the phone, have him ask for a ping, then raise `delay_seconds` until voice mode gives up, to measure the time limit. Research suggests the phone app gives up after about 30 seconds, though Anthropic's docs say 240 seconds for claude.ai and Desktop. Set `ask`'s wait just below what is measured. Note two more things in this step, because two answered questions come back on them: which of the three tools voice mode can see, and how often it asks permission before a call. Partly done 23 November 2026. **claude.ai connected through the named tunnel at the first try**, and Mark reported the voice ping working. All three tools were called: `ping` twice, `ask` twice and `check_reply` once. Every request came from `160.79.106.x`, and none was refused. claude.ai first sends `server/discover` under protocol `2026-07-28`, which the SDK answers with a 400, and then falls back to `initialize` under `2025-11-25`. Mark said afterwards that voice mode did ask his permission before calling. Still to do: the ping timing was not run, and it is not recorded how often it asks, or whether a spoken yes is enough.

- [ ] In the same window, have Mark ask a real question by voice and check that it reaches the session and the answer is read aloud. Then have him remove the connector. Record the results, and the time limit, in this step. Partly done 23 November 2026. Two questions reached the session through `ask`. The first was answered in 18 seconds, inside the call. The second took 32 seconds: claude.ai dropped the call before `ask`'s 25 second wait was up, and the answer was fetched afterwards with `check_reply`. So the limit seems to lie between 18 and 25 seconds, unless Mark cut in, which is still to be checked. **Manual mode did not hold the session to its folder.** Asked to by voice, it wrote a file in its own scratch folder, and ran read-only shell commands across the home folder, without stopping to ask. That is the gap Phase 5's fence closes, and the README's line that every other tool still asks is wrong. Mark closed the window early, after 7 minutes. Mark said afterwards that both answers were read aloud, and that nothing went wrong from his side on the second question. Still to do: Mark removes the connector.

## Phase 4: The login

Built and tested on loopback only. Nothing is opened to the network in this
phase.

- [ ] Move the bridge's web layer to Express, in `src/bridge.ts`, because the SDK's OAuth server is an Express router. Declare `express` and `express-rate-limit` in `package.json`, pinned to the exact versions the SDK already installs (Express 5.3.0). Nothing else changes in this step, and the bridge's tests must still pass.

- [ ] Add the login, in `src/auth.ts`, on the SDK's `mcpAuthRouter`. The bridge supplies the provider: the one client that claude.ai uses, the password page, and the token store. It allows the authorisation code grant with PKCE and nothing else. The storage has no `registerClient` method, so the SDK offers no registration address and nobody can add a client of their own. The one client's redirect address is `https://claude.ai/api/mcp/auth_callback`, matched exactly. The SDK serves the documents Claude reads to find the sign-in and token addresses, and its `requireBearerAuth` on `/mcp` answers a call that has no token with a 401 and a `WWW-Authenticate` header. Anthropic's docs give the token address 10 seconds to answer.

- [ ] Write the password page, in `src/sign-in.ts`. One password, no user name and no sign-up. The form posts to a path under `/authorize`, so one Cloudflare Access rule covers the page and the form. An address is locked out for an hour after five wrong tries, counted by the caller's address from `CF-Connecting-IP`, on the same loopback-only rule as the caller check. The form carries a one-time token tied to the sign-in it belongs to.

- [ ] Keep only hashes, in `src/store.ts`, in a file outside the repository, `~/.local/state/voice-bridge/login.json`, mode `0600`. The password and the client secret are kept as scrypt hashes, and refresh tokens as SHA-256 hashes with their expiry. Access tokens last one hour and live in memory. Refresh tokens last seven days, are swapped for a new one at each use, and survive a restart, so switching voice off and on does not force a sign-in. Using an old refresh token a second time cancels every token. `scripts/voice-init.ts` asks for the password without showing it, makes the client ID and the client secret, prints them once, and writes the hashes.

- [ ] Take the no-login mode away. The endpoint moves to `/mcp`. The secret path, its setting and `scripts/test-window.sh` are deleted, and no switch is left that turns the login off. Narrow the caller check to the paths Anthropic's servers call: `/mcp`, `/token` and the `/.well-known/` documents. The sign-in path, `/authorize`, has to open in Mark's own browser, so it answers any address, and is guarded by the password and the lockout here, and by Cloudflare Access from Phase 5.

- [ ] Write `test/auth.test.ts` and `test/sign-in.test.ts`: a tool call with no token gets a 401 with the header, a wrong password is refused, a sixth wrong password is locked out, an expired token is refused, the wrong client secret is refused, a sign-in with no PKCE challenge is refused, an unregistered redirect address is refused, the registration path is a 404, a full sign-in with PKCE reaches the tools, a refresh works once and a reused refresh token cancels every token, tokens survive a restart of the bridge, a call to `/token` from outside Anthropic's ranges is refused, and the sign-in page is served to any address.

- [ ] Have Mark run `scripts/voice-init.ts`, as set out under "Before running /f", then run one whole sign-in on loopback with the SDK's own client, to check the flow by hand.

## Phase 5: The real bridge

The named tunnel on `<the voice subdomain>` carries over from Phase 3.

- [ ] Put the sign-in behind Cloudflare Access and re-cut the edge filter. Mark does both in the Cloudflare dashboard, as set out under "Before running /f". Then check from the box: Cloudflare refuses `/mcp` and `/token` for a caller outside Anthropic's ranges, and `/authorize` shows the Access page, not the password page. The bridge keeps its own caller check as well.

- [ ] Make it off by default, in `scripts/voice-on.sh` and `scripts/voice-off.sh`. On starts the bridge and the tunnel. Off stops both, so nothing answers at the address. The bridge exits after two hours with no tool call, and `voice-on.sh` stops the tunnel when it does.

- [ ] Start the dedicated voice session by hand, in a folder of its own outside every repository, `~/voice-session`, with the channel loaded. It runs in auto mode, Mark's choice, with `mcp__voice__reply` allowed ahead of time in the folder's own settings. No other session loads the channel, so the bridge has no way to reach one.

- [ ] Fence the voice session in, in `~/voice-session/.claude/settings.json`. Claude Code's sandbox and permission rules must refuse reads, writes and commands outside the folder, and the tools that message other sessions are denied. Read the sandboxing and permissions docs first, and record the exact settings in this step, since the plan has not checked their names. Then test the fence through `scripts/push.ts`: ask the session to read a file in another folder, to write one there, and to message another session, and check that all three are refused.

- [ ] Tag every message as coming from voice, in the channel's `meta`. A spoken `implement` counts like a typed one, by Mark's choice, so the tag is for the session and the log, not a lock.

- [ ] Log every message in and every reply out to a file on the box, outside the repository: `~/.local/state/voice-bridge/messages.log`, mode `0600`. Cap the length of a message, and let in no more than ten messages a minute.

- [ ] Write `test/limits.test.ts` additions and `test/switch.test.ts`: the rate limit holds at ten a minute, each message and reply is logged, the idle switch-off fires at two hours, and switching off leaves nothing listening.

- [ ] Have Mark add the real connector in claude.ai, with "Use your own OAuth client", the client ID and the client secret, and try a conversation.

- [ ] Document it in `voice/README.md`: what it is, how to switch it on and off, how to stop it at once, where the log is, and what stays risky. Say that a session can lose its channel without a word when it is moved, for example by `/fork`, and that `ask` then reports plainly that the channel is not there.

## Decisions

- **A test before the real bridge** - whether voice mode calls a custom connector, how long it waits, and whether a channel works alongside Remote Control are all undocumented. Finding out first costs one 10 minute window.

- **No login for the 10 minute test only** - Mark judged a short window acceptable to prove the pipeline. The free guards cut most of the risk: a secret path, the address check, an empty folder with every command asking first, and a hard shut-off.

- **The plan and the code are public** - `mark-house-style` is public on purpose. The plan and code hold no address, device name, domain or secret, so they say how a bridge works, not where one is.

- **Channels are preferred to typing into tmux** - the session gets the words as a message and answers through a tool. Nothing presses keys, so nothing can answer a dialog by accident.

- **Voice may say `implement`** - Mark's choice. It means a voice chat tricked by hidden instructions in a web page or email could start a code change. The dedicated voice session, with no project in its folder, limits what that change could reach.

- **Auto mode, but fenced to its own folder** - Mark's choices in `/t-g`. Auto mode lets spoken work flow without a tap. The fence means a mis-heard or tricked message can only change files in `~/voice-session`. The cost is that the voice session knows nothing of Mark's projects, and cannot message the sessions that do.

- **The login stands on the SDK's OAuth server and two separate checks** - research on 21 November 2026 found real login flaws reported in a similar voice bridge: unlimited password guessing and open client registration. So the protocol comes from the SDK and not from hand-written code, registration does not exist, and Cloudflare Access stands in front of the password page.

- **The channel stays, though other bridges use session messaging** - the same research found five public voice bridges to Claude Code, none using a channel. Most use Claude Code's messaging between sessions, which needs no warning dialog at each start. But a message sent that way arrives as another session's, never as Mark's. The channel is built and proven on the box, so it stays.
