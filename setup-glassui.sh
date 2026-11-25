#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

APP_TITLE="GlassUI Android Setup"
DEFAULT_GAME_DIR="/storage/emulated/0/Android/data/com.movtery.zalithlauncher.v2/files/.minecraft/versions/1.21.11 Fabric 0.19.5"
DEFAULT_CONFIG_DIR="$DEFAULT_GAME_DIR/config/glassui"
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

set_ffmpeg_path_json(){
  local config_dir="$1" ffmpeg_path="$2"
  local json="$config_dir/../glassui.json"
  # common: config_dir is .../config/glassui ; glassui.json is .../config/glassui.json
  local parent
  parent="$(dirname "$config_dir")"
  json="$parent/glassui.json"
  if [ -f "$json" ]; then
    tmp="$json.tmp"
    jq --arg p "$ffmpegPathVal" '.ffmpegPath=$p' "$json" > "$tmp" && mv "$tmp" "$json"
    echo "Updated ffmpegPath in $json" >&2
  else
    cat > "$json" <<JSON
{
  "ffmpegPath": "$ffmpegPathVal"
}
JSON
    echo "Created $json with ffmpegPath" >&2
  fi
}

main(){
  ui_msg "Setup GlassUI Android oleh Alpoyy. Script ini bisa minta izin storage, salin ffmpeg, dan set ffmpegPath di glassui.json."
  need_storage
  ensure_deps

  local action
  action=$(ui_radio "$APP_TITLE" "Pilih aksi:" "Setup ffmpeg + set path" "Salin ffmpeg saja" "Set ffmpegPath saja" "Keluar")
  [ "$action" = "Keluar" ] && exit 0

  local config_dir ffmpeg_path
  config_dir=$(ui_input "$APP_TITLE" "Masukkan folder config glassui:" "$DEFAULT_CONFIG_DIR")
  ffmpeg_path="$config_dir/ffmpeg"

  if [ "$action" = "Setup ffmpeg + set path" ] || [ "$action" = "Salin ffmpeg saja" ]; then
    copy_ffmpeg "$config_dir" >/dev/null
    ui_msg "ffmpeg disalin ke: $ffmpeg_path"
  fi

  if [ "$action" = "Setup ffmpeg + set path" ] || [ "$action" = "Set ffmpegPath saja" ]; then
    ffmpegPathVal="$ffmpeg_path"
    set_ffmpeg_path_json "$config_dir" "$ffmpeg_path"
    ui_msg "ffmpegPath diset ke:\n$ffmpeg_path\n\nRestart Minecraft setelah ini."
  fi

  ui_msg "Selesai. Jika musik tetap tidak jalan, pastikan ffmpeg kompatibel dengan launcher Android kamu (arm64) dan GlassUI v1.3.23+ terpasang."
}

main "$@"
