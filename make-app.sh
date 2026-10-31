#!/bin/sh
# Builds DisplayCtl.app, a double-clickable menu bar app wrapping the same
# binary. LSUIElement keeps it out of the Dock and the app switcher.
set -e

cd "$(dirname "$0")"
APP=DisplayCtl.app

# -trimpath keeps local file paths out of the shipped binary.
go build -trimpath -ldflags "-s -w" -o displayctl .

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
# Named displayctl-bin, not displayctl: the launcher below is "DisplayCtl", and
# on a case-insensitive filesystem that is the same name, so one would silently
# overwrite the other.
cp displayctl "$APP/Contents/MacOS/displayctl-bin"

# Opened from Finder, displayctl-bin runs the menu itself. This launcher only
# remains for login agents written by older versions, which point at it.
cat > "$APP/Contents/MacOS/DisplayCtl" <<'EOF'
#!/bin/sh
# Launched with no terminal attached, so keep a log to look at when something
# does not appear in the menu bar.
LOG="$HOME/Library/Logs/displayctl.log"
exec "$(dirname "$0")/displayctl-bin" menu >>"$LOG" 2>&1
EOF
chmod +x "$APP/Contents/MacOS/DisplayCtl"

# Finder shows Contents/Resources/AppIcon.icns, built from icon/icon.png at
# every size macOS asks for.
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET" "$APP/Contents/Resources"
for n in 16 32 128 256 512; do
	sips -z $n $n icon/icon.png --out "$ICONSET/icon_${n}x${n}.png" >/dev/null
	sips -z $((n * 2)) $((n * 2)) icon/icon.png --out "$ICONSET/icon_${n}x${n}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>DisplayCtl</string>
	<key>CFBundleDisplayName</key><string>DisplayCtl</string>
	<key>CFBundleIdentifier</key><string>local.displayctl</string>
	<key>CFBundleExecutable</key><string>displayctl-bin</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>${VERSION:-0.1.0}</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# Sign the whole bundle, not just the binary the Go linker already signs, or
# macOS reports the app as not signed at all and calls the download damaged.
# Ad-hoc ("-") by default; set SIGN_IDENTITY to a Developer ID Application
# certificate to sign for distribution (notarizing is a separate step, and
# needs the secure timestamp that ad-hoc signing cannot have).
TIMESTAMP=
[ "${SIGN_IDENTITY:--}" = - ] || TIMESTAMP=--timestamp
codesign --force --deep --options runtime $TIMESTAMP \
	-s "${SIGN_IDENTITY:--}" -i local.displayctl "$APP"

echo "built $(pwd)/$APP"
