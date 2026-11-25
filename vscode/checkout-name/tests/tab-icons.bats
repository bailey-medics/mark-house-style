#!/usr/bin/env bats
# Tests for tab-icons.sh, which makes the terminal tabs' pictures from the
# banner icons.
#
# The pictures go to the test's own folder, so the committed ones are not
# touched. Making them needs Pillow, so the tests are skipped on a machine
# with none set up: they never install it themselves.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../tab-icons.sh"
    BANNERS="${BATS_TEST_DIRNAME}/../../../scripts/notification/icons"
    MADE="${BATS_TEST_TMPDIR}/made"
    PYTHON=""

    if python3 -c 'import PIL' >/dev/null 2>&1; then
        PYTHON="python3"
    elif "${HOME}/.venvs/notifier/bin/python" -c 'import PIL' >/dev/null 2>&1; then
        PYTHON="${HOME}/.venvs/notifier/bin/python"
    else
        skip "Pillow is not set up: run just -g checkout-name-icons once"
    fi

    mkdir -p "${MADE}"
}

# Prints "<width>x<height>", then the opacity, 0 to 255, of a corner pixel
# and of the middle one.
measure() {
    "${PYTHON}" - "$1" <<'EOF_PY'
import sys
from PIL import Image

picture = Image.open(sys.argv[1]).convert("RGBA")
alpha = picture.getchannel("A")
print(f"{picture.width}x{picture.height}")
print(alpha.getpixel((0, 0)))
print(alpha.getpixel((picture.width // 2, picture.height // 2)))
EOF_PY
}

@test "every banner icon gets a tab picture of the same name" {
    run "$SCRIPT" "${MADE}"

    [ "$status" -eq 0 ]
    for banner in "${BANNERS}"/*.png; do
        [ -f "${MADE}/$(basename "${banner}")" ]
    done
}

@test "a solid icon and a see-through one come out the same rounded square" {
    run "$SCRIPT" "${MADE}"
    [ "$status" -eq 0 ]

    for icon in turva quill; do
        run measure "${MADE}/${icon}.png"
        [ "${lines[0]}" = "64x64" ]
        [ "${lines[1]}" = "0" ]
        [ "${lines[2]}" = "255" ]
    done
}

@test "a folder that does not exist is refused" {
    run "$SCRIPT" "${BATS_TEST_TMPDIR}/nowhere"

    [ "$status" -eq 1 ]
    [[ "$output" == *"is not a folder"* ]]
}
