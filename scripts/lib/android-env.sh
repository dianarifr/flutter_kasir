#!/usr/bin/env bash
# Helper Android bersama untuk scripts/*.sh.
#
# Bukan skrip yang dijalankan sendiri — di-source:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   . "$SCRIPT_DIR/lib/android-env.sh"
#
# Semua fungsi di sini hanya menulis ke stdout saat memang mengembalikan
# nilai (id device); pesan, peringatan, dan checklist selalu ke stderr
# supaya aman dipakai di dalam $(...).

# JDK 21 (~/tools/jdk-21) dan Android SDK (~/Android/Sdk) dipasang
# user-level tanpa root; pakai bila env belum diset.
android_env_init() {
  if ! command -v java >/dev/null 2>&1; then
    export JAVA_HOME="$HOME/tools/jdk-21"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  # adb ada di SDK, bukan di PATH sistem.
  export PATH="$ANDROID_HOME/platform-tools:$PATH"
}

android_require_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "!! adb tidak ditemukan. Cek ANDROID_HOME (sekarang: $ANDROID_HOME)" >&2
    exit 1
  fi
}

# Pilih satu device Android yang siap dipakai.
#
# Argumen : id device yang diminta lewat --device (boleh kosong).
# Stdout  : satu id device.
# Stderr  : pesan status + checklist bila tidak ada device siap.
android_select_device() {
  local requested="${1:-}"
  adb start-server >/dev/null 2>&1 || true

  # Device yang benar-benar siap dipakai (bukan offline/unauthorized).
  local -a ready=() pending=()
  mapfile -t ready < <(adb devices | awk 'NR>1 && $2 == "device" { print $1 }')
  mapfile -t pending < <(adb devices | awk 'NR>1 && $2 != "device" && NF > 1 { print $1 " (" $2 ")" }')

  if [ -z "$requested" ]; then
    if [ "${#ready[@]}" -eq 0 ]; then
      echo "!! Tidak ada device Android yang siap dipakai." >&2
      if [ "${#pending[@]}" -gt 0 ]; then
        echo "   Terdeteksi tapi belum siap:" >&2
        printf '     - %s\n' "${pending[@]}" >&2
        echo "   Kalau '(unauthorized)': cek HP, jawab \"Allow\" pada dialog USB debugging." >&2
      fi
      cat >&2 <<'EOF'

   Checklist:
     1. HP: Settings > About phone > ketuk "Build number" 7x
     2. Settings > Developer options > aktifkan "USB debugging"
     3. Colok kabel USB (kabel data, bukan charge-only) lalu pilih mode "File Transfer"
     4. Ulangi dialog "Allow USB debugging" di HP
     5. Cek dengan: adb devices -l
EOF
      exit 1
    fi

    if [ "${#ready[@]}" -gt 1 ]; then
      echo "!! Ada lebih dari satu device Android:" >&2
      printf '     - %s\n' "${ready[@]}" >&2
      echo "   Pilih satu lewat: --device <id>" >&2
      exit 1
    fi

    requested="${ready[0]}"
  else
    # Id yang diminta eksplisit: pastikan benar-benar terhubung & siap,
    # supaya adb tidak error samar di langkah berikutnya.
    local found=0 id
    for id in "${ready[@]}"; do
      [ "$id" = "$requested" ] && found=1
    done
    if [ "$found" -eq 0 ]; then
      echo "!! Device '${requested}' tidak siap dipakai." >&2
      if [ "${#ready[@]}" -gt 0 ]; then
        echo "   Device yang siap:" >&2
        printf '     - %s\n' "${ready[@]}" >&2
      else
        echo "   Tidak ada device siap. Jalankan: adb devices -l" >&2
      fi
      exit 1
    fi
  fi

  printf '%s\n' "$requested"
}