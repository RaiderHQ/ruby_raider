#!/usr/bin/env bash
# Builds the ffmpeg binary that RubyRaider::Ffmpeg downloads for failure videos.
#
#   .github/ffmpeg/build.sh <darwin-arm64|darwin-x64|linux-x64|windows-x64> [out_dir]
#
# LGPL build (no --enable-gpl, no --enable-nonfree) with only what the generated
# VideoHelper needs: PNG frames listed in a concat file, scaled, encoded with libvpx
# (VP8, VP9 kept for later) into WebM. Every source is pinned by SHA-256 or commit.
# Also writes the license notices for what is linked in and, in <out_dir>/sources/, the complete
# corresponding source (FFmpeg and zlib tarballs, a git archive of the libvpx commit) for the release.
# Runs on: macOS (arm64 or x86_64 runner), Alpine Linux (fully static, musl) and
# MSYS2 MINGW64 on Windows (static libgcc/winpthread). Needs bash, make, a C compiler,
# curl, tar, xz, git, pkg-config, perl and nasm (x86_64 targets only).
set -euo pipefail

FFMPEG_VERSION=7.1.5
FFMPEG_SHA256=de668509caf9e35e3cd162473441fdb29538c6d96ed080292b3cf9e6fc5d558f
ZLIB_VERSION=1.3.1
ZLIB_SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
LIBVPX_TAG=v1.15.2
LIBVPX_COMMIT=d168454ecd099805c675d4a98c66f4891373302a
# Only for its license notice: the Linux binary links musl statically (Alpine 3.20 ships musl 1.2.5).
MUSL_VERSION=1.2.5
MUSL_SHA256=a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4
MACOS_MIN=11.0

FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
ZLIB_URL="https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz"
LIBVPX_REPO=https://chromium.googlesource.com/webm/libvpx
MUSL_URL="https://musl.libc.org/releases/musl-${MUSL_VERSION}.tar.gz"

target="${1:?usage: build.sh <darwin-arm64|darwin-x64|linux-x64|windows-x64> [out_dir]}"
here="$(cd "$(dirname "$0")" && pwd)"
out_dir="$(mkdir -p "${2:-dist}" && cd "${2:-dist}" && pwd)"
work="${FFMPEG_BUILD_DIR:-$(pwd)/build-ffmpeg-$target}"
prefix="$work/prefix"
jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"

cflags=""
ldflags=""
exe=""
ffmpeg_flags=(--enable-pthreads)
zlib_make=()
case "$target" in
  darwin-arm64)
    vpx_target=arm64-darwin20-gcc
    arch=arm64
    ;;
  darwin-x64)
    vpx_target=x86_64-darwin20-gcc
    arch=x86_64
    ;;
  linux-x64)
    vpx_target=x86_64-linux-gcc
    ldflags="-static"
    ;;
  windows-x64)
    vpx_target=x86_64-win64-gcc
    ldflags="-static"
    exe=".exe"
    ffmpeg_flags=(--enable-w32threads)
    zlib_make=(-f win32/Makefile.gcc)
    ;;
  *)
    echo "unknown target: $target" >&2
    exit 2
    ;;
esac

if [[ "$target" == darwin-* ]]; then
  if [[ "$(uname -m)" != "$arch" ]]; then
    echo "build $target on a $arch Mac (this one is $(uname -m))" >&2
    exit 2
  fi
  export MACOSX_DEPLOYMENT_TARGET="$MACOS_MIN"
  cflags="-mmacosx-version-min=$MACOS_MIN"
  ldflags="-mmacosx-version-min=$MACOS_MIN"
fi

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

fetch() { # url sha256 file
  local url="$1" want="$2" file="$work/src/$3"
  if [[ ! -f "$file" ]]; then
    echo "fetching $url"
    curl --proto '=https' --tlsv1.2 -sSfL --retry 5 --retry-all-errors --retry-delay 10 -o "$file" "$url"
  fi
  local got
  got="$(sha256 "$file")"
  if [[ "$got" != "$want" ]]; then
    echo "checksum mismatch for $url: got $got, want $want" >&2
    rm -f "$file"
    exit 1
  fi
}

mkdir -p "$work/src" "$prefix"
cd "$work/src"

fetch "$FFMPEG_URL" "$FFMPEG_SHA256" "ffmpeg-${FFMPEG_VERSION}.tar.xz"
fetch "$ZLIB_URL" "$ZLIB_SHA256" "zlib-${ZLIB_VERSION}.tar.gz"
rm -rf "ffmpeg-${FFMPEG_VERSION}" "zlib-${ZLIB_VERSION}" libvpx
tar -xJf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
tar -xzf "zlib-${ZLIB_VERSION}.tar.gz"
git -c advice.detachedHead=false clone -q --depth 1 --branch "$LIBVPX_TAG" "$LIBVPX_REPO" libvpx
got_commit="$(git -C libvpx rev-parse HEAD)"
if [[ "$got_commit" != "$LIBVPX_COMMIT" ]]; then
  echo "libvpx $LIBVPX_TAG is $got_commit, want $LIBVPX_COMMIT" >&2
  exit 1
fi

echo "== zlib $ZLIB_VERSION"
(
  cd "zlib-${ZLIB_VERSION}"
  if [[ "$target" == windows-x64 ]]; then
    make -s "${zlib_make[@]}" -j"$jobs" libz.a CFLAGS="-O2"
    mkdir -p "$prefix/include" "$prefix/lib"
    cp zlib.h zconf.h "$prefix/include/"
    cp libz.a "$prefix/lib/"
  else
    CFLAGS="-O2 -fPIC $cflags" ./configure --static --prefix="$prefix" >/dev/null
    make -s -j"$jobs"
    make -s install >/dev/null
  fi
)

echo "== libvpx $LIBVPX_TAG ($vpx_target)"
(
  cd libvpx
  ./configure --prefix="$prefix" --target="$vpx_target" \
    --enable-static --disable-shared --enable-pic \
    --enable-vp8 --enable-vp9 --disable-examples --disable-tools --disable-docs \
    --disable-unit-tests --disable-install-bins --disable-install-docs \
    ${cflags:+--extra-cflags="$cflags"} >/dev/null
  make -s -j"$jobs" >/dev/null
  make -s install >/dev/null
)

echo "== ffmpeg $FFMPEG_VERSION"
configure_args=(
  --prefix="$prefix"
  --pkg-config-flags=--static
  --extra-cflags="-I$prefix/include $cflags"
  --extra-ldflags="-L$prefix/lib $ldflags"
  --disable-everything --disable-autodetect
  --disable-doc --disable-debug --disable-network
  --disable-ffplay --disable-ffprobe --disable-avdevice --disable-swresample
  --enable-static --disable-shared
  "${ffmpeg_flags[@]}"
  --enable-zlib --enable-libvpx
  --enable-protocol=file
  --enable-demuxer=concat,image2,png_pipe
  --enable-decoder=png
  --enable-encoder=libvpx_vp8,libvpx_vp9
  --enable-bsf=vp9_superframe
  --enable-muxer=webm
  --enable-filter=scale,format,null
)
(
  cd "ffmpeg-${FFMPEG_VERSION}"
  PKG_CONFIG_PATH="$prefix/lib/pkgconfig" ./configure "${configure_args[@]}" >"$work/configure.log" 2>&1 ||
    { tail -40 ffbuild/config.log; exit 1; }
  make -s -j"$jobs" "ffmpeg$exe" >/dev/null
  cp "ffmpeg$exe" "$out_dir/ffmpeg-7.1-$target$exe"
  grep -q '^CONFIG_GPL=yes' ffbuild/config.mak && { echo 'GPL build: refusing' >&2; exit 1; }
  grep -q '^CONFIG_NONFREE=yes' ffbuild/config.mak && { echo 'nonfree build: refusing' >&2; exit 1; }
  cp COPYING.LGPLv2.1 "$out_dir/"
)
cp libvpx/LICENSE "$out_dir/libvpx-LICENSE"
cp libvpx/PATENTS "$out_dir/libvpx-PATENTS"
sed -n '/^Copyright notice:/,$p' "zlib-${ZLIB_VERSION}/README" >"$out_dir/zlib-LICENSE"
case "$target" in
  linux-x64)
    fetch "$MUSL_URL" "$MUSL_SHA256" "musl-${MUSL_VERSION}.tar.gz"
    tar -xzOf "musl-${MUSL_VERSION}.tar.gz" "musl-${MUSL_VERSION}/COPYRIGHT" >"$out_dir/musl-COPYRIGHT"
    ;;
  windows-x64)
    # Static libgcc, mingw-w64 CRT and winpthreads: copy MSYS2's license files for them.
    notices="$out_dir/mingw-w64-notices"
    mkdir -p "$notices"
    for dir in /mingw64/share/licenses/*; do
      case "$(basename "$dir")" in
        *winpthread* | *crt* | *gcc-libs* | *libwinpthread* | *headers*) cp -R "$dir" "$notices/" ;;
      esac
    done
    [[ -n "$(ls -A "$notices")" ]] || { echo 'no mingw-w64 license files found' >&2; exit 1; }
    ;;
esac
mkdir -p "$out_dir/sources"
cp "ffmpeg-${FFMPEG_VERSION}.tar.xz" "zlib-${ZLIB_VERSION}.tar.gz" "$out_dir/sources/"
git -C libvpx archive --format=tar.gz --prefix="libvpx-${LIBVPX_TAG#v}/" -o "$out_dir/sources/libvpx-${LIBVPX_TAG#v}.tar.gz" HEAD

binary="$out_dir/ffmpeg-7.1-$target$exe"
# arm64 macOS will not run an unsigned binary; re-apply the linker's ad-hoc signature.
[[ "$target" == darwin-* ]] && codesign --force --sign - "$binary"

{
  echo "target: $target"
  echo "ffmpeg: $FFMPEG_VERSION $FFMPEG_URL sha256 $FFMPEG_SHA256"
  echo "zlib: $ZLIB_VERSION $ZLIB_URL sha256 $ZLIB_SHA256"
  echo "libvpx: $LIBVPX_TAG $LIBVPX_REPO commit $LIBVPX_COMMIT"
  echo "configure: ${configure_args[*]}" | sed "s#$prefix#\$PREFIX#g"
  echo "sha256: $(sha256 "$binary")  $(basename "$binary")"
} >"$out_dir/BUILD-$target.txt"
cat "$out_dir/BUILD-$target.txt"
"$here/check.sh" "$binary" "$work/check"
