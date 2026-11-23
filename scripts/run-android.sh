#!/usr/bin/env bash
# Jalankan app di HP/emulator Android untuk development (hot reload).
#
# Bedanya dengan build-apk.sh: script ini memakai `flutter run`, jadi APK
# dipasang SEKALI lalu perubahan kode cukup di-`r` (hot reload, ~1 detik)
# alih-alih build + install ulang 2-3 menit tiap kali.
#
# Build ulang penuh hanya perlu bila: dependency pubspec berubah, manifest
# /build.gradle berubah, atau ada perubahan kode native.
#
# JAVA_HOME/ANDROID_HOME dipasang otomatis (JDK & SDK user-level tanpa root,
# sama seperti build-apk.sh).
#
# Pakai:
#   ./scripts/run-android.sh                       # device tunggal
#   ./scripts/run-android.sh --device emulator-5554
#   ./scripts/run-android.sh --release             # argumen lain diteruskan
#   ./scripts/run-android.sh --stop-daemon         # matikan Gradle daemon (hemat RAM)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
. "$SCRIPT_DIR/lib/android-env.sh"

android_env_init
android_require_adb

# --device <id> di-strip sendiri, sisanya diteruskan ke flutter run.
DEVICE_ID=""
STOP_DAEMON=0
FLUTTER_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --device|-d)
      [ "$#" -ge 2 ] || { echo "!! --device butuh nilai" >&2; exit 1; }
      DEVICE_ID="$2"
      shift 2
      ;;
    --stop-daemon)
      STOP_DAEMON=1
      shift
      ;;
    *)
      FLUTTER_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ "$STOP_DAEMON" = "1" ]; then
  echo "==> Menghentikan Gradle daemon (membebaskan RAM)..."
  (cd android && ./gradlew --stop >/dev/null 2>&1) || true
  echo "    Selesai."
  exit 0
fi

DEVICE_ID="$(android_select_device "$DEVICE_ID")"

echo "==> Device: ${DEVICE_ID}"

# Peringatan URL API: HP harus bisa menjangkau host di .env. Tidak memblokir
# karena backend bisa saja berjalan di mesin lain.
ANDROID_URL="$(sed -n 's/^API_BASE_URL_ANDROID=//p' .env 2>/dev/null | tr -d '\r' | head -n1)"
if [ -n "$ANDROID_URL" ]; then
  API_HOST="$(printf '%s' "$ANDROID_URL" | sed -E 's|^[a-zA-Z]+://||' | cut -d/ -f1 | cut -d: -f1)"
  if [ -n "$API_HOST" ] && ! ip -4 addr show scope global 2>/dev/null | grep -q "inet ${API_HOST}[ /]"; then
    echo "!! API_BASE_URL_ANDROID menunjuk ke ${API_HOST}, yang bukan IP mesin ini." >&2
    echo "   IP mesin ini:" >&2
    ip -4 addr show scope global 2>/dev/null | awk '/inet /{ sub("/.*","",$2); print "     - " $2 }' >&2
    echo "   Pastikan HP satu jaringan dan host itu memang bisa dijangkau dari HP." >&2
  fi
fi

# Host loopback hanya jalan di emulator (diremap ke 10.0.2.2), tidak di HP.
API_URL="$(sed -n 's/^API_BASE_URL=//p' .env 2>/dev/null | tr -d '\r' | head -n1)"
case "$API_URL" in
  *localhost* | *127.0.0.1*)
    echo "!! API_BASE_URL memakai alamat loopback (localhost/127.0.0.1)." >&2
    echo "   Itu hanya jalan di emulator. Untuk HP fisik, set" >&2
    echo "   API_BASE_URL_ANDROID ke URL/IP yang bisa dijangkau dari HP." >&2
    ;;
esac

# Build Android butuh ~3 GB (Gradle 2 GB + Kotlin daemon 1 GB). Kalau RAM
# mepet, sistem akan lag lalu OOM killer membunuh aplikasi lain — ini yang
# terjadi sebelumnya. Peringatan saja, bukan penghalang.
MEM_AVAIL_KB="$(awk '/^MemAvailable/ { print $2 }' /proc/meminfo 2>/dev/null || true)"
if [ -n "$MEM_AVAIL_KB" ] && [ "$MEM_AVAIL_KB" -lt 3145728 ]; then
  echo "!! RAM tersedia hanya $((MEM_AVAIL_KB / 1024)) MB (build butuh ~3 GB)." >&2
  echo "   Tutup VS Code/browser dulu, atau jalankan:" >&2
  echo "     ./scripts/run-android.sh --stop-daemon" >&2
fi

# versionCode disamakan dengan build-apk.sh (jumlah commit git). Tanpa ini,
# APK debug memakai +7 dari pubspec dan bisa ditolak adb
# (INSTALL_FAILED_VERSION_DOWNGRADE) saat HP sudah terpasang APK release
# hasil install-apk.sh yang versionCode-nya lebih tinggi.
BUILD_NUMBER="$(git rev-list --count HEAD)"

cat <<'EOF'
==> flutter run
    Build pertama 1-3 menit (kompilasi native JNI, sekali saja). Jangan tutup terminal.
    Setelah app terbuka: 'r' hot reload (~1 detik), 'R' hot restart, 'q' keluar.
EOF
flutter run -d "$DEVICE_ID" --build-number="${BUILD_NUMBER}" ${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"}