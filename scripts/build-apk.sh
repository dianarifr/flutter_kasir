#!/usr/bin/env bash
# Build APK release untuk app kasir.
#
# versionCode diambil otomatis dari jumlah commit git (`git rev-list
# --count HEAD`) sehingga selalu naik — syarat update-over-install
# Android (install ditolak bila versionCode sama/lebih rendah).
# versionName tetap dari pubspec.yaml (di-bump manual saat rilis fitur
# dan itulah yang tampil di halaman login).
#
# JDK 21 (~/tools/jdk-21) dan Android SDK (~/Android/Sdk) dipasang
# user-level tanpa root; script memakainya bila env belum diset.
#
# Pakai:
#   ./scripts/build-apk.sh              # APK universal
#   ./scripts/build-apk.sh --split-per-abi   # APK per arsitektur
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
. "$SCRIPT_DIR/lib/android-env.sh"

android_env_init

BUILD_NUMBER="$(git rev-list --count HEAD)"
echo "==> Build APK release — versionCode=${BUILD_NUMBER} (dari jumlah commit git)"

APK_DIR="build/app/outputs/flutter-apk"
# Buang APK dari build sebelumnya agar hasil split dan universal tidak
# tercampur (mis. app-release.apk lama ikut tersalin saat mode split).
rm -f "$APK_DIR"/app-release.apk "$APK_DIR"/app-*-release.apk

flutter build apk --release --build-number="${BUILD_NUMBER}" "$@"

# Salin hasil build dengan nama yang mudah dikenali, mis.
# nyemil-nyam-v1.2.0.apk (universal) atau
# nyemil-nyam-v1.2.0-arm64-v8a.apk (--split-per-abi).
VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | cut -d '+' -f1)"

FOUND=0
for apk in "$APK_DIR"/app-release.apk "$APK_DIR"/app-*-release.apk; do
  [ -f "$apk" ] || continue
  name="$(basename "$apk")"
  if [ "$name" = "app-release.apk" ]; then
    suffix=""
  else
    # app-arm64-v8a-release.apk -> arm64-v8a
    suffix="-${name#app-}"
    suffix="${suffix%-release.apk}"
  fi
  final="${APK_DIR}/nyemil-nyam-v${VERSION}${suffix}.apk"
  cp "$apk" "$final"
  FOUND=1
  echo "==> APK siap: ${final}"
  [ -z "$suffix" ] || echo "    (versionCode APK split = nilai dasar + 1000 * kode ABI, normal)"
done

if [ "$FOUND" -eq 0 ]; then
  echo "!! Tidak ada APK yang dihasilkan di ${APK_DIR}" >&2
  exit 1
fi
