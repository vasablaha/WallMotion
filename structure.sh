#!/bin/bash
# Enhanced structure.sh s diagnostikou

echo "🔧 Setting up bundled executables for WallMotion..."

# Vytvoř directory structure
echo "📁 Creating directory structure..."
mkdir -p WallMotion/Resources/Executables

# Debug: Check current directory
echo "📍 Current directory: $(pwd)"
echo "📍 Listing current structure:"
ls -la WallMotion/Resources/ 2>/dev/null || echo "Resources directory doesn't exist yet"

# Download yt-dlp pro macOS (Universal Binary)  
echo "📺 Downloading yt-dlp..."
if curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o WallMotion/Resources/yt-dlp; then
    echo "✅ yt-dlp downloaded successfully"
    
    # Set executable permissions
    chmod +x WallMotion/Resources/yt-dlp
    echo "✅ yt-dlp made executable"
    
    # Verify download
    ls -la WallMotion/Resources/yt-dlp
else
    echo "❌ Failed to download yt-dlp"
    exit 1
fi

# Copy ffmpeg from Homebrew (if exists)
echo "🎬 Copying ffmpeg from Homebrew..."
FFMPEG_PATHS=(
    "/opt/homebrew/bin/ffmpeg"
    "/usr/local/bin/ffmpeg"
)

FFPROBE_PATHS=(
    "/opt/homebrew/bin/ffprobe"
    "/usr/local/bin/ffprobe"
)

# Find and copy ffmpeg
for path in "${FFMPEG_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        echo "📍 Found ffmpeg at: $path"
        cp "$path" WallMotion/Resources/ffmpeg
        chmod +x WallMotion/Resources/ffmpeg
        echo "✅ ffmpeg copied and made executable"
        break
    fi
done

# Find and copy ffprobe  
for path in "${FFPROBE_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        echo "📍 Found ffprobe at: $path"
        cp "$path" WallMotion/Resources/ffprobe
        chmod +x WallMotion/Resources/ffprobe
        echo "✅ ffprobe copied and made executable"
        break
    fi
done

# Final verification
echo ""
echo "🔍 Final verification:"
echo "===================="

for tool in yt-dlp ffmpeg ffprobe; do
    tool_path="WallMotion/Resources/$tool"
    if [[ -f "$tool_path" ]]; then
        size=$(ls -lh "$tool_path" | awk '{print $5}')
        perms=$(ls -l "$tool_path" | awk '{print $1}')
        echo "✅ $tool: $size, permissions: $perms"
        
        # Test executability
        if [[ -x "$tool_path" ]]; then
            echo "   🔧 Executable: ✅"
        else
            echo "   🔧 Executable: ❌"
        fi
    else
        echo "❌ $tool: Not found"
    fi
done

echo ""
echo "📁 Complete bundle structure:"
ls -la WallMotion/Resources/

echo ""
echo "🎉 Setup complete! Now build your app."
echo "💡 Remember to run this script before each build if you update the tools."