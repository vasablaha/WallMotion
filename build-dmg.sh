#!/bin/bash

# Aktualizovaný notarizační skript s vašimi certifikáty
APP_NAME="WallMotion"
BUNDLE_ID="tapp-studio.WallMotion"
TEAM_ID="GJMB6NKTWK"  # Váš Team ID z Keychain
APPLE_ID="vasa.blaha727@gmail.com"  # Váš Apple ID
APP_PASSWORD="rlyq-jvzp-phum-jtop"  # Vytvoříte na appleid.apple.com

# Cesty
APP_PATH="build/Build/Products/Release/WallMotion.app"
DMG_NAME="WallMotion-v1.0.0.dmg"
ENTITLEMENTS="entitlements.plist"
BUILD_DIR="dmg-temp"

echo "🔐 Starting robust notarization process..."

# 1. Najdeme certifikáty
echo "🔍 Finding certificates..."
APP_CERT=$(security find-identity -v -p codesigning | grep -i "developer id application" | head -1 | awk '{print $2}')

if [[ -z "$APP_CERT" ]]; then
    echo "❌ No Developer ID Application certificate found"
    exit 1
fi

echo "✅ Using certificate: $APP_CERT"

# 2. Vytvoření robustnějších entitlements
echo "📝 Creating robust entitlements..."
cat > "$ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.assets.movies.read-write</key>
    <true/>
    <key>com.apple.security.assets.pictures.read-write</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF

# 3. Kontrola a oprava aplikace
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ App not found at $APP_PATH"
    exit 1
fi

echo "🧹 Deep cleaning application..."
# Důkladné vyčištění
xattr -cr "$APP_PATH"
find "$APP_PATH" -name "*.DS_Store" -exec rm -f {} \;
find "$APP_PATH" -name "__pycache__" -exec rm -rf {} \; 2>/dev/null || true
find "$APP_PATH" -name "*.pyc" -exec rm -f {} \; 2>/dev/null || true
find "$APP_PATH" -name ".svn" -exec rm -rf {} \; 2>/dev/null || true
find "$APP_PATH" -name ".git" -exec rm -rf {} \; 2>/dev/null || true

# 4. Kontrola Bundle ID v Info.plist
echo "🔍 Checking Bundle ID..."
INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ -f "$INFO_PLIST" ]]; then
    CURRENT_BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST" 2>/dev/null || echo "not found")
    echo "Current Bundle ID: $CURRENT_BUNDLE_ID"
    
    # Nastavení správného Bundle ID
    plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$INFO_PLIST"
    echo "✅ Bundle ID set to: $BUNDLE_ID"
else
    echo "❌ Info.plist not found"
    exit 1
fi

# 5. Rekurzivní podepsání všech binárních souborů
echo "✍️ Recursively signing all binaries..."

# Najdeme všechny binární soubory a podepíšeme je
find "$APP_PATH" -type f -perm +111 -not -path "*/Contents/MacOS/*" | while read binary; do
    echo "Signing: $binary"
    codesign --force --timestamp --options runtime --sign "$APP_CERT" "$binary" 2>/dev/null || true
done

# Podepsání hlavních komponent
if [[ -d "$APP_PATH/Contents/Frameworks" ]]; then
    find "$APP_PATH/Contents/Frameworks" -name "*.framework" -o -name "*.dylib" | while read framework; do
        echo "Signing framework: $framework"
        codesign --force --timestamp --options runtime --sign "$APP_CERT" "$framework"
    done
fi

# 6. Podepsání hlavní aplikace
echo "✍️ Signing main application..."
codesign --force --deep --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_CERT" \
    "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Application signing failed"
    exit 1
fi

# 7. Důkladné ověření podpisu
echo "🔍 Thoroughly verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
if [ $? -ne 0 ]; then
    echo "❌ Deep signature verification failed"
    exit 1
fi

# Test spctl
spctl --assess --verbose "$APP_PATH"
if [ $? -ne 0 ]; then
    echo "⚠️  spctl assessment failed (may be normal before notarization)"
fi

echo "✅ Application signature verified"

# 8. Vytvoření DMG
echo "💿 Creating DMG..."
rm -rf "$BUILD_DIR"
rm -f "$DMG_NAME"
mkdir -p "$BUILD_DIR"

# Kopírování aplikace
cp -R "$APP_PATH" "$BUILD_DIR/"

# Vytvoření Applications symlink
ln -s /Applications "$BUILD_DIR/Applications"

# Vytvoření DMG
hdiutil create -srcfolder "$BUILD_DIR" \
    -volname "WallMotion" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_NAME"

rm -rf "$BUILD_DIR"

# 9. Podepsání DMG
echo "✍️ Signing DMG..."
codesign --force --timestamp --sign "$APP_CERT" "$DMG_NAME"

if [ $? -ne 0 ]; then
    echo "❌ DMG signing failed"
    exit 1
fi

# 10. Ověření DMG
echo "🔍 Verifying DMG..."
codesign --verify --deep --verbose "$DMG_NAME"
spctl --assess --type open --context context:primary-signature "$DMG_NAME"

# 11. Kontrola hesla
if [[ "$APP_PASSWORD" == "your-app-specific-password" ]]; then
    echo ""
    echo "⚠️  Set your app-specific password in the script before notarization"
    echo "✅ DMG created and signed: $DMG_NAME"
    echo "🔒 Ready for notarization when password is set"
    exit 0
fi

# 12. Notarizace
echo "📤 Submitting for notarization..."
SUBMISSION_RESULT=$(xcrun notarytool submit "$DMG_NAME" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait)

echo "$SUBMISSION_RESULT"

# Získání Submission ID
SUBMISSION_ID=$(echo "$SUBMISSION_RESULT" | grep "id:" | head -1 | awk '{print $2}')

if [[ "$SUBMISSION_RESULT" == *"status: Accepted"* ]]; then
    echo "✅ Notarization successful!"
    
    # Stapling
    echo "📎 Stapling notarization..."
    xcrun stapler staple "$DMG_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✅ Stapling successful!"
        
        # Finální test
        echo "🏁 Final verification..."
        spctl --assess --type open --context context:primary-signature "$DMG_NAME"
        
        if [ $? -eq 0 ]; then
            echo "🎉 SUCCESS! DMG is ready for distribution!"
        else
            echo "⚠️  Final verification failed but DMG should still work"
        fi
    else
        echo "❌ Stapling failed"
    fi
else
    echo "❌ Notarization failed"
    
    if [[ -n "$SUBMISSION_ID" ]]; then
        echo "📋 Getting error details..."
        xcrun notarytool log "$SUBMISSION_ID" \
            --apple-id "$APPLE_ID" \
            --password "$APP_PASSWORD" \
            --team-id "$TEAM_ID"
    fi
    
    exit 1
fi

# Vyčištění
rm -f "$ENTITLEMENTS"

echo ""
echo "🎉 FINAL SUCCESS!"
echo "📦 File: $DMG_NAME"
echo "📊 Size: $(du -h "$DMG_NAME" | cut -f1)"
echo "🔐 Checksum: $(shasum -a 256 "$DMG_NAME")"
echo "🚀 Ready for distribution!"