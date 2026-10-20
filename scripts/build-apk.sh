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
cd "$(dirname "$0")/.."

if ! command -v java >/dev/null 2>&1; then
  export JAVA_HOME="$HOME/tools/jdk-21"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"

BUILD_NUMBER="$(git rev-list --count HEAD)"
echo "==> Build APK release — versionCode=${BUILD_NUMBER} (dari jumlah commit git)"

flutter build apk --release --build-number="${BUILD_NUMBER}" "$@"
