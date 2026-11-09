#!/bin/bash -e
# Mirrors one LGPL libmpv Windows build from zhongfly/mpv-winbuild into this
# release, so the app pins a URL that does not disappear when upstream prunes
# its nightlies. The archive is kept as-is (7z with libmpv-2.dll, libmpv.dll.a
# and include/); the Flutter side extracts it with CMake.
#
# Usage: scripts/windows.sh <release-tag> <asset-name> <sha256>

tag="$1"; asset="$2"; expected="$3"
mkdir -p out
curl -fL --retry 3 -o "out/$asset" "https://github.com/zhongfly/mpv-winbuild/releases/download/$tag/$asset"
echo "$expected  out/$asset" | sha256sum -c -
(cd out && sha256sum "$asset" > "$asset.sha256")
echo "mpv-winbuild $tag $asset" > out/VERSIONS-windows-x86_64.txt
