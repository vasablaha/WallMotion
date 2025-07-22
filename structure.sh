#!/bin/bash
# Enhanced structure.sh with statically linked tools

echo "🔧 Setting up statically linked executables for WallMotion..."

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p WallMotion/Resources

# Debug: Check current directory
echo "📍 Current directory: $(pwd)"

# 1. Download statically linked yt-dlp (older stable version)
echo "📺 Downloading statically linked yt-dlp..."
YT_DLP_URL="https://github.com/yt-dlp/yt-dlp/releases/download/2023.07.06/yt-dlp_macos"

if curl -L "$YT_DLP_URL" -o WallMotion/Resources/yt-dlp; then
    echo "✅ yt-dlp downloaded successfully"
    
    # Set executable permissions
    chmod +x WallMotion/Resources/yt-dlp
    echo "✅ yt-dlp made executable"
    
    # Remove quarantine
    xattr -d com.apple.quarantine WallMotion/Resources/yt-dlp 2>/dev/null || true
    xattr -c WallMotion/Resources/yt-dlp 2>/dev/null || true
    
    # Verify download
    ls -la WallMotion/Resources/yt-dlp
    
    # Quick test
    echo "🧪 Testing yt-dlp..."
    if ./WallMotion/Resources/yt-dlp --version 2>/dev/null; then
        echo "✅ yt-dlp test passed"
    else
        echo "⚠️  yt-dlp test failed, but should work in bundle"
    fi
else
    echo "❌ Failed to download yt-dlp"
    exit 1
fi

# 2. Download statically linked FFmpeg
echo "🎬 Downloading statically linked FFmpeg..."

# Try different sources for static FFmpeg
FFMPEG_URLS=(
    "https://evermeet.cx/ffmpeg/ffmpeg-6.0.zip"
    "https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip"
)

FFPROBE_URLS=(
    "https://evermeet.cx/ffmpeg/ffprobe-6.0.zip" 
    "https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip"
)

# Function to download and extract
download_and_extract() {
    local name=$1
    local url=$2
    local output_path="WallMotion/Resources/$name"
    
    echo "📥 Downloading $name from evermeet.cx..."
    
    if curl -L "$url" -o "/tmp/${name}.zip"; then
        echo "📦 Extracting $name..."
        
        if unzip -o "/tmp/${name}.zip" -d "/tmp/${name}_extracted/"; then
            # Find the binary in extracted folder
            local binary_path=$(find "/tmp/${name}_extracted/" -name "$name" -type f | head -1)
            
            if [[ -f "$binary_path" ]]; then
                cp "$binary_path" "$output_path"
                chmod +x "$output_path"
                
                # Remove quarantine
                xattr -d com.apple.quarantine "$output_path" 2>/dev/null || true
                xattr -c "$output_path" 2>/dev/null || true
                
                echo "✅ $name installed successfully"
                ls -la "$output_path"
                
                # Test
                echo "🧪 Testing $name..."
                if "$output_path" -version &>/dev/null; then
                    echo "✅ $name test passed"
                else
                    echo "⚠️  $name test failed, but should work in bundle"
                fi
                
                # Cleanup
                rm -rf "/tmp/${name}.zip" "/tmp/${name}_extracted/"
                return 0
            else
                echo "❌ $name binary not found in zip"
                return 1
            fi
        else
            echo "❌ Failed to extract $name"
            return 1
        fi
    else
        echo "❌ Failed to download $name"
        return 1
    fi
}

# Download FFmpeg
for url in "${FFMPEG_URLS[@]}"; do
    if download_and_extract "ffmpeg" "$url"; then
        break
    fi
done

# Download FFprobe
for url in "${FFPROBE_URLS[@]}"; do
    if download_and_extract "ffprobe" "$url"; then
        break
    fi
done

# Fallback: Try to use system ffmpeg if static download failed
if [[ ! -f "WallMotion/Resources/ffmpeg" ]]; then
    echo "⚠️  Static FFmpeg download failed, trying system fallback..."
    
    # Check if we can create a relocatable version
    if command -v ffmpeg &> /dev/null; then
        echo "🔍 Found system ffmpeg, but it has dynamic dependencies"
        echo "💡 Consider installing static FFmpeg manually"
        
        # For now, copy system version (will need library bundling later)
        cp "$(which ffmpeg)" WallMotion/Resources/ffmpeg 2>/dev/null || true
        cp "$(which ffprobe)" WallMotion/Resources/ffprobe 2>/dev/null || true
        
        if [[ -f "WallMotion/Resources/ffmpeg" ]]; then
            chmod +x WallMotion/Resources/ffmpeg
            chmod +x WallMotion/Resources/ffprobe
            echo "⚠️  System ffmpeg copied, may need additional setup"
        fi
    fi
fi

# Final verification
echo ""
echo "🔍 Final verification:"
echo "===================="

for tool in yt-dlp ffmpeg ffprobe; do
    tool_path="WallMotion/Resources/$tool"
    if [[ -f "$tool_path" ]]; then
        size=$(ls -lh "$tool_path" | awk '{print $5}')
        echo "✅ $tool: $size"
        
        # Check if it's static (no dynamic dependencies)
        if command -v otool &> /dev/null; then
            deps=$(otool -L "$tool_path" 2>/dev/null | grep -v "$tool_path" | grep -v "/usr/lib" | grep -v "/System" | wc -l)
            if [[ $deps -eq 0 ]]; then
                echo "   🔒 Static binary (no external dependencies)"
            else
                echo "   ⚠️  Dynamic binary ($deps external dependencies)"
                # Show dependencies for debugging
                echo "   📋 Dependencies:"
                otool -L "$tool_path" 2>/dev/null | grep -v "$tool_path" | grep -v "/usr/lib" | grep -v "/System" | head -3
            fi
        fi
    else
        echo "❌ $tool: Not found"
    fi
done

echo ""
echo "📁 Complete bundle structure:"
ls -la WallMotion/Resources/

echo ""
echo "🎉 Setup complete!"
echo "💡 If you see dynamic dependencies warnings, consider downloading"
echo "   static binaries manually from evermeet.cx or other sources."