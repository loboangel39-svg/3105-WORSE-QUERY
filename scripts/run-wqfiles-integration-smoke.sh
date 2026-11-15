#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
OUT="$ROOT/build-smoke"
APP="$OUT/WQIntegrationSmoke.app"
mkdir -p "$APP"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
ARCH=$(uname -m)
xcrun --sdk iphonesimulator clang -fobjc-arc -fmodules -arch "$ARCH" \
  -isysroot "$SDK" -mios-simulator-version-min=26.0 -O0 \
  -I Vendor/WQFiles Vendor/WQFiles/WQ*.m scripts/WQIntegrationSmoke.m \
  -framework UIKit -framework Foundation -framework Security -framework UniformTypeIdentifiers \
  -framework AVFoundation -framework AVKit -lsqlite3 -lz -o "$APP/WQIntegrationSmoke"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.3105.WQIntegrationSmoke</string>
<key>CFBundleExecutable</key><string>WQIntegrationSmoke</string>
<key>CFBundleName</key><string>WQIntegrationSmoke</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>26.0</string>
<key>UILaunchScreen</key><dict/>
</dict></plist>
PLIST
cp -R ThreeOneOSFive/WQFilesResources.bundle "$APP/"
codesign --force --sign - "$APP"
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for runtime,items in d["devices"].items() if "iOS-26" in runtime or "iOS-27" in runtime for x in items if "iPhone" in x["name"]))')
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch --console "$DEVICE" org.3105.WQIntegrationSmoke > "$OUT/simulator.log" 2>&1 &
LAUNCH_PID=$!
CONTAINER=$(xcrun simctl get_app_container "$DEVICE" org.3105.WQIntegrationSmoke data)
for i in $(seq 1 90); do
  if [[ -f "$CONTAINER/Documents/integration-smoke.json" ]]; then break; fi
  sleep 2
done
test -f "$CONTAINER/Documents/integration-smoke.json"
cp "$CONTAINER/Documents/integration-smoke.json" "$OUT/"
python3 -c 'import json; d=json.load(open("build-smoke/integration-smoke.json")); print(json.dumps(d,indent=2)); assert d["passed"]'
wait "$LAUNCH_PID" || true
