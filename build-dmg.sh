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
VIDEOSAVER_ENTITLEMENTS="videosaver-entitlements.plist"
BUILD_DIR="dmg-temp"
YT_DLP_ENTITLEMENTS="ytdlp-entitlements.plist"

echo "🔐 Starting notarization with VideoSaver fix..."

# 1. Najdeme certifikáty
echo "🔍 Finding certificates..."
APP_CERT=$(security find-identity -v -p codesigning | grep -i "developer id application" | head -1 | awk '{print $2}')

if [[ -z "$APP_CERT" ]]; then
    echo "❌ No Developer ID Application certificate found"
    exit 1
fi

echo "✅ Using certificate: $APP_CERT"

# 2. Vytvoření entitlements pro hlavní aplikaci
echo "📝 Creating main app entitlements..."
cat > "$ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.assets.movies.read-write</key>
    <true/>
    <key>com.apple.security.assets.pictures.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.inherit</key>
    <true/>
    <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
    <array>
        <string>/opt/homebrew/</string>
        <string>/usr/local/</string>
        <string>/Library/Application Support/com.apple.idleassetsd/</string>
        <string>/private/tmp/</string>
        <string>/tmp/</string>
        <string>/var/folders/</string>
    </array>
    <key>com.apple.security.cs.allow-relative-library-loads</key>
    <true/>
    <key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
    <array>
        <string>/opt/homebrew/</string>
        <string>/usr/local/</string>
        <string>/usr/bin/</string>
        <string>/bin/</string>
    </array>
    <key>com.apple.security.temporary-exception.sbpl</key>
    <string>(allow process-exec (literal "/usr/bin/xattr"))</string>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
    <array>
        <string>com.apple.system.opendirectoryd.libinfo</string>
        <string>com.apple.system.logger</string>
        <string>com.apple.system.notification_center</string>
    </array>
    <key>com.apple.security.temporary-exception.shared-preference.read-write</key>
    <array>
        <string>com.apple.Terminal</string>
        <string>com.apple.desktop</string>
        <string>com.apple.security</string>
    </array>
    <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
    <array>
        <string>Library/Application Support/com.apple.idleassetsd/</string>
        <string>Library/Containers/com.apple.desktop.admin.png/</string>
        <string>Library/Caches/</string>
        <string>.cache/</string>
    </array>
    <key>com.apple.security.temporary-exception.apple-events</key>
    <array>
        <string>com.apple.terminal</string>
        <string>com.apple.systemevents</string>
        <string>com.apple.finder</string>
    </array>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
</dict>
</plist>
EOF

# 3. Vytvoření entitlements pro yt-dlp (PyInstaller support)
echo "📝 Creating yt-dlp PyInstaller entitlements..."
YT_DLP_ENTITLEMENTS="ytdlp-entitlements.plist"
cat > "$YT_DLP_ENTITLEMENTS" << 'EOF'
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

# 4. Vytvoření entitlements pro VideoSaver (BEZ debug entitlements)
echo "📝 Creating VideoSaver entitlements..."
cat > "$VIDEOSAVER_ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
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
</dict>
</plist>
EOF

# 5. Kontrola aplikace
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ App not found at $APP_PATH"
    exit 1
fi

# 6. Podepsání bundled CLI executables s rozlišením pro yt-dlp
echo "✍️ Signing bundled CLI executables..."
RESOURCES_PATH="$APP_PATH/Contents/Resources"

# Seznam CLI tools k podepsání
CLI_TOOLS=("yt-dlp" "ffmpeg" "ffprobe")

for tool in "${CLI_TOOLS[@]}"; do
    # Zkus najít tool v různých lokacích
    TOOL_PATHS=(
        "$RESOURCES_PATH/$tool"
        "$RESOURCES_PATH/Executables/$tool"
        "$RESOURCES_PATH/bin/$tool"
        "$RESOURCES_PATH/tools/$tool"
    )
    
    for tool_path in "${TOOL_PATHS[@]}"; do
        if [[ -f "$tool_path" ]]; then
            echo "🔧 Found $tool at: $tool_path"
            
            # Smaž quarantine flag
            xattr -d com.apple.quarantine "$tool_path" 2>/dev/null || true
            xattr -c "$tool_path" 2>/dev/null || true
            
            # Nastav executable permissions
            chmod +x "$tool_path"
            
            # Smaž starý podpis
            codesign --remove-signature "$tool_path" 2>/dev/null || true
            
            # 🔧 SPECIÁLNÍ HANDLING PRO YT-DLP (PyInstaller) s detailním logováním
            if [[ "$tool" == "yt-dlp" ]]; then
                echo "🐍 Signing yt-dlp with PyInstaller entitlements..."
                
                # Debug: Zobraz obsah entitlements před podepsáním
                echo "📋 yt-dlp entitlements file content:"
                echo "======================================"
                cat "$YT_DLP_ENTITLEMENTS"
                echo "=====================================."
                
                # Debug: Zkontroluj, že entitlements soubor existuje
                echo "🔍 Entitlements file check:"
                ls -la "$YT_DLP_ENTITLEMENTS"
                
                # Podepsání s detailním výstupem
                echo "✍️ Executing codesign command:"
                echo "codesign --force --timestamp --options runtime --entitlements \"$YT_DLP_ENTITLEMENTS\" --sign \"$APP_CERT\" \"$tool_path\""
                
                codesign --force --timestamp --options runtime \
                    --entitlements "$YT_DLP_ENTITLEMENTS" \
                    --sign "$APP_CERT" \
                    "$tool_path"
                    
                signing_result=$?
                
                if [ $signing_result -eq 0 ]; then
                    echo "✅ yt-dlp signed successfully with PyInstaller support"
                    
                    # Ověř podpis s detailním výstupem
                    echo "🔍 Detailed signature verification:"
                    codesign --verify --deep --strict --verbose=4 "$tool_path" 2>&1
                    
                    # KLÍČOVÉ: Zobraz skutečné entitlements po podepsání
                    echo ""
                    echo "🎯 ACTUAL yt-dlp entitlements after signing:"
                    echo "=============================================="
                    codesign --display --entitlements - "$tool_path" 2>/dev/null || echo "❌ Failed to read entitlements"
                    echo "=============================================="
                    
                    # Specificky zkontroluj klíčové PyInstaller entitlements
                    echo ""
                    echo "🔑 Key PyInstaller entitlements check:"
                    entitlements_output=$(codesign --display --entitlements - "$tool_path" 2>/dev/null)
                    
                    if [[ "$entitlements_output" == *"disable-library-validation"* ]]; then
                        echo "✅ disable-library-validation: FOUND"
                    else
                        echo "❌ disable-library-validation: MISSING"
                    fi
                    
                    if [[ "$entitlements_output" == *"allow-jit"* ]]; then
                        echo "✅ allow-jit: FOUND"
                    else
                        echo "❌ allow-jit: MISSING"
                    fi
                    
                    if [[ "$entitlements_output" == *"allow-unsigned-executable-memory"* ]]; then
                        echo "✅ allow-unsigned-executable-memory: FOUND"
                    else
                        echo "❌ allow-unsigned-executable-memory: MISSING"
                    fi
                    
                    # Test funkčnosti s PyInstaller environment
                    echo ""
                    echo "🧪 Testing yt-dlp with PyInstaller environment..."
                    export TMPDIR="/tmp"
                    export PYINSTALLER_SEMAPHORE="0"
                    export PYI_DISABLE_SEMAPHORE="1"
                    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY="YES"
                    
                    # Detailní test s timeout
                    echo "🚀 Running: timeout 10s \"$tool_path\" --version"
                    test_result=$(timeout 10s "$tool_path" --version 2>&1)
                    test_exit_code=$?
                    
                    echo "📊 Test results:"
                    echo "   Exit code: $test_exit_code"
                    echo "   Output: $test_result"
                    
                    if [[ $test_exit_code -eq 0 && ! "$test_result" == *"Failed to load Python"* ]]; then
                        echo "✅ yt-dlp PyInstaller test passed: $test_result"
                    else
                        echo "❌ yt-dlp PyInstaller test failed!"
                        echo "🔍 Full error output:"
                        echo "$test_result"
                        
                        # Additional diagnostics
                        echo ""
                        echo "🔧 Additional diagnostics:"
                        echo "   File permissions: $(ls -la "$tool_path")"
                        echo "   File type: $(file "$tool_path")"
                        echo "   Code signature status: $(codesign --verify "$tool_path" 2>&1 || echo "Verification failed")"
                    fi
                    
                else
                    echo "❌ yt-dlp signing failed with exit code: $signing_result"
                    
                    # Debug why signing failed
                    echo "🔍 Signing failure diagnostics:"
                    echo "   Certificate: $APP_CERT"
                    echo "   Tool path: $tool_path"
                    echo "   Entitlements file: $YT_DLP_ENTITLEMENTS"
                    echo "   Entitlements file exists: $(test -f "$YT_DLP_ENTITLEMENTS" && echo "YES" || echo "NO")"
                    
                    exit 1
                fi
                
            else
                # Standardní podepsání pro ffmpeg a ffprobe (beze změny)
                echo "✍️ Signing $tool with standard entitlements..."
                codesign --force --timestamp --options runtime \
                    --sign "$APP_CERT" \
                    "$tool_path"
                
                if [ $? -eq 0 ]; then
                    echo "✅ $tool signed successfully"
                    
                    # Ověř podpis
                    codesign --verify --verbose "$tool_path"
                else
                    echo "❌ $tool signing failed"
                    exit 1
                fi
            fi
                    
                if [ $? -eq 0 ]; then
                    echo "✅ yt-dlp signed successfully with PyInstaller support"
                    
                    # Ověř podpis
                    codesign --verify --verbose "$tool_path"
                    
                    # Test funkčnosti s PyInstaller environment
                    echo "🧪 Testing yt-dlp with PyInstaller environment..."
                    export TMPDIR="/tmp"
                    export PYINSTALLER_SEMAPHORE="0"
                    export PYI_DISABLE_SEMAPHORE="1"
                    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY="YES"
                    
                    test_result=$("$tool_path" --version 2>&1 | head -1)
                    if [[ ! "$test_result" == *"Failed to load Python"* ]]; then
                        echo "✅ yt-dlp PyInstaller test passed: $test_result"
                    else
                        echo "⚠️  yt-dlp might still have PyInstaller issues, but signed correctly"
                    fi
                else
                    echo "❌ yt-dlp signing failed"
                    exit 1
                fi
            else
                # Standardní podepsání pro ffmpeg a ffprobe
                echo "✍️ Signing $tool with standard entitlements..."
                codesign --force --timestamp --options runtime \
                    --sign "$APP_CERT" \
                    "$tool_path"
                
                if [ $? -eq 0 ]; then
                    echo "✅ $tool signed successfully"
                    
                    # Ověř podpis
                    codesign --verify --verbose "$tool_path"
                else
                    echo "❌ $tool signing failed"
                    exit 1
                fi
            fi
            
            break # Našli jsme tool, přejdi na další
        fi
    done
done

echo "✅ All CLI tools processed"

# Zbytek scriptu pokračuje normálně...
echo "🧹 Deep cleaning application..."
xattr -cr "$APP_PATH"
find "$APP_PATH" -name "*.DS_Store" -exec rm -f {} \;
find "$APP_PATH" -name "__pycache__" -exec rm -rf {} \; 2>/dev/null || true
find "$APP_PATH" -name "*.pyc" -exec rm -f {} \; 2>/dev/null || true

# 5. Speciální oprava VideoSaver
VIDEOSAVER_PATH="$APP_PATH/Contents/Resources/VideoSaver"
if [[ -f "$VIDEOSAVER_PATH" ]]; then
    echo "🔧 Fixing VideoSaver binary..."
    
    # Smazání starého podpisu
    codesign --remove-signature "$VIDEOSAVER_PATH" 2>/dev/null || true
    
    # Nové podepsání s produkčními entitlements
    echo "✍️ Signing VideoSaver with production entitlements..."
    codesign --force --timestamp --options runtime \
        --entitlements "$VIDEOSAVER_ENTITLEMENTS" \
        --sign "$APP_CERT" \
        "$VIDEOSAVER_PATH"
    
    if [ $? -eq 0 ]; then
        echo "✅ VideoSaver signed successfully"
        
        # Ověření podpisu
        codesign --verify --verbose "$VIDEOSAVER_PATH"
        
        # Kontrola entitlements
        echo "🔍 Checking VideoSaver entitlements..."
        codesign --display --entitlements - "$VIDEOSAVER_PATH"
    else
        echo "❌ VideoSaver signing failed"
        exit 1
    fi
else
    echo "⚠️  VideoSaver not found at $VIDEOSAVER_PATH"
fi

# 6. Podepsání všech ostatních binárních souborů
echo "✍️ Signing all other binaries..."
find "$APP_PATH" -type f -perm +111 -not -path "*VideoSaver*" -not -path "*/Contents/MacOS/*" | while read binary; do
    echo "Signing: $binary"
    codesign --force --timestamp --options runtime --sign "$APP_CERT" "$binary" 2>/dev/null || true
done

# Podepsání frameworks
if [[ -d "$APP_PATH/Contents/Frameworks" ]]; then
    find "$APP_PATH/Contents/Frameworks" -name "*.framework" -o -name "*.dylib" | while read framework; do
        echo "Signing framework: $framework"
        codesign --force --timestamp --options runtime --sign "$APP_CERT" "$framework"
    done
fi

# 7. Podepsání hlavní aplikace
echo "✍️ Signing main application..."
codesign --force --deep --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_CERT" \
    "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Main application signing failed"
    exit 1
fi

# 8. Důkladné ověření
echo "🔍 Verifying all signatures..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ All signatures verified"
else
    echo "❌ Signature verification failed"
    exit 1
fi

# 9. Kontrola konkrétně VideoSaver
if [[ -f "$VIDEOSAVER_PATH" ]]; then
    echo "🔍 Final VideoSaver verification..."
    codesign --verify --verbose "$VIDEOSAVER_PATH"
    
    # Kontrola, že nemá debug entitlements
    ENTITLEMENTS_CHECK=$(codesign --display --entitlements - "$VIDEOSAVER_PATH" 2>/dev/null | grep "get-task-allow" || echo "not found")
    if [[ "$ENTITLEMENTS_CHECK" == "not found" ]]; then
        echo "✅ VideoSaver has no debug entitlements"
    else
        echo "❌ VideoSaver still has debug entitlements"
        exit 1
    fi
fi

# 10. Vytvoření DMG
echo "💿 Creating DMG..."
rm -rf "$BUILD_DIR"
rm -f "$DMG_NAME"
mkdir -p "$BUILD_DIR"

cp -R "$APP_PATH" "$BUILD_DIR/"
ln -s /Applications "$BUILD_DIR/Applications"

hdiutil create -srcfolder "$BUILD_DIR" \
    -volname "WallMotion" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_NAME"

rm -rf "$BUILD_DIR"

# 11. Podepsání DMG
echo "✍️ Signing DMG..."
codesign --force --timestamp --sign "$APP_CERT" "$DMG_NAME"

if [ $? -ne 0 ]; then
    echo "❌ DMG signing failed"
    exit 1
fi

echo "✅ DMG signed successfully"

# 12. Kontrola hesla
if [[ "$APP_PASSWORD" == "your-app-specific-password" ]]; then
    echo ""
    echo "⚠️  Set your app-specific password in the script"
    echo "✅ DMG ready for notarization: $DMG_NAME"
    echo "📋 VideoSaver issues should now be fixed"
    exit 0
fi

# 13. Notarizace
echo "📤 Submitting for notarization..."
SUBMISSION_RESULT=$(xcrun notarytool submit "$DMG_NAME" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait)

echo "$SUBMISSION_RESULT"

SUBMISSION_ID=$(echo "$SUBMISSION_RESULT" | grep "id:" | head -1 | awk '{print $2}')

if [[ "$SUBMISSION_RESULT" == *"status: Accepted"* ]]; then
    echo "✅ Notarization successful!"
    
    # Stapling
    xcrun stapler staple "$DMG_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✅ Stapling successful!"
        
        # Finální test
        spctl --assess --type open --context context:primary-signature "$DMG_NAME"
        
        if [ $? -eq 0 ]; then
            echo "🎉 SUCCESS! DMG is ready for distribution!"
        else
            echo "⚠️  Final verification warning (but should still work)"
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
fi

# Vyčištění
rm -f "$ENTITLEMENTS" "$VIDEOSAVER_ENTITLEMENTS" "$YT_DLP_ENTITLEMENTS"

echo ""
echo "📦 File: $DMG_NAME"
echo "📊 Size: $(du -h "$DMG_NAME" | cut -f1)"
echo "🔐 Checksum: $(shasum -a 256 "$DMG_NAME")"

if [[ "$SUBMISSION_RESULT" == *"status: Accepted"* ]]; then
    echo "🎉 READY FOR DISTRIBUTION!"
else
    echo "❌ Fix issues and try again"
fi
