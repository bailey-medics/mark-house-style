# Voice bridge

A Claude Code channel, and a small bridge in front of it, that let a voice
chat on the phone talk to a Claude session on the dev box. This is Phases 2
to 4 of the
[voice bridge build plan](../plans/2026-11-21-voice-bridge-build-plan.md).

- **The channel** runs inside the session, and is reachable only from the
  box itself.
- **The bridge** is what claude.ai's connector talks to. It lets in only
  calls that carry the login's secret token, and it is off unless a short
  test window is open.

The only thing here that listens on a network port is the bridge, on
loopback, while a test window is open.

## How the channel works

- **The session starts the channel.** Claude Code runs `src/main.ts` as an
  MCP server over stdio, when the session is started with the channel
  loaded.
- **A private socket is the way in.** The channel listens on
  `$XDG_RUNTIME_DIR/voice-channel/channel.sock`. The folder is mode `0700`
  and the socket `0600`, so only Mark's user can open it.
- **Each message is one line of JSON**, `{"text": "..."}`, of at most 2,000
  characters. The channel pushes it into the session as a channel event,
  tagged `via="voice"` with a `message_id`.
- **The session answers with the `reply` tool**, and the answer goes back
  down the same connection as `{"reply": "..."}`. A bad message gets
  `{"error": "..."}` and never reaches the session.
- **It cannot approve anything.** The channel never declares
  `claude/channel/permission`, so no message can answer a Bash, Write or
  Edit prompt.

## How the bridge works

- **It is an MCP server over HTTP, bound to loopback.** A Cloudflare
  tunnel is the only way in from outside, and the tunnel runs only while a
  test window is open.
- **It has three tools.** `ping` checks the box is reachable. `ask` sends
  words to the session and returns its answer. `check_reply` fetches an
  answer that took too long for `ask`.
- **It answers only at `/mcp`.** Every other path gets a 404.
- **It refuses any caller outside Anthropic's published address ranges.**
  A Cloudflare rule on the host name does the same, before a request
  reaches the box.
- **It refuses any call without the login's token.** Anyone can make
  Anthropic's servers call an address, so the ranges alone prove nothing.
  The token is what says the call is Mark's.
- **The login cannot be switched off.** The bridge will not start without
  one, and there is no setting that skips the check.

## The login

One secret token, which claude.ai stores and sends in the `Authorization`
header of every request. There is no sign-in page and no password.

- **Make it** in a terminal of your own, not through a Claude session, so
  that nothing else sees the token:

  ```bash
  node ~/github/mark-house-style/voice/scripts/voice-init.ts
  ```

  It prints a header name and a header value, once. It will not run when
  its output is not a terminal.

- **The box keeps only a hash of it**, in
  `~/.local/state/voice-bridge/login.json`, mode `0600`, outside every
  repository. The token itself is written nowhere on the box.
- **It lasts 7 days.** `--days` sets another length, up to 90. After that
  the bridge refuses it.
- **Replace it** by running the script again with `--replace`. The old
  token stops at once. claude.ai does not let a connector's sign-in be
  edited, so remove the connector and add it again with the new value.
- **Cut it off at once** by deleting the file. The bridge reads it afresh
  for every request, so the next call is refused.
- **Ten wrong tokens inside an hour raise an alarm in the log.** Nothing
  is locked. A lock would let a stranger shut Mark out, since anyone can
  make Anthropic's servers send a wrong token, and it would add no safety,
  because the token cannot be guessed.

## Tests

```bash
just -g voice-test
just -g voice-typecheck
```

Needs Node 26 or later, which runs the `.ts` files directly. Run
`npm install` in this folder once first.

## Trying it in a throwaway session

1. Make an empty folder outside every repository, and put this in
   `.mcp.json` inside it:

   ```json
   {
     "mcpServers": {
       "voice": {
         "command": "node",
         "args": ["${HOME}/github/mark-house-style/voice/src/main.ts"]
       }
     }
   }
   ```

   And this in `.claude/settings.json`, so the session can answer through
   `reply` without stopping to ask:

   ```json
   {
     "permissions": {
       "allow": ["mcp__voice__reply"]
     }
   }
   ```

   **Nothing here fences the session in.** Even in manual mode, Claude
   Code runs shell commands it judges read-only without asking, anywhere
   Mark's user can read, and lets the session write in its own scratch
   folder. So treat a message as able to read out anything on the box that
   Mark's user can read. The fence comes in Phase 5.

2. Start Claude there with the channel loaded and Remote Control on:

   ```bash
   claude --dangerously-load-development-channels server:voice --remote-control voice-test
   ```

   The first start asks three things: trust the folder ("Yes, I trust this
   folder"), use the MCP server ("Use this MCP server"), and load the
   development channel ("I am using this for local development"). Later
   starts ask only the last. If the session comes up in auto mode, press
   Shift+Tab until it says manual mode.

3. From another terminal, send it a message:

   ```bash
   node ~/github/mark-house-style/voice/scripts/push.ts "What is in this folder?"
   ```

   The answer prints when the session calls `reply`.

4. Quit Claude, then start it again with `--continue` added, to check the
   channel still loads with the flags the boot script uses.

## Opening a test window

For short live tests, until Phase 5 adds an on and off switch. It needs a
login, made as above, and the named tunnel set up as the plan describes,
with its host name in `~/.config/voice-bridge/host`, outside every
repository.

1. Start the throwaway session, as above.

2. Run the window:

   ```bash
   ~/github/mark-house-style/voice/scripts/test-window.sh
   ```

   It starts the bridge and the tunnel, prints the connector address, and
   stops both after 10 minutes or on Ctrl+C. `VOICE_WINDOW_SECONDS` sets
   another length. If the bridge will not start, for want of a login, the
   tunnel never opens.

3. Add the printed address in claude.ai as a custom connector. Choose
   "No sign-in", and under "Request headers" add the header that
   `voice-init` printed.

`VOICE_WINDOW_NO_SESSION=1` opens the window with no session running, for
checking what reaches the bridge's log.

## Stopping it

Type `/exit` in the Claude session. The channel stops with it and the
socket goes. A test window stops its own bridge and tunnel when it closes.
