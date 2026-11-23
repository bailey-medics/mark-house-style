# Voice channel

A Claude Code channel that lets a voice chat on the phone talk to a Claude
session on the dev box. This is Phase 2 of the
[voice bridge build plan](../plans/2026-11-21-voice-bridge-build-plan.md):
the channel alone, reachable only from the box itself. Nothing here listens
on a network port.

## How it works

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
   `reply` without stopping to ask. Every other tool still asks:

   ```json
   {
     "permissions": {
       "allow": ["mcp__voice__reply"]
     }
   }
   ```

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

## Stopping it

Type `/exit` in the Claude session. The channel stops with it and the
socket goes.
