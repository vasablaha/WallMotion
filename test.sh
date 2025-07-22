#!/bin/bash
# Test script pro ověření bundled tools

echo "🧪 Testing bundled tools before build..."

TOOLS_DIR="WallMotion/Resources"

test_tool() {
    local tool=$1
    local path="${TOOLS_DIR}/${tool}"
    
    echo ""
    echo "🔧 Testing $tool:"
    echo "=================="
    
    if [[ ! -f "$path" ]]; then
        echo "❌ $tool not found at $path"
        return 1
    fi
    
    # Check size
    local size=$(ls -lh "$path" | awk '{print $5}')
    echo "📊 Size: $size"
    
    # Check permissions
    local perms=$(ls -l "$path" | awk '{print $1}')
    echo "🔒 Permissions: $perms"
    
    # Check executable bit
    if [[ -x "$path" ]]; then
        echo "✅ Executable: Yes"
    else
        echo "❌ Executable: No"
        chmod +x "$path"
        echo "🔧 Fixed permissions"
    fi
    
    # Check quarantine
    if xattr -l "$path" 2>/dev/null | grep -q "com.apple.quarantine"; then
        echo "⚠️  Quarantine: Present (removing...)"
        xattr -d com.apple.quarantine "$path" 2>/dev/null || true
        xattr -c "$path" 2>/dev/null || true
        echo "✅ Quarantine: Removed"
    else
        echo "✅ Quarantine: Clear"
    fi
    
    # Check dependencies (macOS only)
    if command -v otool &> /dev/null; then
        echo "📋 Dependencies:"
        local external_deps=$(otool -L "$path" 2>/dev/null | grep -v "$path" | grep -v "/usr/lib" | grep -v "/System" | grep -v "@")
        
        if [[ -z "$external_deps" ]]; then
            echo "   ✅ No external dependencies (static or system only)"
        else
            echo "   ⚠️  External dependencies found:"
            echo "$external_deps" | while read line; do
                echo "     $line"
            done
        fi
    fi
    
    # Functional test
    echo "🧪 Functional test:"
    case $tool in
        "yt-dlp")
            if timeout 10 "$path" --version >/dev/null 2>&1; then
                echo "   ✅ Version check passed"
                local version=$("$path" --version 2>/dev/null | head -1)
                echo "   📋 Version: $version"
            else
                echo "   ❌ Version check failed"
                echo "   🔍 Error output:"
                timeout 5 "$path" --version 2>&1 | head -3 | sed 's/^/     /'
                return 1
            fi
            ;;
        "ffmpeg"|"ffprobe")
            if timeout 10 "$path" -version >/dev/null 2>&1; then
                echo "   ✅ Version check passed"
                local version=$("$path" -version 2>/dev/null | head -1)
                echo "   📋 Version: $version"
            else
                echo "   ❌ Version check failed"
                echo "   🔍 Error output:"
                timeout 5 "$path" -version 2>&1 | head -3 | sed 's/^/     /'
                return 1
            fi
            ;;
    esac
    
    echo "✅ $tool test completed"
    return 0
}

# Test all tools
overall_success=true

for tool in yt-dlp ffmpeg ffprobe; do
    if ! test_tool "$tool"; then
        overall_success=false
    fi
done

echo ""
echo "📊 Overall Test Result:"
echo "======================="

if $overall_success; then
    echo "🎉 ALL TESTS PASSED!"
    echo "✅ Tools are ready for bundling"
    echo ""
    echo "Next steps:"
    echo "1. Build the application"
    echo "2. Test YouTube import functionality"
else
    echo "❌ SOME TESTS FAILED!"
    echo "🔧 Recommended actions:"
    echo "1. Re-run structure.sh with static binaries"
    echo "2. Manually download tools from evermeet.cx"
    echo "3. Check tool compatibility with macOS version"
    echo ""
    echo "🔗 Static binary sources:"
    echo "• yt-dlp: https://github.com/yt-dlp/yt-dlp/releases"
    echo "• ffmpeg: https://evermeet.cx/ffmpeg/"
fi

echo ""
echo "📁 Current bundle structure:"
ls -la "$TOOLS_DIR/" 2>/dev/null || echo "Tools directory not found"