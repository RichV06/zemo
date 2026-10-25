#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# SwiftPM's manifest sandbox cannot nest inside some managed build environments.
# This flag affects the build tools only; Zemo's Codex tasks retain their sandbox.
swift build --disable-sandbox -c release --product AstroBoyero
app="dist/Zemo.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/AstroBoyero "$app/Contents/MacOS/Zemo"
cp Assets/sprites/zemo-sheet.png Assets/sprites/frames.json Assets/sprites/menubar.png "Assets/sprites/menubar@2x.png" "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Zemo</string>
<key>CFBundleIdentifier</key><string>dev.zemo.app</string>
<key>CFBundleName</key><string>Zemo</string>
<key>CFBundleDisplayName</key><string>Zemo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>ZemoIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSMicrophoneUsageDescription</key><string>Zemo usa el micrófono solo mientras dictas una instrucción. No guarda audio.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Zemo transcribe tu voz en el Mac, sin enviar audio a otros servicios, para convertirla en texto que revisas antes de enviar.</string>
<key>NSHumanReadableCopyright</key><string>Zemo</string>
</dict></plist>
PLIST
# sips only resizes Assets/icon-1024.png, which tools/sprites/build.py generates from the sprite.
iconset="dist/ZemoIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/icon-1024.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Assets/icon-1024.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
python3 - "$iconset" "$app/Contents/Resources/ZemoIcon.icns" <<'PYICON'
import pathlib
import struct
import sys
source, destination = map(pathlib.Path, sys.argv[1:])
chunks = []
for kind, name in [(b'icp4', 'icon_16x16.png'), (b'icp5', 'icon_32x32.png'),
                   (b'icp6', 'icon_32x32@2x.png'), (b'ic07', 'icon_128x128.png'),
                   (b'ic08', 'icon_256x256.png'), (b'ic09', 'icon_512x512.png'),
                   (b'ic10', 'icon_512x512@2x.png')]:
    png = (source / name).read_bytes()
    chunks.append(kind + struct.pack('>I', len(png) + 8) + png)
body = b''.join(chunks)
destination.write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
PYICON
codesign --force --sign - "$app"
printf 'App creada: %s\n' "$PWD/$app"
