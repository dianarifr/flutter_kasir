#!/usr/bin/env bash
# Pasang APK release terbaru ke HP/emulator Android.
#
# Berbeda dari run-android.sh (flutter run + hot reload) dan build-apk.sh
# (hanya menghasilkan file APK): script ini mengambil APK **release**
# terbaru yang sudah ada di build/app/outputs/flutter-apk, lalu memasangnya
# dengan `adb install -r` sehingga data aplikasi (sesi login, pengaturan)
# tidak hilang.
#
# Versi dipilih dari nama file (nyemil-nyam-vX.Y.Z.apk) dengan urutan
# versi, bukan urutan abjad — v1.10.0 dianggap lebih baru dari v1.9.0.
# APK split (--split-per-abi) dipilih sesuai ABI HP.
#
# Pakai:
#   ./scripts/install-apk.sh                       # APK release terbaru
#   ./scripts/install-apk.sh --build               # build dulu, lalu pasang
#   ./scripts/install-apk.sh --device emulator-5554
#   ./scripts/install-apk.sh --apk path/ke/app.apk
#   ./scripts/install-apk.sh --list                # daftar APK & tandai terbaru
#   ./scripts/install-apk.sh --launch              # buka app setelah terpasang
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
. "$SCRIPT_DIR/lib/android-env.sh"

# applicationId di android/app/build.gradle.kts
PACKAGE="com.example.flutter_kasir"
APK_DIR="build/app/outputs/flutter-apk"

DEVICE_ID=""
APK_PATH=""
DO_BUILD=0
DO_LIST=0
DO_LAUNCH=0

usage() {
  cat <<EOF
Pasang APK release terbaru ke device Android.

Pakai:
  ./scripts/install-apk.sh                 # APK release terbaru
  ./scripts/install-apk.sh --build         # build dulu (build-apk.sh) lalu pasang
  ./scripts/install-apk.sh -d <id>         # pilih device (sama: --device)
  ./scripts/install-apk.sh --apk <file>    # pasang file APK tertentu
  ./scripts/install-apk.sh --list          # daftar APK di ${APK_DIR}
  ./scripts/install-apk.sh --launch        # buka app setelah terpasang
  ./scripts/install-apk.sh -h              # bantuan ini

Data aplikasi tidak dihapus (adb install -r). Uninstall manual hanya
diperlukan bila signature APK berbeda.
EOF
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

# Nama file APK berversi -> X.Y.Z
apk_version() {
  basename "$1" | sed -E 's/^nyemil-nyam-v([0-9]+\.[0-9]+\.[0-9]+).*/\1/'
}

# Semua APK berversi, urut versi naik.
mapfile -t VERSIONED < <(compgen -G "${APK_DIR}/nyemil-nyam-v*.apk" | sort -V)

if [ "$DO_LIST" -eq 1 ]; then
  if [ "${#VERSIONED[@]}" -eq 0 ]; then
    echo "Belum ada APK berversi di ${APK_DIR}." >&2
    echo "Jalankan dulu: ./scripts/build-apk.sh" >&2
    exit 1
  fi
  LATEST_VERSION="$(for apk in "${VERSIONED[@]}"; do apk_version "$apk"; done | sort -Vu | tail -1)"
  echo "APK di ${APK_DIR} (urut versi):"
  for apk in "${VERSIONED[@]}"; do
    version="$(apk_version "$apk")"
    marker=""
    [ "$version" = "$LATEST_VERSION" ] && marker="  <= terbaru"
    printf '  %-9s %6s  %s%s\n' "v${version}" "$(du -h "$apk" | cut -f1)" "$(basename "$apk")" "$marker"
  done
  exit 0
fi

if [ "$DO_BUILD" -eq 1 ]; then
  echo "==> Build APK dulu lewat scripts/build-apk.sh"
  "$SCRIPT_DIR/build-apk.sh"
  # Muat ulang daftar setelah build.
  mapfile -t VERSIONED < <(compgen -G "${APK_DIR}/nyemil-nyam-v*.apk" | sort -V)
fi

if [ -n "$APK_PATH" ]; then
  [ -f "$APK_PATH" ] || { echo "!! File APK tidak ditemukan: ${APK_PATH}" >&2; exit 1; }
elif [ "${#VERSIONED[@]}" -eq 0 ]; then
  echo "!! Belum ada APK release di ${APK_DIR}." >&2
  echo "   Jalankan dulu: ./scripts/build-apk.sh" >&2
  echo "   Atau: ./scripts/install-apk.sh --build" >&2
  exit 1
fi

android_require_adb
DEVICE_ID="$(android_select_device "$DEVICE_ID")"
echo "==> Device: ${DEVICE_ID}"

# Pilih APK setelah device diketahui, supaya APK split bisa dicocokkan
# dengan ABI HP.
if [ -z "$APK_PATH" ]; then
  LATEST_VERSION="$(for apk in "${VERSIONED[@]}"; do apk_version "$apk"; done | sort -Vu | tail -1)"
  UNIVERSAL="${APK_DIR}/nyemil-nyam-v${LATEST_VERSION}.apk"

  if [ -f "$UNIVERSAL" ]; then
    APK_PATH="$UNIVERSAL"
  else
    DEV_ABI="$(adb -s "$DEVICE_ID" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r' | head -n1)"
    SPLIT="${APK_DIR}/nyemil-nyam-v${LATEST_VERSION}-${DEV_ABI}.apk"
    if [ -n "$DEV_ABI" ] && [ -f "$SPLIT" ]; then
      APK_PATH="$SPLIT"
    else
      echo "!! v${LATEST_VERSION} hanya tersedia sebagai APK split, tidak ada yang cocok." >&2
      echo "   ABI device: ${DEV_ABI:-tidak diketahui}" >&2
      echo "   Tersedia:" >&2
      compgen -G "${APK_DIR}/nyemil-nyam-v${LATEST_VERSION}-*.apk" | sed 's/^/     - /' >&2 || true
      echo "   Pakai APK universal: ./scripts/install-apk.sh --build" >&2
      exit 1
    fi
  fi
fi

EXPECTED_VERSION="$(apk_version "$APK_PATH")"
# Hanya bandingkan bila nama file memang berpola versi (mis. --apk app-release.apk).
[[ "$EXPECTED_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || EXPECTED_VERSION=""
echo "==> Pasang: $(basename "$APK_PATH")"
echo "    Data aplikasi dipertahankan (install -r)."

if ! INSTALL_OUT="$(adb -s "$DEVICE_ID" install -r "$APK_PATH" 2>&1)"; then
  echo "$INSTALL_OUT" >&2
  case "$INSTALL_OUT" in
    *INSTALL_FAILED_VERSION_DOWNGRADE*)
      echo "!! APK ini lebih lama dari yang terpasang di HP." >&2
      echo "   Cek versi terpasang dengan: adb -s ${DEVICE_ID} shell dumpsys package ${PACKAGE} | grep version" >&2
      echo "   Atau build versi baru: ./scripts/install-apk.sh --build" >&2
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