#!/usr/bin/env bash
# Rebuilds every banner icon app and refreshes the Mac's copies of the banner
# scripts, then restarts macOS's notification services.
#
# Usage: refresh-banners.sh
#
# Run it on the Mac after any change to the banners: a new or changed icon,
# or a change to the scripts. It pulls mark-house-style first, forward only:
# with changes made on the Mac, or commits GitHub hasn't got, it stops and
# builds nothing, and with GitHub out of reach it builds from the copy it
# has. TURVA_NOTIFY_HOUSE names another checkout to pull. Safe to run twice. Each picture in icons/
# is built into its app by build-notifier-app.sh, which sets up Pillow itself
# if needed. The scripts are copied into the relay's folder and the
# listener's, where those are installed, so neither needs installing again
# for a script change. macOS may ask to allow an app whose picture changed.
#
# Off a Mac it fails, saying so, since a terminal in a VS Code window
# connected to the box runs on the box and is easy to take for the Mac's.
set -euo pipefail

SCRIPTS="notification-queue.py notification-show.sh notification-focus.sh notification-dismiss.sh level-completed.mp3"

# Copy the banner scripts into an installed copy, if that copy is there.
refresh_copy() {
    local source_dir="$1"
    local dest="$2"
    local file

    if [ ! -d "${dest}" ]; then
        return
    fi

    for file in ${SCRIPTS}; do
        cp "${source_dir}/${file}" "${dest}/${file}"
    done

    if [ -f "${dest}/notification-listen.sh" ]; then
        cp "${source_dir}/notification-listen.sh" "${dest}/notification-listen.sh"
    fi

    chmod +x "${dest}"/*.sh
    echo "Refreshed the banner scripts in ${dest}"
}

# Brings the checkout level with GitHub, forward only. Fails, saying why, when
# that would lose or mix up work; carries on, saying so, when GitHub can't be
# reached.
pull_house() {
    local house="$1"

    if [ -n "$(git -C "${house}" status --porcelain --untracked-files=no)" ]; then
        echo "✗ mark-house-style has changes here that aren't committed, so nothing was pulled or rebuilt." >&2
        return 1
    fi

    if ! git -C "${house}" fetch --quiet 2>/dev/null; then
        echo "Couldn't reach GitHub, so rebuilding from the copy here."
        return 0
    fi

    if ! git -C "${house}" merge --ff-only --quiet "@{upstream}" 2>/dev/null; then
        echo "✗ mark-house-style here has gone a different way from GitHub, so nothing was pulled or rebuilt." >&2
        return 1
    fi

    echo "mark-house-style is at: $(git -C "${house}" log --oneline -1)"
}

main() {
    local here
    local builder
    local support
    local icon
    local house
    local before

    if [ "$(uname -s)" != "Darwin" ]; then
        echo "✗ This machine is not the Mac, so nothing was pulled, rebuilt or refreshed." >&2
        echo "  Run \`just -g rfb\` in a terminal on the Mac itself: a terminal in a VS Code window connected to the box runs on the box." >&2
        exit 1
    fi

    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Pull first. When that changes anything, start again from the new copy
    # of this script, as bash reads a script as it goes.
    if [ "${TURVA_NOTIFY_PULLED:-0}" != "1" ]; then
        house="${TURVA_NOTIFY_HOUSE:-$(cd "${here}/../.." && pwd)}"
        before="$(git -C "${house}" rev-parse HEAD 2>/dev/null || true)"
        pull_house "${house}" || exit 1
        if [ "$(git -C "${house}" rev-parse HEAD 2>/dev/null || true)" != "${before}" ]; then
            TURVA_NOTIFY_PULLED=1 exec "${BASH_SOURCE[0]}" "$@"
        fi
    fi

    builder="${TURVA_NOTIFY_BUILDER:-${here}/build-notifier-app.sh}"
    support="${HOME}/Library/Application Support"

    for icon in "${here}"/icons/*.png; do
        "${builder}" "$(basename "${icon}" .png)"
    done

    refresh_copy "${here}" "${support}/banner-relay"
    refresh_copy "${here}" "${support}/turva-notify"

    # The services that draw banners restart by themselves, and come back
    # without the icons they had cached.
    killall NotificationCenter usernoted >/dev/null 2>&1 || true
    echo "Restarted the notification services. Banners now use the rebuilt icons."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
