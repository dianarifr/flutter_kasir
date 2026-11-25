#!/usr/bin/env bash
# Build APK release untuk app kasir.
#
# Hasil build selalu satu file dengan nama tetap: nyemil-nyam-latest.apk
# (+ nyemil-nyam-latest.apk.sha1 dari Flutter), jadi tidak perlu menebak
# mana APK terbaru. APK lama di folder build dibuang lebih dulu supaya
# tidak ada versi basi yang ikut terpasang.
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
#   ./scripts/build-apk.sh        # APK universal -> nyemil-nyam-latest.apk
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
. "$SCRIPT_DIR/lib/android-env.sh"

case "${1:-}" in
  -h|--help)
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$SCRIPT_DIR/build-apk.sh"
    exit 0
    ;;
  "")
    ;;
  --split-per-abi)
    # Mode split menghasilkan app-<abi>-release.apk, bukan satu APK
    # universal, jadi tidak cocok dengan nama file tetap di script ini.
    echo "!! --split-per-abi tidak didukung lagi." >&2
    echo "   Script ini hanya menghasilkan satu APK universal:" >&2
    echo "     ${PWD}/build/app/outputs/flutter-apk/nyemil-nyam-latest.apk" >&2
    exit 1
    ;;
  *)
    echo "!! Argumen tidak dikenal: $1" >&2
    echo "   Pakai: ./scripts/build-apk.sh   (tanpa argumen)" >&2
    exit 1
    ;;
esac

android_env_init

BUILD_NUMBER="$(git rev-list --count HEAD)"
echo "==> Build APK release — versionCode=${BUILD_NUMBER} (dari jumlah commit git)"

APK_DIR="build/app/outputs/flutter-apk"
FINAL_APK="${APK_DIR}/nyemil-nyam-latest.apk"

# Bersihkan artefak build sebelumnya: di folder ini hanya ingin satu APK
# (plus .sha1-nya). Termasuk APK split lama dan APK berversi lama.
rm -f "$APK_DIR"/app-release.apk \
      "$APK_DIR"/app-release.apk.sha1 \
      "$APK_DIR"/app-*-release.apk \
      "$APK_DIR"/nyemil-nyam-latest.apk \
      "$APK_DIR"/nyemil-nyam-latest.apk.sha1 \
      "$APK_DIR"/nyemil-nyam-v*.apk \
      "$APK_DIR"/nyemil-nyam-v*.apk.sha1

flutter build apk --release --build-number="${BUILD_NUMBER}"

if [ ! -f "$APK_DIR/app-release.apk" ]; then
  echo "!! Build selesai tapi ${APK_DIR}/app-release.apk tidak ada." >&2
  exit 1
fi

# Ganti nama hasil Flutter ke nama tetap. Isi .sha1 tetap valid karena
# hash-nya hash isi file, bukan nama file.
mv "$APK_DIR/app-release.apk" "$FINAL_APK"
if [ -f "$APK_DIR/app-release.apk.sha1" ]; then
  mv "$APK_DIR/app-release.apk.sha1" "${FINAL_APK}.sha1"
fi

VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | cut -d '+' -f1)"
echo "==> APK siap: ${FINAL_APK} (versi ${VERSION}, versionCode ${BUILD_NUMBER}, $(du -h "$FINAL_APK" | cut -f1))"
echo "    Pasang ke HP: ./scripts/install-apk.sh"