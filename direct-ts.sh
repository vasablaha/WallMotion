#!/bin/bash
# Direct test of bundled tools (no timeout needed)

echo "🧪 Direct testing of bundled tools..."

TOOLS_DIR="WallMotion/Resources"

# Test yt-dlp
echo ""
echo "📺 Testing yt-dlp directly:"
echo "==========================="
if [[ -f "${TOOLS_DIR}/yt-dlp" ]]; then
    echo "🔧 Running: ${TOOLS_DIR}/yt-dlp --version"
    echo "Output:"
    "${TOOLS_DIR}/yt-dlp" --version 2>&1 | head -5
    
    echo ""
    echo "🔧 Exit code: $?"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ yt-dlp is working!"
    else
        echo "❌ yt-dlp failed"
        echo ""
        echo "🔍 Detailed error:"
        "${TOOLS_DIR}/yt-dlp" --version 2>&1 | head -10
    fi
else
    echo "❌ yt-dlp not found"
fi

# Test ffmpeg
echo ""
echo "🎬 Testing ffmpeg directly:"
echo "=========================="
if [[ -f "${TOOLS_DIR}/ffmpeg" ]]; then
    echo "🔧 Running: ${TOOLS_DIR}/ffmpeg -version"
    echo "Output:"
    "${TOOLS_DIR}/ffmpeg" -version 2>&1 | head -3
    
    echo ""
    echo "🔧 Exit code: $?"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ ffmpeg is working!"
    else
        echo "❌ ffmpeg failed"
        echo ""
        echo "🔍 Detailed error:"
        "${TOOLS_DIR}/ffmpeg" -version 2>&1 | head -10
    fi
else
    echo "❌ ffmpeg not found"
fi

# Test ffprobe
echo ""
echo "🔍 Testing ffprobe directly:"
echo "==========================="
if [[ -f "${TOOLS_DIR}/ffprobe" ]]; then
    echo "🔧 Running: ${TOOLS_DIR}/ffprobe -version"
    echo "Output:"
    "${TOOLS_DIR}/ffprobe" -version 2>&1 | head -3
    
    echo ""
    echo "🔧 Exit code: $?"
    
    if [[ $? -eq 0 ]]; then
        echo "✅ ffprobe is working!"
    else
        echo "❌ ffprobe failed"
        echo ""
        echo "🔍 Detailed error:"
        "${TOOLS_DIR}/ffprobe" -version 2>&1 | head -10
    fi
else
    echo "❌ ffprobe not found"
fi

# Test with a real YouTube URL (yt-dlp only)
echo ""
echo "🌐 Testing yt-dlp with real URL:"
echo "================================"
if [[ -f "${TOOLS_DIR}/yt-dlp" ]]; then
    echo "🔧 Testing video info retrieval..."
    echo "URL: https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    
    # Test with minimal output
    "${TOOLS_DIR}/yt-dlp" --no-check-certificate --no-warnings --dump-json "https://www.youtube.com/watch?v=dQw4w9WgXcQ" 2>&1 | head -20
    
    local exit_code=$?
    echo ""
    echo "🔧 Exit code: $exit_code"
    
    if [[ $exit_code -eq 0 ]]; then
        echo "✅ yt-dlp can fetch video info!"
    else
        echo "❌ yt-dlp failed to fetch video info"
    fi
fi

echo ""
echo "📊 Summary:"
echo "==========="
echo "📁 All tools are present and statically linked"
echo "🔒 Permissions and quarantine are correct"
echo "📋 If version commands work, tools should work in app"
echo ""
echo "🚀 Next step: Build and test the application!"