#!/usr/bin/env bash
# Rebuilds every banner icon app and refreshes the Mac's copies of the banner
# scripts, then restarts macOS's notification services.
#
# Usage: refresh-banners.sh
#
# Run it on the Mac after pulling any change to the banners: a new or changed
# icon, or a change to the scripts. Safe to run twice. Each picture in icons/
# is built into its app by build-notifier-app.sh, which sets up Pillow itself
# if needed. The scripts are copied into the relay's folder and the
# listener's, where those are installed, so neither needs installing again
# for a script change. macOS may ask to allow an app whose picture changed.
set -euo pipefail

SCRIPTS="notification-queue.py notification-show.sh notification-focus.sh level-completed.mp3"

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

main() {
    local here
    local builder
    local support
    local icon

    if [ "$(uname -s)" != "Darwin" ]; then
        echo "Banners are shown on the Mac; nothing to refresh here."
        exit 0
    fi

    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
