#!/usr/bin/env bash
# Pasang APK release ke HP/emulator Android.
#
# Sumber APK: build/app/outputs/flutter-apk/nyemil-nyam-latest.apk — hasil
# ./scripts/build-apk.sh. Namanya sengaja tetap ("latest") supaya selalu
# jelas file mana yang terbaru; versi sebenarnya dibaca dari isi APK, bukan
# ditebak dari nama file.
#
# Memakai `adb install -r` sehingga data aplikasi (sesi login, pengaturan)
# tidak hilang. Uninstall manual hanya perlu bila signature APK berbeda.
#
# Pakai:
#   ./scripts/install-apk.sh                 # APK latest
#   ./scripts/install-apk.sh --build         # build dulu (build-apk.sh) lalu pasang
#   ./scripts/install-apk.sh -d <id>         # pilih device (sama: --device)
#   ./scripts/install-apk.sh --apk <file>    # pasang file APK tertentu
#   ./scripts/install-apk.sh --list          # info APK yang akan dipasang
#   ./scripts/install-apk.sh --launch        # buka app setelah terpasang
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
. "$SCRIPT_DIR/lib/android-env.sh"

# applicationId di android/app/build.gradle.kts
PACKAGE="com.example.flutter_kasir"
APK_DIR="build/app/outputs/flutter-apk"
LATEST_APK="${APK_DIR}/nyemil-nyam-latest.apk"

DEVICE_ID=""
APK_PATH=""
DO_BUILD=0
DO_LIST=0
DO_LAUNCH=0

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$SCRIPT_DIR/install-apk.sh"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --device|-d)
      [ "$#" -ge 2 ] || { echo "!! --device butuh nilai" >&2; exit 1; }
      DEVICE_ID="$2"
      shift 2
      ;;
    --apk)
      [ "$#" -ge 2 ] || { echo "!! --apk butuh nilai" >&2; exit 1; }
      APK_PATH="$2"
      shift 2
      ;;
    --build)
      DO_BUILD=1
      shift
      ;;
    --list)
      DO_LIST=1
      shift
      ;;
    --launch)
      DO_LAUNCH=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "!! Argumen tidak dikenal: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

android_env_init

# Versi dari isi APK (aapt2 di build-tools). Stdout: "<versionName> <versionCode>",
# kosong bila aapt2 tidak tersedia / gagal membaca.
apk_version_info() {
  local apk="$1" aapt2 out
  aapt2="$(compgen -G "${ANDROID_HOME}/build-tools/*/aapt2" 2>/dev/null | sort -V | tail -1)"
  [ -n "$aapt2" ] || return 0
  out="$("$aapt2" dump badging "$apk" 2>/dev/null | sed -n "s/^package:.*versionCode='\([0-9]*\)'.*versionName='\([^']*\)'.*/\2 \1/p" | head -n1)"
  printf '%s\n' "$out"
}

apk_mtime() {
  date -r "$1" '+%d %b %Y %H:%M' 2>/dev/null || echo '?'
}

show_apk() {
  local apk="$1" info version code
  info="$(apk_version_info "$apk")"
  version="${info%% *}"
  code="${info##* }"
  printf '  %s\n' "$(basename "$apk")"
  printf '    versi   : %s\n' "$(if [ -n "$version" ]; then echo "${version} (versionCode ${code})"; else echo 'tidak terbaca (aapt2 tidak ada)'; fi)"
  printf '    ukuran  : %s\n' "$(du -h "$apk" | cut -f1)"
  printf '    dibuild : %s\n' "$(apk_mtime "$apk")"
}

# Pilih APK: --apk eksplisit > nyemil-nyam-latest.apk > app-release.apk.
resolve_apk() {
  if [ -n "$APK_PATH" ]; then
    [ -f "$APK_PATH" ] || { echo "!! File APK tidak ditemukan: ${APK_PATH}" >&2; exit 1; }
    return 0
  fi
  if [ -f "$LATEST_APK" ]; then
    APK_PATH="$LATEST_APK"
    return 0
  fi
  if [ -f "${APK_DIR}/app-release.apk" ]; then
    APK_PATH="${APK_DIR}/app-release.apk"
    return 0
  fi
  echo "!! Belum ada APK release di ${APK_DIR}." >&2
  echo "   Jalankan dulu: ./scripts/build-apk.sh" >&2
  echo "   Atau: ./scripts/install-apk.sh --build" >&2
  exit 1
}

if [ "$DO_BUILD" -eq 1 ]; then
  echo "==> Build APK dulu lewat scripts/build-apk.sh"
  "$SCRIPT_DIR/build-apk.sh"
fi

if [ "$DO_LIST" -eq 1 ]; then
  if [ -n "$APK_PATH" ]; then
    [ -f "$APK_PATH" ] || { echo "!! File APK tidak ditemukan: ${APK_PATH}" >&2; exit 1; }
    show_apk "$APK_PATH"
  elif [ -f "$LATEST_APK" ]; then
    show_apk "$LATEST_APK"
  elif [ -f "${APK_DIR}/app-release.apk" ]; then
    show_apk "${APK_DIR}/app-release.apk"
  else
    echo "Belum ada APK release di ${APK_DIR}." >&2
    echo "Jalankan dulu: ./scripts/build-apk.sh" >&2
    exit 1
  fi
  exit 0
fi

resolve_apk

# Versi yang diharapkan, dibaca dari isi APK (bukan dari nama file).
EXPECTED_INFO="$(apk_version_info "$APK_PATH")"
EXPECTED_VERSION="${EXPECTED_INFO%% *}"
EXPECTED_CODE="${EXPECTED_INFO##* }"
[ -n "$EXPECTED_INFO" ] || { EXPECTED_VERSION=""; EXPECTED_CODE=""; }

echo "==> Pasang: $(basename "$APK_PATH") ($(du -h "$APK_PATH" | cut -f1))"
if [ -n "$EXPECTED_VERSION" ]; then
  echo "    Versi APK: ${EXPECTED_VERSION} (versionCode ${EXPECTED_CODE})"
fi

android_require_adb
DEVICE_ID="$(android_select_device "$DEVICE_ID")"
echo "==> Device: ${DEVICE_ID}"
echo "    Data aplikasi dipertahankan (install -r)."

if ! INSTALL_OUT="$(adb -s "$DEVICE_ID" install -r "$APK_PATH" 2>&1)"; then
  echo "$INSTALL_OUT" >&2
  case "$INSTALL_OUT" in
    *INSTALL_FAILED_VERSION_DOWNGRADE*)
      echo "!! APK ini lebih lama dari yang terpasang di HP." >&2
      echo "   Cek versi terpasang: adb -s ${DEVICE_ID} shell dumpsys package ${PACKAGE} | grep version" >&2
      echo "   Build versi baru: ./scripts/install-apk.sh --build" >&2
      ;;
    *INSTALL_FAILED_UPDATE_INCOMPATIBLE*)
      echo "!! Signature APK berbeda dengan yang terpasang." >&2
      echo "   Uninstall dulu (data aplikasi akan hilang):" >&2
      echo "     adb -s ${DEVICE_ID} uninstall ${PACKAGE}" >&2
      ;;
    *INSTALL_FAILED_INSUFFICIENT_STORAGE*)
      echo "!! Penyimpanan HP penuh. Kosongkan dulu, lalu ulangi." >&2
      ;;
    *INSTALL_FAILED_OLDER_SDK*)
      echo "!! Android di HP lebih lama dari minSdk APK." >&2
      ;;
    *)
      echo "!! Instalasi gagal. Pesan adb di atas adalah penyebabnya." >&2
      ;;
  esac
  exit 1
fi
echo "==> ${INSTALL_OUT}"

# Verifikasi versi yang benar-benar terpasang, bukan menebak dari nama file.
PKG_INFO="$(adb -s "$DEVICE_ID" shell dumpsys package "$PACKAGE" 2>/dev/null | tr -d '\r')"
INSTALLED_VERSION="$(printf '%s\n' "$PKG_INFO" | grep -m1 -oE 'versionName=[^ ]+' | cut -d= -f2)"
INSTALLED_CODE="$(printf '%s\n' "$PKG_INFO" | grep -m1 -oE 'versionCode=[0-9]+' | cut -d= -f2)"

if [ -n "$INSTALLED_VERSION" ]; then
  echo "==> Terpasang: ${PACKAGE} versionName ${INSTALLED_VERSION} (versionCode ${INSTALLED_CODE:-?})"
  if [ -n "$EXPECTED_VERSION" ] && [ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]; then
    echo "!! Versi terpasang (${INSTALLED_VERSION}) beda dari file APK (${EXPECTED_VERSION})." >&2
  fi
  if [ -n "$EXPECTED_CODE" ] && [ -n "$INSTALLED_CODE" ] && [ "$INSTALLED_CODE" != "$EXPECTED_CODE" ]; then
    echo "!! versionCode terpasang (${INSTALLED_CODE}) beda dari file APK (${EXPECTED_CODE})." >&2
  fi
else
  echo "!! Tidak bisa membaca versi terpasang (adb dumpsys gagal)." >&2
fi

if [ "$DO_LAUNCH" -eq 1 ]; then
  adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || {
    echo "!! Gagal membuka app. Buka manual dari layar HP." >&2
    exit 1
  }
  echo "==> App dibuka di device."
fi