#!/bin/bash -e
# Builds libmpv for one Android ABI on top of mpv-android's buildscripts and
# packs every shared object the app has to ship into one zip.
#
# Usage: scripts/android.sh <arm64|armv7l|x86_64>
#
# Differences from a stock mpv-android build, applied with sed so the
# upstream scripts stay pinned and readable:
#   - ffmpeg is LGPL (no --enable-gpl), mpv is built with -Dgpl=false
#   - lua and curl are off: libmpv embedded in a Flutter app runs no scripts
#     and streams through ffmpeg's own protocols

arch="$1"
case "$arch" in
  arm64) abi=arm64-v8a; triple=aarch64-linux-android ;;
  armv7l) abi=armeabi-v7a; triple=arm-linux-androideabi ;;
  x86_64) abi=x86_64; triple=x86_64-linux-android ;;
  *) echo "unknown arch $arch" >&2; exit 1 ;;
esac

: "${MPV_ANDROID_COMMIT:?}"
: "${MPV_TAG:?}"
root=$(pwd)
out="$root/out"
mkdir -p "$out"

if [ ! -d mpv-android ]; then
  git clone https://github.com/mpv-android/mpv-android
  git -C mpv-android checkout "$MPV_ANDROID_COMMIT"
fi
cd mpv-android/buildscripts

sed -i 's/--disable-static --enable-shared --enable-{gpl,version3}/--disable-static --enable-shared --enable-version3/' scripts/ffmpeg.sh
grep -q -- '--enable-version3$' scripts/ffmpeg.sh || grep -q -- '--enable-version3 ' scripts/ffmpeg.sh
sed -i 's/-Diconv=disabled -D{lua,libcurl}=enabled/-Dgpl=false -Diconv=disabled -D{lua,libcurl}=disabled/' scripts/mpv.sh
grep -q -- '-Dgpl=false' scripts/mpv.sh
sed -i 's/^dep_mpv=(ffmpeg libass lua libplacebo curl)/dep_mpv=(ffmpeg libass libplacebo)/' include/depinfo.sh
grep -q '^dep_mpv=(ffmpeg libass libplacebo)' include/depinfo.sh

# mpv itself is pinned to a release tag; download-deps.sh skips a dir that
# already exists.
mkdir -p deps
[ -d deps/mpv ] || git clone --depth 1 --branch "$MPV_TAG" https://github.com/mpv-player/mpv deps/mpv

IN_CI=1 ./include/download-sdk.sh
IN_CI=1 ./include/download-deps.sh

./buildall.sh --arch "$arch" mpv || {
  build_dir="deps/mpv/_build_$arch"
  [ -f "$build_dir/meson-logs/meson-log.txt" ] && tail -100 "$build_dir/meson-logs/meson-log.txt"
  exit 1
}

prefix="prefix/$arch"
ndk=$(echo sdk/android-ndk-*)
toolchain=$(echo "$ndk"/toolchains/llvm/prebuilt/*)
stage=$(mktemp -d)

# libmpv.so plus the closure of what it needs from the prefix. Everything
# that is not from the prefix must come from the system (libc, liblog,
# libandroid, libmediandk...) or the NDK's libc++_shared.so.
copy_closure() {
  local lib="$1"
  [ -f "$stage/$(basename "$lib")" ] && return 0
  cp "$lib" "$stage/"
  for needed in $(llvm-readelf -d "$lib" | awk '/NEEDED/ {gsub(/[\[\]]/, "", $5); print $5}'); do
    if [ -f "$prefix/lib/$needed" ]; then
      copy_closure "$prefix/lib/$needed"
    elif [ "$needed" = "libc++_shared.so" ]; then
      cp "$toolchain/sysroot/usr/lib/$triple/libc++_shared.so" "$stage/"
    fi
  done
}
export PATH="$toolchain/bin:$PATH"
copy_closure "$prefix/lib/libmpv.so"
llvm-strip --strip-unneeded "$stage"/*.so

(cd "$stage" && ls -l && zip -q -X "$out/libmpv-android-$abi.zip" *.so)
(cd "$out" && sha256sum "libmpv-android-$abi.zip" > "libmpv-android-$abi.zip.sha256")

{
  echo "mpv-android $MPV_ANDROID_COMMIT"
  echo "mpv $MPV_TAG $(git -C deps/mpv rev-parse HEAD)"
  for d in ffmpeg libplacebo libass dav1d; do
    echo "$d $(git -C deps/$d describe --tags --always 2>/dev/null) $(git -C deps/$d rev-parse HEAD)"
  done
  echo "ndk $(basename "$ndk")"
} > "$out/VERSIONS-$abi.txt"
cat "$out/VERSIONS-$abi.txt"
