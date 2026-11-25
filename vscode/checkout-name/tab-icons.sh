#!/usr/bin/env bash
# Makes the pictures the terminal tabs show, in icons/ beside this file, from
# the banner icons in scripts/notification/icons.
#
# Usage: tab-icons.sh [folder]
#
# Run through `just -g checkout-name-icons` after a banner icon is added or
# changed, then commit what it wrote and install the extension again. With a
# folder, the pictures go there instead, which is how the tests run it.
#
# Every picture comes out as the same 64 pixel rounded square, so the tabs of
# different projects share one outline. A banner icon with a solid
# background, such as Turva's or Juttu's, is used whole. One with a
# see-through background, such as Quill's feather, is set on white first: its
# artwork is dark, and a dark tab would hide it.
#
# The pictures are committed, not made as the extension is installed, so
# installing needs no Pillow. Making them does: this uses the python3 that
# has it, or sets it up once in ~/.venvs/notifier, the folder the banner
# builder uses, since a system Python may refuse pip installs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly BANNERS="${here}/../../scripts/notification/icons"
readonly PILLOW_VENV="${TURVA_NOTIFY_VENV:-${HOME}/.venvs/notifier}"

# Prints a python3 that has Pillow: the machine's own when it has it,
# otherwise the one in the venv, which is set up when it is missing.
pillow_python() {
    if python3 -c 'import PIL' >/dev/null 2>&1; then
        echo python3
        return 0
    fi

    if ! "${PILLOW_VENV}/bin/python" -c 'import PIL' >/dev/null 2>&1; then
        echo "Setting up Pillow in ${PILLOW_VENV}, once..." >&2
        python3 -m venv "${PILLOW_VENV}" >&2
        "${PILLOW_VENV}/bin/pip" install --quiet Pillow >&2
    fi

    echo "${PILLOW_VENV}/bin/python"
}

# Writes a tab picture into the folder for every banner icon.
make_icons() {
    local python="$1"
    local target="$2"

    "${python}" - "${BANNERS}" "${target}" <<'EOF_PY'
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 64
CORNER = 12
INSET = 53


def square(logo: Image.Image) -> Image.Image:
    """The logo as a square: whole when solid, on white when see-through."""
    if logo.getchannel("A").getextrema()[0] == 255:
        return logo.resize((SIZE, SIZE), Image.LANCZOS)

    ink = logo.crop(logo.getbbox())
    ink.thumbnail((INSET, INSET), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
    canvas.alpha_composite(ink, ((SIZE - ink.width) // 2, (SIZE - ink.height) // 2))

    return canvas


def rounded(picture: Image.Image) -> Image.Image:
    """The picture with its corners cut away, see-through outside them."""
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=CORNER, fill=255)
    picture.putalpha(mask)

    return picture


banners, target = Path(sys.argv[1]), Path(sys.argv[2])

for banner in sorted(banners.glob("*.png")):
    logo = Image.open(banner).convert("RGBA")
    rounded(square(logo)).save(target / banner.name, optimize=True)
    print(f"Made {banner.name}")
EOF_PY
}

main() {
    local target="${1:-${here}/icons}"
    local python

    if [ ! -d "${target}" ]; then
        echo "✗ ${target} is not a folder. Usage: tab-icons.sh [folder]" >&2
        exit 1
    fi

    python="$(pillow_python)"
    make_icons "${python}" "${target}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
