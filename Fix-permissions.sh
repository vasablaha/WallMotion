#!/bin/bash

echo "🔧 Fixing yt-dlp PyInstaller Signature Issue"
echo "============================================"

# Cesty
YT_DLP_PATH="/Applications/WallMotion.app/Contents/Resources/yt-dlp"

# 1. Najdi Developer ID certifikát
echo "🔍 Finding Developer ID certificate..."
APP_CERT=$(security find-identity -v -p codesigning | grep -i "developer id application" | head -1 | awk '{print $2}')

if [[ -z "$APP_CERT" ]]; then
    echo "❌ No Developer ID Application certificate found"
    echo "💡 You need a valid Apple Developer certificate to fix this"
    exit 1
fi

echo "✅ Using certificate: $APP_CERT"

# 2. Kontrola existence yt-dlp
if [[ ! -f "$YT_DLP_PATH" ]]; then
    echo "❌ yt-dlp not found at: $YT_DLP_PATH"
    exit 1
fi

echo "✅ yt-dlp found at: $YT_DLP_PATH"

# 3. Vytvoř PyInstaller entitlements
echo "📝 Creating PyInstaller entitlements..."
ENTITLEMENTS_FILE="/tmp/ytdlp_entitlements.plist"

cat > "$ENTITLEMENTS_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- KLÍČOVÉ: PyInstaller support -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-relative-library-loads</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    
    <!-- Základní permissions -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    
    <!-- Temp directory access pro PyInstaller -->
    <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
    <array>
        <string>/private/tmp/</string>
        <string>/tmp/</string>
        <string>/var/folders/</string>
    </array>
</dict>
</plist>
EOF

echo "✅ Entitlements created"

# 4. Backup původního souboru
echo "💾 Creating backup..."
cp "$YT_DLP_PATH" "${YT_DLP_PATH}.backup"
echo "✅ Backup created: ${YT_DLP_PATH}.backup"

# 5. Vyčisti extended attributes
echo "🧹 Cleaning extended attributes..."
xattr -cr "$YT_DLP_PATH"

# 6. Smaž starý podpis
echo "🗑️ Removing old signature..."
codesign --remove-signature "$YT_DLP_PATH" 2>/dev/null || true

# 7. Podepři s PyInstaller entitlements
echo "✍️ Signing yt-dlp with PyInstaller support..."
codesign --force --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS_FILE" \
    --sign "$APP_CERT" \
    "$YT_DLP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ yt-dlp signed successfully!"
else
    echo "❌ Signing failed!"
    echo "🔄 Restoring backup..."
    mv "${YT_DLP_PATH}.backup" "$YT_DLP_PATH"
    rm -f "$ENTITLEMENTS_FILE"
    exit 1
fi

# 8. Ověř podpis
echo "🔍 Verifying signature..."
codesign --verify --verbose "$YT_DLP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Signature verification successful!"
else
    echo "❌ Signature verification failed!"
    echo "🔄 Restoring backup..."
    mv "${YT_DLP_PATH}.backup" "$YT_DLP_PATH"
    rm -f "$ENTITLEMENTS_FILE"
    exit 1
fi

# 9. Test funkčnosti
echo "🧪 Testing yt-dlp functionality..."

# Nastav PyInstaller environment variables
export TMPDIR="/tmp"
export TEMP="/tmp"
export TMP="/tmp"
export PYINSTALLER_SEMAPHORE="0"
export PYI_DISABLE_SEMAPHORE="1"
export _PYI_SPLASH_IPC="0"
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY="YES"

# Test version
test_result=$("$YT_DLP_PATH" --version 2>&1)
exit_code=$?

if [[ $exit_code -eq 0 && ! "$test_result" == *"Failed to load Python"* ]]; then
    echo "✅ yt-dlp test successful!"
    echo "📋 Version: $test_result"
    
    # Vyčištění
    rm -f "${YT_DLP_PATH}.backup"
    rm -f "$ENTITLEMENTS_FILE"
    
    echo ""
    echo "🎉 SUCCESS! yt-dlp should now work in WallMotion"
    echo "💡 Restart WallMotion - Missing Dependencies error should be gone"
    
else
    echo "❌ yt-dlp test failed!"
    echo "🔍 Error output: $test_result"
    echo "🔄 Restoring backup..."
    mv "${YT_DLP_PATH}.backup" "$YT_DLP_PATH"
    rm -f "$ENTITLEMENTS_FILE"
    exit 1
fi

echo ""
echo "🔄 Next steps:"
echo "1. Close WallMotion if it's running"
echo "2. Restart WallMotion"
echo "3. Try importing a YouTube video"