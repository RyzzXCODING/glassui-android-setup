#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

APP_TITLE="GlassUI Android Setup"
DEFAULT_GAME_DIR="/storage/emulated/0/Android/data/com.movtery.zalithlauncher.v2/files/.minecraft/versions/1.21.11 Fabric 0.19.5"
DEFAULT_CONFIG_DIR="$DEFAULT_GAME_DIR/config/glassui"
DEFAULT_DOWNLOAD_DIR="/storage/emulated/0/Download"
FFMPEG_RELEASE_URL="https://github.com/RyzzXCODING/ffmpeg-android-arm64-glassui/releases/latest/download/ffmpeg"

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

ui_msg(){
  local msg="$1"
  if have_cmd termux-dialog; then
    termux-dialog confirm -t "$APP_TITLE" -i "$msg" >/dev/null || true
  else
    printf "\n[%s]\n%s\n" "$APP_TITLE" "$msg"
  fi
}

ui_confirm(){
  local msg="$1"
  if have_cmd termux-dialog; then
    local out
    out=$(termux-dialog confirm -t "$APP_TITLE" -i "$msg" 2>/dev/null || true)
    echo "$out" | grep -q '"text"[[:space:]]*:[[:space:]]*"yes"'
  else
    printf "\n%s [y/N]: " "$msg"
    read -r ans
    [[ "${ans:-}" =~ ^[Yy]$ ]]
  fi
}

ui_input(){
  local title="$1" hint="$2" def="$3"
  if have_cmd termux-dialog; then
    local out text
    out=$(termux-dialog text -t "$title" -i "$hint" -n -v "$def" 2>/dev/null || true)
    text=$(echo "$out" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n1)
    if [ -n "$text" ]; then echo "$text"; else echo "$def"; fi
  else
    printf "%s\n[%s]: " "$hint" "$def" >&2
    read -r ans
    if [ -n "${ans:-}" ]; then echo "$ans"; else echo "$def"; fi
  fi
}

ui_radio(){
  local title="$1" hint="$2"; shift 2
  local opts=("$@")
  if have_cmd termux-dialog; then
    local args=()
    for o in "${opts[@]}"; do args+=("$o"); done
    local out idx
    out=$(termux-dialog radio -t "$title" -v "$(IFS=,; echo "${args[*]}")" 2>/dev/null || true)
    idx=$(echo "$out" | sed -n 's/.*"index"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p' | head -n1)
    if [ -n "$idx" ] && [ "$idx" -ge 0 ] && [ "$idx" -lt "${#opts[@]}" ]; then
      echo "${opts[$idx]}"
      return
    fi
  fi
  echo "Pilih opsi:" >&2
  local i=1
  for o in "${opts[@]}"; do echo "  $i) $o" >&2; i=$((i+1)); done
  printf "Nomor [1]: " >&2
  read -r n
  n=${n:-1}
  if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#opts[@]}" ]; then
    echo "${opts[$((n-1))]}"
  else
    echo "${opts[0]}"
  fi
}

need_storage(){
  if ui_confirm "Script butuh izin storage Termux untuk akses folder Minecraft. Jalankan termux-setup-storage sekarang?"; then
    termux-setup-storage || true
    ui_msg "Jika popup izin muncul, izinkan akses storage. Lalu tekan OK untuk lanjut."
  fi
}

ensure_deps(){
  local missing=()
  for c in curl jq; do have_cmd "$c" || missing+=("$c"); done
  if [ ${#missing[@]} -gt 0 ]; then
    if ui_confirm "Paket dibutuhkan: ${missing[*]}. Install sekarang?"; then
      pkg update -y || true
      pkg install -y "${missing[@]}"
    else
      echo "Missing deps: ${missing[*]}" >&2
      exit 1
    fi
  fi
}

copy_ffmpeg(){
  local dest="$1"
  mkdir -p "$dest"
  local target="$dest/ffmpeg"
  echo "Downloading ffmpeg..." >&2
  curl -fL --retry 3 --retry-delay 2 "$FFMPEG_RELEASE_URL" -o "$target.tmp"
  mv "$target.tmp" "$target"
  chmod 755 "$target" || true
  echo "$target"
}

resolve_glassui_json(){
  local p="$1"
  if [ -d "$p" ]; then
    if [ "$(basename "$p")" = "glassui" ]; then
      echo "$(dirname "$p")/glassui.json"
    elif [ -f "$p/glassui.json" ]; then
      echo "$p/glassui.json"
    elif [ -f "$p/config/glassui.json" ]; then
      echo "$p/config/glassui.json"
    else
      echo "$p/glassui.json"
    fi
  else
    echo "$p"
  fi
}

set_ffmpeg_path_json(){
  local json_input="$1" ffmpeg_path="$2"
  local json
  json=$(resolve_glassui_json "$json_input")
  mkdir -p "$(dirname "$json")"
  if [ -f "$json" ]; then
    if ! jq empty "$json" >/dev/null 2>&1; then
      echo "ERROR: JSON tidak valid: $json" >&2
      return 1
    fi
    local tmp
    tmp="$json.tmp"
    jq --arg p "$ffmpeg_path" '.ffmpegPath = $p' "$json" > "$tmp" && mv "$tmp" "$json"
    echo "Updated ffmpegPath in $json" >&2
  else
    cat > "$json" <<JSON
{
  "ffmpegPath": "$ffmpeg_path"
}
JSON
    echo "Created $json with ffmpegPath" >&2
  fi
}

main(){
  ui_msg "Setup GlassUI Android oleh Alpoyy. Script ini minta izin storage, menyalin ffmpeg ke folder custom (default Downloads, bukan data), dan hanya mengubah ffmpegPath di glassui.json."
  need_storage
  ensure_deps

  local action
  action=$(ui_radio "$APP_TITLE" "Pilih aksi:" "Salin ffmpeg ke folder custom/Downloads" "Salin ffmpeg + set ffmpegPath" "Set ffmpegPath saja" "Keluar")
  [ "$action" = "Keluar" ] && exit 0

  local ffmpeg_dir ffmpeg_path
  if [ "$action" = "Salin ffmpeg ke folder custom/Downloads" ] || [ "$action" = "Salin ffmpeg + set ffmpegPath" ]; then
    ffmpeg_dir=$(ui_input "$APP_TITLE" "Masukkan folder tujuan salin ffmpeg (default Downloads, bukan folder data):" "$DEFAULT_DOWNLOAD_DIR")
    ffmpeg_path="$ffmpeg_dir/ffmpeg"
    copy_ffmpeg "$ffmpeg_dir" >/dev/null
    ui_msg "ffmpeg disalin ke: $ffmpeg_path"
  else
    ffmpeg_path=$(ui_input "$APP_TITLE" "Masukkan path lengkap file ffmpeg:" "$DEFAULT_DOWNLOAD_DIR/ffmpeg")
  fi

  if [ "$action" = "Salin ffmpeg + set ffmpegPath" ] || [ "$action" = "Set ffmpegPath saja" ]; then
    local json_input json
    json_input=$(ui_input "$APP_TITLE" "Masukkan path glassui.json (atau folder config):" "$DEFAULT_CONFIG_DIR/../glassui.json")
    json=$(resolve_glassui_json "$json_input")
    if [ ! -f "$json" ]; then
      if ui_confirm "File glassui.json tidak ditemukan di: $json. Buat file baru yang hanya berisi ffmpegPath?"; then
        :
      else
        ui_msg "Dibatalkan. ffmpegPath tidak diubah."
        exit 1
      fi
    fi
    set_ffmpeg_path_json "$json_input" "$ffmpeg_path"
    ui_msg "ffmpegPath diset ke:\n$ffmpeg_path\n\nHanya field ffmpegPath yang diubah. Restart Minecraft setelah ini."
  else
    ui_msg "Selesai. File ffmpeg ada di:\n$ffmpeg_path\n\nJika mau GlassUI pakai file ini, set ffmpegPath di glassui.json ke path tersebut."
  fi

  ui_msg "Selesai. Jika musik tetap tidak jalan, pastikan ffmpeg kompatibel dengan launcher Android kamu (arm64) dan GlassUI v1.3.23+ terpasang."
}

main "$@"
