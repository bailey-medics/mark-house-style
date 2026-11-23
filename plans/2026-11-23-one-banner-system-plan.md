# One banner system plan

Two copies of the finished-response banners run side by side. Quill
Medical has its own scripts, hooks, recipes, docs and Mac listener, and
mark-house-style has the copy every other project uses, which has since
grown a relay for networks that block SSH, an icon per project, and a
Finnish voice for Finnish names. Each fix now has to be made twice or
lands in one copy only, and the two meet on the Mac in a race: when the
Mac can reach the box over Tailscale, Quill's listener shows a banner
first and gives every project the Quill icon, and the relay, sharing its
record of what was shown, then skips it.

The outcome is one banner system, in mark-house-style. Quill Medical's
sessions call mark-house-style's hook from each checkout's own,
git-ignored settings, Quill's repository loses its copy in one pull
request, and the Mac runs mark-house-style's listener and relay only.

## Phase 1: Pronunciation and icons in mark-house-style

- [x] Give Turva, Juttu and Quill Medical a banner icon each, in `scripts/notification/icons/`, built into `~/Applications/<name>-notifier.app` by `build-notifier-app.sh <name>` (`t nap <name>`). `notification-show.sh` picks the icon from the banner's folder: `quillmedical…`, `turva…` and `juttu-messaging…` get their own, and every other folder keeps the plain icon. A logo with a solid background is used whole; a see-through one is set on white. The Mac's Homebrew Python refuses `pip` installs and its Homebrew belongs to an admin account, so Pillow for the builder lives in a private environment: `python3 -m venv ~/.venvs/notifier`, `~/.venvs/notifier/bin/pip install Pillow`, then `PATH="$HOME/.venvs/notifier/bin:$PATH" t nap <name>`.

- [x] Replace Juttu's icon with Mark's design, a gold speech bubble with a "j" on navy, kept as `icons/juttu.svg` and rendered to `icons/juttu.png` at 1024 by 1024 with headless Chrome, since the builder reads PNG.

- [x] Say the Finnish names with a Finnish voice. The Mac's voice, Karen, is Australian English and reads "Juttu" as "Juh-too". `notification-show.sh` now has Satu, macOS's Finnish voice, say "Turva" and "Juttu", and Karen the number after them, and falls back to English spellings Karen says close to the Finnish ("Toor-vah", "Yoot-too") where Satu is not installed. `TURVA_NOTIFY_FINNISH_VOICE` picks another Finnish voice. Six `bats` tests, with a stand-in `say` that lists voices the way the real one does, and breaking the Finnish path turns three of them red.

## Phase 2: Match what Quill's copy does

- [x] Speak Quill Medical's worktrees in mark-house-style's `notification.sh`, which builds the spoken name on the box. Quill's own hook said "Quill Medicine 6", and every project's main checkout ended in "one". At Mark's request, a main checkout is now its project's name alone and Quill is "Quill": `quillmedical` is "Quill", `quillmedical-<number>` "Quill <number>", `quillmedical-owl` "Quill Owl", `turva` "Turva", `juttu` "Juttu", and numbered worktrees keep their number. The stop-gap that renamed "quillmedical" on the Mac, in `notification-show.sh`, is gone, so the spoken name is worked out in one place. Tests check each as an exact line; putting the "one" back turns two of them red.

- [x] Leave out Quill's banner and sound on the box itself (`notify-send`, then `paplay`, `aplay` or `ffplay`). The box's desktops are seen through a remote desktop at most, and the Mac already shows and speaks every banner, so a second banner on the box adds nothing. Recorded as a decision rather than ported.

- [x] Keep mark-house-style's group names, `turva-claude-<name>`, for Quill banners too. A group only decides which banner replaces which, and one prefix for every project is simpler than a Quill exception.

## Phase 3: Quill Medical's sessions call mark-house-style's hook

- [x] Keep a session from getting two banners while the old hooks are still committed. Adding the new hooks before every checkout has the removal would fire both. So mark-house-style's `notification.sh` stands aside, exiting quietly, in a checkout that has its own `scripts/notification.sh` and whose committed `.claude/settings.json` still calls it. Each worktree then switches over by itself when it takes in the removal. Two `bats` tests; with the check disabled the first turns red.

- [x] Add the three hooks to each Quill checkout's own `.claude/settings.local.json`, which git ignores, pointing at `$HOME/github/mark-house-style/scripts/notification/notification.sh`: `Stop`, `Notification` for `permission_prompt` with `needs-input`, and `PreToolUse` for `AskUserQuestion` with `needs-input`, as mark-house-style's notification README sets out. The committed settings cannot name a path in Mark's personal repository, because Quill's repository is public and the path would not exist for anybody else. Every checkout on the box: `quillmedical`, `quillmedical-2` to `-6` and `quillmedical-owl`. Done on 23 November 2026 by a short script that keeps what each file already holds, the main checkout's permissions, and adds no hook twice. Checked: in `quillmedical-6` the new hook stays silent while the old one is committed, and in `turva` it runs.

## Phase 4: Remove Quill Medical's copy

- [x] In one Quill pull request, on its own `feature/` branch: delete `scripts/notification.sh`, `notification-show.sh`, `notification-focus.sh`, `notification-listen.sh`, `notification-listen-install.sh`, `notification-queue.py`, `notification-summary.py`, `build-notifier-app.sh` and `scripts/tests/notification.bats`; remove the three hooks from `.claude/settings.json`; remove the `notifier-app` (`na`) and `notify-listen-install` (`nli`) recipes and the `just notifier-app` call in another recipe; and remove or redirect `docs/docs/conventions/finished-response-notifications.md`, the `play-finished-sound` skill and its Copilot prompt, and the mention in `.claude/rules/home-details.md`. Each is read first, in case it covers more than banners. Done on 23 November 2026 in `quillmedical-6`, from current `main`: twelve files removed, the `Stop` hook keeping its `owl-busy.sh` call, the `play-finished-sound` entry dropped from `.claude/sync-manifest.json` and both pages from `docs/mkdocs.yml`, and the rule's clause about `devbox` finding a window removed. Nothing in the repository refers to the old files, the Justfile parses, and `just ts scripts/tests` ran all 467 shell tests with no warnings. The pull request is opened with `/crpd`.

- [ ] Once every Quill checkout has taken in the removal, delete the stand-aside check from `notification.sh` and its two tests.

## Phase 5: The Mac runs mark-house-style's listener only

- [ ] Unload Quill's listener, `launchctl bootout gui/$(id -u)/com.quill-medical.notify-listen`, and delete its agent file and `~/Library/Application Support/quill-notify`. Then run `t nli`, which refuses while Quill's listener is loaded. The SSH route then uses the per-project icons and the Finnish voice too, and shares its record of what was shown with the relay, in `~/Library/Caches/turva-notifier`.

- [ ] Rebuild `quill-notifier.app` from mark-house-style's copy of the logo with `t nap quill`, so nothing on the Mac comes from Quill's builder, and run `t nri` so the relay has the current banner script.

- [ ] Check at home and on the hospital wifi: a banner from a Quill, a Turva and a Juttu session each shows once, with its own icon, and says its name.

## Decisions

- **mark-house-style keeps the banners, not Quill Medical** - every project uses them, the relay and icons are already there, and Quill's repository is public, so anything personal to Mark's machines belongs in mark-house-style.

- **The spoken name is worked out on the box, the voice chosen on the Mac** - the hook knows the worktree, so it says what to call it; the Mac knows which voices are installed, so it decides who says it.

- **A real Finnish voice, with English stand-ins** - Mark asked for a strong Finnish accent, which only a Finnish voice gives. The stand-ins keep a Mac without Satu speaking something close rather than "Juh-too".
