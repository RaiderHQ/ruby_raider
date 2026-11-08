#!/usr/bin/env bash
# Proves a built ffmpeg does what the generated VideoHelper asks of it:
#   .github/ffmpeg/check.sh <ffmpeg binary> [work_dir]
# 1. links only (unless SKIP_LINKAGE is set) to libraries every machine of that OS has;
# 2. runs VideoHelper#ffmpeg_arguments' exact encode on sample PNG frames;
# 3. if FFPROBE is set (or ffprobe is on PATH), checks the WebM: one VP8 stream, 1280 wide, even height.
# Writes <work_dir>/video.webm.
set -euo pipefail

binary="$1"
work="${2:-$(mktemp -d)}"
here="$(cd "$(dirname "$0")" && pwd)"
rm -rf "$work" && mkdir -p "$work"

echo "== linkage"
case "${SKIP_LINKAGE:+skip}$(uname -s)" in
  skip*) echo '(skipped)' ;;
  Darwin)
    otool -L "$binary" | tail -n +2 | tee "$work/libs.txt"
    if grep -v -E '^\s*/(usr/lib|System/Library)/' "$work/libs.txt"; then
      echo 'links to a non-system library' >&2
      exit 1
    fi
    codesign --verify --verbose "$binary"
    otool -l "$binary" | grep -A4 -E 'LC_BUILD_VERSION|LC_VERSION_MIN_MACOSX' | grep -E 'minos|version' | head -2
    ;;
  Linux)
    file "$binary"
    file "$binary" | grep -q 'statically linked' || { echo 'not statically linked' >&2; exit 1; }
    ;;
  MINGW* | MSYS* | CYGWIN*)
    objdump -p "$binary" | grep 'DLL Name' | tee "$work/libs.txt"
    # Only Windows system DLLs: no libgcc, libwinpthread, libvpx, zlib.
    if grep -v -i -E 'DLL Name: (KERNEL32|msvcrt|ADVAPI32|USER32|bcrypt|ole32|shell32|api-ms-win-[a-z0-9-]+)\.dll' "$work/libs.txt"; then
      echo 'links to a non-system DLL' >&2
      exit 1
    fi
    ;;
esac

echo "== version"
"$binary" -hide_banner -version | head -3
if "$binary" -hide_banner -version | grep -q -- '--enable-gpl\|--enable-nonfree'; then
  echo 'GPL or nonfree build' >&2
  exit 1
fi
"$binary" -hide_banner -encoders 2>/dev/null | grep -E 'libvpx' || { echo 'no libvpx encoder' >&2; exit 1; }

echo "== encode (VideoHelper#ffmpeg_arguments)"
ruby "$here/frames.rb" "$work"
# Relative names in list.txt resolve against the list's directory, as in the helper's tmpdir.
"$binary" -y -loglevel error -f concat -safe 0 -i "$work/list.txt" \
  -vf "scale='min(1280,iw)':-2" -c:v libvpx -deadline realtime \
  -b:v 1M -r 5 -pix_fmt yuv420p "$work/video.webm"
size="$(wc -c <"$work/video.webm" | tr -d ' ')"
echo "video.webm: $size bytes"
[[ "$size" -gt 1000 ]] || { echo 'video too small' >&2; exit 1; }

probe="${FFPROBE:-$(command -v ffprobe || true)}"
if [[ -n "$probe" ]]; then
  "$here/probe.sh" "$probe" "$work/video.webm"
else
  echo "(no ffprobe here: the validate job probes this video)"
fi
