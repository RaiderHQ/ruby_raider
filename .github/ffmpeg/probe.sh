#!/usr/bin/env bash
# probe.sh <ffprobe> <video.webm> [codec, default vp8]: one video stream of that codec, 1280x616 (1366x657 scaled to an even height),
# about 8 s long, and the whole file decodes without errors.
set -euo pipefail

probe="$1"
video="$2"
codec="${3:-vp8}"
stream="$("$probe" -v error -select_streams v -show_entries stream=codec_name,width,height,pix_fmt -of csv=p=0 "$video")"
format="$("$probe" -v error -show_entries format=format_name -of default=nw=1:nk=1 "$video")"
duration="$("$probe" -v error -show_entries format=duration -of default=nw=1:nk=1 "$video")"
echo "$(basename "$video"): stream $stream; format $format; duration $duration"
[[ "$stream" == "$codec,1280,616,yuv420p" ]] || { echo "unexpected stream: $stream" >&2; exit 1; }
[[ "$format" == "matroska,webm" ]] || { echo "unexpected format: $format" >&2; exit 1; }
awk -v d="$duration" 'BEGIN { exit !(d > 7 && d < 9) }' || { echo "unexpected duration: $duration" >&2; exit 1; }
errors="$("${probe%probe}mpeg" -v error -i "$video" -f null - 2>&1 || true)"
[[ -z "$errors" ]] || { echo "decode errors: $errors" >&2; exit 1; }
