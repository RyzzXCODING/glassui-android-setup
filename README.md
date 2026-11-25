# GlassUI Android Setup (Termux GUI)

Script Termux untuk setup GlassUI di Android (Zalith/Pojav-like launcher):
- minta izin storage (`termux-setup-storage`)
- unduh/salin `ffmpeg` arm64 ke folder config GlassUI
- set `ffmpegPath` di `glassui.json`

> Catatan: ffmpeg Android arm64 mungkin tidak kompatibel di semua launcher. Binary yang diunduh berasal dari release: https://github.com/RyzzXCODING/ffmpeg-android-arm64-glassui/releases/latest/download/ffmpeg

## Cara cepat (curl)

Jalankan di Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/RyzzXCODING/glassui-android-setup/master/setup-glassui.sh -o setup-glassui.sh && chmod +x setup-glassui.sh && bash setup-glassui.sh
```

## Default path (bisa diganti di GUI/input)

- Config dir: `/storage/emulated/0/Android/data/com.movtery.zalithlauncher.v2/files/.minecraft/versions/1.21.11 Fabric 0.19.5/config/glassui`
- ffmpeg: `<config-dir>/ffmpeg`
- glassui.json: `<config-dir>/../glassui.json`

## Setelah setup

1. Pastikan GlassUI v1.3.23+ terpasang.
2. Restart Minecraft/launcher.
3. Cek Music screen status. Jika ffmpeg tidak kompatibel, gunakan ffmpeg yang cocok untuk launcher/device kamu.

## Author

Alpoyy
