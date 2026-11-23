#!/usr/bin/env bash
# Tune xrdp's H.264 settings (xrdp 0.10 and later). It always starts from the
# packaged file, kept as gfx.toml.orig, so each run replaces the last one.
# The buffer is one second of video, so a short burst such as a scroll stays
# sharp and only a long one is held to the cap. 10000 30 suits a home line
# with about 11 Mbit/s of upload.
#   sudo bash scripts/remote-desktop/xrdp-tune.sh <kbit/s per screen, 0 = no cap> <frames a second>
# Takes effect on the next connection. Undo with:
#   sudo cp /etc/xrdp/gfx.toml.orig /etc/xrdp/gfx.toml
set -euo pipefail

bitrate="${1:-10000}"
fps="${2:-30}"
file="${3:-/etc/xrdp/gfx.toml}"

case "$bitrate$fps" in
    *[!0-9]*) echo "usage: xrdp-tune.sh <kbit/s> <fps>" >&2; exit 1 ;;
esac

[ -e "$file.orig" ] || cp -a "$file" "$file.orig"
cp -a "$file.orig" "$file"

# The buffer is one second of video, so a short burst stays sharp and only
# a long one is held to the cap.
sed -i \
    -e '/^\[x264\.default\]/,/^\[x264\.lan\]/ {
        s/^preset = "ultrafast"/preset = "superfast"/
        s/^vbv_max_bitrate = 0$/vbv_max_bitrate = '"$bitrate"'/
        s/^vbv_buffer_size = 0$/vbv_buffer_size = '"$bitrate"'/
        s/^fps_num = 60$/fps_num = '"$fps"'/
        s/^threads = 1 /threads = 2 /
    }' \
    -e '/^\[x264\.wan\]/,/^\[x264\.broadband_high\]/ {
        s/^vbv_max_bitrate = 15_000$/vbv_max_bitrate = '"$bitrate"'/
        s/^vbv_buffer_size = 1_500$/vbv_buffer_size = '"$bitrate"'/
    }' \
    "$file"

sed -n '/^\[x264\.default\]/,/^\[x264\.broadband_high\]/p' "$file" | grep -vE '^\s*(#|$)'
