# kirahe-libmpv-build

Prebuilt libmpv for the Kirahe Player app.

- Android: built from [mpv-android](https://github.com/mpv-android/mpv-android)'s
  buildscripts with LGPL flags (`scripts/android.sh`), one zip per ABI holding
  `libmpv.so`, the shared ffmpeg libraries it links, and `libc++_shared.so`.
- Windows: a mirror of one LGPL x86_64 dev archive from
  [zhongfly/mpv-winbuild](https://github.com/zhongfly/mpv-winbuild).
- Linux: nothing; the app uses the distribution's libmpv.

Releases are cut by hand from the `release` workflow. `VERSIONS.txt` on each
release records every pinned commit; `SHA256SUMS` is what the app verifies.
