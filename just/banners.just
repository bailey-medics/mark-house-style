# Finished-response banners
#
# Recipes for the banners on the Mac, kept in a file of their own so any
# repository can load them with `import?` and run them as `just rfb`, while
# mark-house-style's own justfile loads them for `just -g`. Paths are taken
# from this file's own folder, so they work wherever it is loaded from. See
# scripts/notification/README.md.
banner_scripts := source_directory() / ".." / "scripts" / "notification"


alias nli := notify-listen-install
# Install the Mac's listener for banners from a Linux box (macOS only; run again after the scripts change)
[no-cd]
notify-listen-install:
    "{{banner_scripts}}"/notification-listen-install.sh


alias nri := notify-relay-install
# Build the banner relay and install it in the Mac's VS Code, for banners where SSH to the box is blocked (macOS only)
[no-cd]
notify-relay-install:
    "{{banner_scripts}}"/notification-relay-install.sh


alias nrt := notify-relay-test
# Run the banner relay's tests and type check, and the banner scripts' tests
[no-cd]
notify-relay-test:
    cd "{{banner_scripts}}/vscode-relay" && npm ci --no-audit --no-fund --loglevel=error && npm test && npm run typecheck
    bats "{{banner_scripts}}/tests"


alias nap := notifier-app
# Build a branded banner notifier on the Mac from scripts/notification/icons/<name>.png, such as quill (macOS only)
[no-cd]
notifier-app name="quill":
    "{{banner_scripts}}"/build-notifier-app.sh "{{name}}"


alias rfb := refresh-banners
# Rebuild every banner icon and refresh the Mac's banner scripts, after pulling a banner change (macOS only)
[no-cd]
refresh-banners:
    "{{banner_scripts}}"/refresh-banners.sh
