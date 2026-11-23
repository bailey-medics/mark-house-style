#!/usr/bin/env bats
# Tests for xrdp-tune.sh, run against a copy of xrdp 0.10's packaged
# gfx.toml sections, so nothing here touches /etc/xrdp.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../xrdp-tune.sh"
    FILE="${BATS_TEST_TMPDIR}/gfx.toml"

    cat > "$FILE" <<'TOML'
[codec]
order = [ "H.264", "RFX" ]
h264_encoder = "x264"

[x264.default]
preset = "ultrafast"
tune = "zerolatency"
profile = "main"     # profile is forced to baseline if preset == ultrafast
vbv_max_bitrate = 0
vbv_buffer_size = 0
fps_num = 60
fps_den = 1
threads = 1          # recommended: 1 or 2, see `man gfx.toml` for details

[x264.lan]
# inherits default

[x264.wan]
vbv_max_bitrate = 15_000
vbv_buffer_size = 1_500

[x264.broadband_high]
preset = "superfast"
vbv_max_bitrate = 8_000
vbv_buffer_Size = 800
TOML
}

# The value of a key inside one [section] of the file.
value_in() {
    sed -n "/^\[$1\]/,/^\[/p" "$FILE" | sed -n "s/^$2 = \([^ ]*\).*/\1/p"
}

@test "it sets the cap, a one-second buffer and the frame rate" {
    run bash "$SCRIPT" 10000 30 "$FILE"

    [ "$status" -eq 0 ]
    [ "$(value_in 'x264\.default' vbv_max_bitrate)" = 10000 ]
    [ "$(value_in 'x264\.default' vbv_buffer_size)" = 10000 ]
    [ "$(value_in 'x264\.default' fps_num)" = 30 ]
    [ "$(value_in 'x264\.default' preset)" = '"superfast"' ]
    [ "$(value_in 'x264\.default' threads)" = 2 ]
    [ "$(value_in 'x264\.wan' vbv_max_bitrate)" = 10000 ]
}

@test "it keeps the packaged file and leaves other sections alone" {
    run bash "$SCRIPT" 10000 30 "$FILE"

    [ -e "${FILE}.orig" ]
    [ "$(value_in 'x264\.default' vbv_max_bitrate)" = 10000 ]
    [ "$(value_in 'x264\.broadband_high' vbv_max_bitrate)" = 8_000 ]
    grep -q '^vbv_max_bitrate = 0$' "${FILE}.orig"
}

@test "a second run starts again from the packaged file" {
    bash "$SCRIPT" 5000 30 "$FILE"
    run bash "$SCRIPT" 0 60 "$FILE"

    [ "$status" -eq 0 ]
    [ "$(value_in 'x264\.default' vbv_max_bitrate)" = 0 ]
    [ "$(value_in 'x264\.default' fps_num)" = 60 ]
}

@test "a value that is not a number is refused and the file is untouched" {
    cp "$FILE" "${BATS_TEST_TMPDIR}/before"

    run bash "$SCRIPT" '10000;x' 30 "$FILE"

    [ "$status" -eq 1 ]
    [[ "$output" == *"usage"* ]]
    cmp -s "$FILE" "${BATS_TEST_TMPDIR}/before"
}
