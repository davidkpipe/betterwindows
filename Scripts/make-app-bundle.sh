#!/bin/sh
# Builds a release binary and wraps it in BetterWindows.app so features that
# require a real app bundle work: launch at login (SMAppService) and stable
# permission grants tied to the app instead of the launching terminal.
set -e
cd "$(dirname "$0")/.."

swift build -c release

APP=build/BetterWindows.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/BetterWindows "$APP/Contents/MacOS/BetterWindows"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>BetterWindows</string>
	<key>CFBundleIdentifier</key>
	<string>com.davidkpipe.BetterWindows</string>
	<key>CFBundleName</key>
	<string>BetterWindows</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"

echo "Built $APP"
echo "Launch it, grant Accessibility, and the launch-at-login toggle in Settings becomes available."
