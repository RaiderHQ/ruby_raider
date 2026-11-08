#!/usr/bin/env bash
# probe.sh <ffprobe> <video.webm>: one VP8 stream, 1280x618 (1366x657 scaled, even height),
# about 8 s long, and the whole file decodes without errors.
set -euo pipefail

probe="$1"
video="$2"
stream="$("$probe" -v error -select_streams v -show_entries stream=codec_name,width,height,pix_fmt -of csv=p=0 "$video")"
format="$("$probe" -v error -show_entries format=format_name,duration -of csv=p=0 "$video")"
echo "$video: stream $stream; format $format"
[[ "$stream" == "vp8,1280,618,yuv420p" ]] || { echo "unexpected stream: $stream" >&2; exit 1; }
[[ "$format" == matroska,webm,* ]] || { echo "unexpected format: $format" >&2; exit 1; }
duration="${format##*,}"
awk -v d="$duration" 'BEGIN { exit !(d > 7 && d < 9) }' || { echo "unexpected duration: $duration" >&2; exit 1; }
errors="$("${probe%probe}mpeg" -v error -i "$video" -f null - 2>&1 || true)"
[[ -z "$errors" ]] || { echo "decode errors: $errors" >&2; exit 1; }
