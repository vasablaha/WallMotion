#!/bin/bash
# 🔧 Update bundled yt-dlp to fix PyInstaller runtime issues

echo "🔧 Updating bundled yt-dlp to latest working version..."

# Create backup of current version
echo "📦 Creating backup of current yt-dlp..."
if [[ -f "WallMotion/Resources/yt-dlp" ]]; then
    cp "WallMotion/Resources/yt-dlp" "WallMotion/Resources/yt-dlp.backup"
    echo "✅ Backup created: yt-dlp.backup"
fi

# ✅ ŘEŠENÍ 1: Novější stabilní verze (2024.08.06)
echo "📺 Downloading newer stable yt-dlp (2024.08.06)..."
YT_DLP_URL="https://github.com/yt-dlp/yt-dlp/releases/download/2024.08.06/yt-dlp_macos"

if curl -L "$YT_DLP_URL" -o "WallMotion/Resources/yt-dlp.new"; then
    echo "✅ Downloaded new yt-dlp"
    
    # Set permissions
    chmod +x "WallMotion/Resources/yt-dlp.new"
    
    # Remove quarantine
    xattr -d com.apple.quarantine "WallMotion/Resources/yt-dlp.new" 2>/dev/null || true
    xattr -c "WallMotion/Resources/yt-dlp.new" 2>/dev/null || true
    
    # Test new version
    echo "🧪 Testing new yt-dlp version..."
    if ./WallMotion/Resources/yt-dlp.new --version 2>/dev/null; then
        # Replace old with new
        mv "WallMotion/Resources/yt-dlp.new" "WallMotion/Resources/yt-dlp"
        echo "✅ yt-dlp updated successfully!"
        
        # Verify
        echo "📋 New version info:"
        ./WallMotion/Resources/yt-dlp --version
        
    else
        echo "❌ New version failed test, trying alternative..."
        rm -f "WallMotion/Resources/yt-dlp.new"
        
        # ✅ ŘEŠENÍ 2: Zkus ještě novější verzi (2024.12.06)
        echo "📺 Trying even newer version (2024.12.06)..."
        YT_DLP_URL_ALT="https://github.com/yt-dlp/yt-dlp/releases/download/2024.12.06/yt-dlp_macos"
        
        if curl -L "$YT_DLP_URL_ALT" -o "WallMotion/Resources/yt-dlp.alt"; then
            chmod +x "WallMotion/Resources/yt-dlp.alt"
            xattr -d com.apple.quarantine "WallMotion/Resources/yt-dlp.alt" 2>/dev/null || true
            xattr -c "WallMotion/Resources/yt-dlp.alt" 2>/dev/null || true
            
            echo "🧪 Testing alternative version..."
            if ./WallMotion/Resources/yt-dlp.alt --version 2>/dev/null; then
                mv "WallMotion/Resources/yt-dlp.alt" "WallMotion/Resources/yt-dlp"
                echo "✅ Alternative version working!"
                ./WallMotion/Resources/yt-dlp --version
            else
                echo "❌ Alternative version also failed"
                rm -f "WallMotion/Resources/yt-dlp.alt"
                
                # ✅ ŘEŠENÍ 3: Native build bez PyInstaller
                echo "🔧 Trying native build without PyInstaller..."
                try_native_build
            fi
        else
            echo "❌ Failed to download alternative version"
            try_native_build
        fi
    fi
else
    echo "❌ Failed to download new yt-dlp"
    try_native_build
fi

function try_native_build() {
    echo "🔧 Attempting to get native yt-dlp build..."
    
    # Zkus získat z různých zdrojů
    NATIVE_SOURCES=(
        "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
        "https://github.com/yt-dlp/yt-dlp/releases/download/2024.11.18/yt-dlp_macos"
        "https://github.com/yt-dlp/yt-dlp/releases/download/2024.10.07/yt-dlp_macos"
    )
    
    for source in "${NATIVE_SOURCES[@]}"; do
        echo "🔄 Trying: $source"
        
        if curl -L "$source" -o "WallMotion/Resources/yt-dlp.native"; then
            chmod +x "WallMotion/Resources/yt-dlp.native"
            xattr -d com.apple.quarantine "WallMotion/Resources/yt-dlp.native" 2>/dev/null || true
            xattr -c "WallMotion/Resources/yt-dlp.native" 2>/dev/null || true
            
            echo "🧪 Testing: $source"
            if ./WallMotion/Resources/yt-dlp.native --version 2>/dev/null; then
                mv "WallMotion/Resources/yt-dlp.native" "WallMotion/Resources/yt-dlp"
                echo "✅ Native build working from: $source"
                ./WallMotion/Resources/yt-dlp --version
                return 0
            else
                echo "❌ Failed: $source"
                rm -f "WallMotion/Resources/yt-dlp.native"
            fi
        fi
    done
    
    echo "❌ All native builds failed, restoring backup..."
    if [[ -f "WallMotion/Resources/yt-dlp.backup" ]]; then
        mv "WallMotion/Resources/yt-dlp.backup" "WallMotion/Resources/yt-dlp"
        echo "✅ Backup restored"
    fi
    
    return 1
}

# Final verification
echo ""
echo "📊 Final Status:"
echo "==============="

if [[ -f "WallMotion/Resources/yt-dlp" ]]; then
    echo "📁 File exists: ✅"
    echo "📏 File size: $(stat -f%z WallMotion/Resources/yt-dlp) bytes"
    echo "🔒 Permissions: $(stat -f%Mp%Lp WallMotion/Resources/yt-dlp)"
    
    echo "🧪 Version test:"
    if ./WallMotion/Resources/yt-dlp --version 2>/dev/null; then
        echo "✅ yt-dlp is working!"
        
        # Test with real URL
        echo ""
        echo "🌐 Testing with real YouTube URL..."
        if ./WallMotion/Resources/yt-dlp --print "%(title)s" --no-download --no-warnings "https://www.youtube.com/watch?v=dQw4w9WgXcQ" 2>/dev/null | head -1; then
            echo "✅ YouTube access working!"
        else
            echo "⚠️ YouTube access may be limited (but tool is working)"
        fi
        
    else
        echo "❌ yt-dlp still not working"
        echo ""
        echo "🔍 Error details:"
        ./WallMotion/Resources/yt-dlp --version 2>&1 | head -10
        
        echo ""
        echo "🔧 Possible solutions:"
        echo "1. Try manually downloading latest yt-dlp from GitHub releases"
        echo "2. Check macOS version compatibility"
        echo "3. Verify Xcode command line tools are installed"
    fi
else
    echo "❌ yt-dlp file missing!"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Build the application in Xcode"
echo "2. Test YouTube import functionality"
echo "3. Create new DMG with updated yt-dlp"