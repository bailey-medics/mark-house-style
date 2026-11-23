#!/usr/bin/env bash
# Builds a branded copy of terminal-notifier, so banners carry an icon.
#
# Usage: build-notifier-app.sh <name>
#
# Makes ~/Applications/<name>-notifier.app from icons/<name>.png beside this
# script. notification-show.sh posts a banner through it, for the folders it
# belongs to. macOS takes a banner's icon from the app that posts it, and
# offers no way to set one per banner, so each icon needs its own copy of
# the app, with its own bundle identifier. That identifier also gives it its
# own entry in System Settings, Notifications, which must be allowed once.
#
# macOS only. Safe to run twice: it rebuilds the app from scratch. The app
# is a signed binary, so it is built here, never committed. It needs Pillow
# to prepare the icon, and sets it up once in ~/.venvs/notifier when the
# Mac's python3 lacks it, since Homebrew's Python refuses pip installs.
set -euo pipefail

TERMINAL_NOTIFIER_VERSION="3.1.0"
NAME_PATTERN='^[a-z][a-z0-9-]{0,30}$'
PILLOW_VENV="${TURVA_NOTIFY_VENV:-${HOME}/.venvs/notifier}"

# The download folder, global so the clean-up on exit can still see it after
# main() returns.
WORK=""

cleanup() {
    if [ -n "${WORK}" ]; then
        rm -rf "${WORK}"
    fi
}

# A python3 that has Pillow: the Mac's own when it has it, otherwise a
# private environment, made the first time it is needed.
pillow_python() {
    local venv="${PILLOW_VENV}"

    if python3 -c 'import PIL' >/dev/null 2>&1; then
        echo python3
        return
    fi

    if ! "${venv}/bin/python" -c 'import PIL' >/dev/null 2>&1; then
        echo "Setting up Pillow in ${venv}, once..." >&2
        python3 -m venv "${venv}" >&2
        "${venv}/bin/pip" install --quiet Pillow >&2
    fi

    echo "${venv}/bin/python"
}

# The app's identifier carries a checksum of its picture. macOS keeps a
# notification app's icon under its identifier and will not let it go, so
# a new picture needs a new identifier, which macOS may ask to allow once.
# The same picture keeps the same identifier.
icon_identifier() {
    local name="$1"
    local logo="$2"
    local sum

    sum="$(cksum <"${logo}" | cut -d ' ' -f 1)"

    echo "fr.julienxx.oss.terminal-notifier.${name}.${sum}"
}

# A logo with a solid background, such as Turva's or Juttu's, is already a
# finished square icon, so it is used whole. One with a see-through
# background, such as Quill's, is set on white and inset, because macOS
# rounds a notification icon's corners and would clip artwork that runs to
# the edge.
prepare_icon() {
    local logo="$1"
    local out="$2"
    local python="$3"

    "${python}" - "$logo" "$out" <<'EOF_PY'
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA")
size = 1024

if im.getchannel("A").getextrema()[0] == 255:
    im.convert("RGB").resize((size, size), Image.LANCZOS).save(out)
    sys.exit(0)

ink = im.crop(im.getbbox())
margin = 0.16
target = int(size * (1 - 2 * margin))
scale = min(target / ink.width, target / ink.height)
ink = ink.resize(
    (max(1, int(ink.width * scale)), max(1, int(ink.height * scale))),
    Image.LANCZOS,
)

canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
canvas.alpha_composite(ink, ((size - ink.width) // 2, (size - ink.height) // 2))
canvas.convert("RGB").save(out)
EOF_PY
}

make_icns() {
    local png="$1"
    local icns="$2"
    local iconset="$3"
    local size

    mkdir -p "${iconset}"

    for size in 16 32 128 256 512; do
        sips -z "${size}" "${size}" "${png}" --out "${iconset}/icon_${size}x${size}.png" >/dev/null
        sips -z "$((size * 2))" "$((size * 2))" "${png}" --out "${iconset}/icon_${size}x${size}@2x.png" >/dev/null
    done

    iconutil -c icns "${iconset}" -o "${icns}"
}

# A copy of terminal-notifier carrying the icon, under its own identifier.
assemble_app() {
    local source_app="$1"
    local icns="$2"
    local name="$3"
    local display="$4"
    local dest="$5"
    local identifier="$6"
    local plist="${dest}/Contents/Info.plist"
    local buddy=/usr/libexec/PlistBuddy

    rm -rf "${dest}"
    mkdir -p "$(dirname "${dest}")"
    cp -R "${source_app}" "${dest}"
    cp "${icns}" "${dest}/Contents/Resources/${display}.icns"
    rm -f "${dest}/Contents/Resources/Terminal.icns"

    "${buddy}" -c "Set :CFBundleIdentifier ${identifier}" "${plist}"
    "${buddy}" -c "Set :CFBundleIconFile ${display}" "${plist}" 2>/dev/null \
        || "${buddy}" -c "Add :CFBundleIconFile string ${display}" "${plist}"
    "${buddy}" -c "Set :CFBundleName ${display}" "${plist}" 2>/dev/null || true
    "${buddy}" -c "Set :CFBundleDisplayName ${display}" "${plist}" 2>/dev/null \
        || "${buddy}" -c "Add :CFBundleDisplayName string ${display}" "${plist}"

    # Editing the bundle breaks the upstream signature, so sign it again for
    # this Mac, and drop the quarantine flag the download carries.
    xattr -dr com.apple.quarantine "${dest}" 2>/dev/null || true
    codesign --force --deep -s - "${dest}" >/dev/null 2>&1
}

main() {
    local name="${1:-}"
    local here
    local logo
    local dest
    local display
    local python
    local identifier
    local url

    if [ -z "${name}" ] || ! [[ "${name}" =~ ${NAME_PATTERN} ]]; then
        echo "Give an icon name, such as quill. Usage: build-notifier-app.sh <name>" >&2
        exit 1
    fi

    if [ "$(uname -s)" != "Darwin" ]; then
        echo "The notifier app is for macOS; nothing to build here."
        exit 0
    fi

    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    logo="${here}/icons/${name}.png"
    dest="${TURVA_NOTIFY_APP_DIR:-${HOME}/Applications}/${name}-notifier.app"
    display="$(printf '%s' "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1}"
    url="https://github.com/julienXX/terminal-notifier/releases/download/${TERMINAL_NOTIFIER_VERSION}/terminal-notifier-${TERMINAL_NOTIFIER_VERSION}.zip"

    if [ ! -f "${logo}" ]; then
        echo "No icon at ${logo}; add a square PNG there first." >&2
        exit 1
    fi

    python="$(pillow_python)"
    identifier="$(icon_identifier "${name}" "${logo}")"

    WORK="$(mktemp -d)"
    trap cleanup EXIT

    # The upstream release is a signed, prebuilt binary, which needs no Xcode.
    echo "Fetching terminal-notifier ${TERMINAL_NOTIFIER_VERSION}..."
    curl -fsSL -o "${WORK}/tn.zip" "${url}"
    unzip -q "${WORK}/tn.zip" -d "${WORK}"

    if [ ! -d "${WORK}/terminal-notifier.app" ]; then
        echo "The terminal-notifier download was not laid out as expected." >&2
        exit 1
    fi

    echo "Preparing the icon..."
    prepare_icon "${logo}" "${WORK}/icon.png" "${python}"
    make_icns "${WORK}/icon.png" "${WORK}/${display}.icns" "${WORK}/${display}.iconset"

    echo "Assembling ${dest}..."
    assemble_app "${WORK}/terminal-notifier.app" "${WORK}/${display}.icns" "${name}" "${display}" "${dest}" "${identifier}"

    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${dest}" || true

    echo "Built ${dest}"
    echo "Built as ${identifier}. If macOS asks, allow ${display} to send notifications."
    "${dest}/Contents/MacOS/terminal-notifier" -title "${display}" \
        -message "Notifier installed. Banners will look like this." >/dev/null 2>&1 || true
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
