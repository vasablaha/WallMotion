#!/bin/bash

# Simple DMG Builder for WallMotion
# Creates DMG with app + dependencies installer

set -e

APP_NAME="WallMotion"
DMG_NAME="WallMotion-v1.0.0"
BUILD_DIR="dmg-temp"

echo "🔨 Building DMG for WallMotion..."

# Clean up
rm -rf "$BUILD_DIR"
rm -f "${DMG_NAME}.dmg"
mkdir -p "$BUILD_DIR"

# Copy app
APP_PATH="build/Build/Products/Release/WallMotion.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ App not found at $APP_PATH"
    echo "Looking for app in build directory..."
    find build -name "WallMotion.app" -type d 2>/dev/null | head -1
    exit 1
fi

echo "📱 Copying WallMotion.app..."
cp -R "$APP_PATH" "$BUILD_DIR/"

# Copy VideoSaver executable
VIDEOSAVER_PATH="build/Build/Products/Release/VideoSaver"
if [[ -f "$VIDEOSAVER_PATH" ]]; then
    echo "📺 Copying VideoSaver executable..."
    mkdir -p "$BUILD_DIR/WallMotion.app/Contents/MacOS"
    cp "$VIDEOSAVER_PATH" "$BUILD_DIR/WallMotion.app/Contents/MacOS/"
    chmod +x "$BUILD_DIR/WallMotion.app/Contents/MacOS/VideoSaver"
else
    echo "⚠️ VideoSaver executable not found at $VIDEOSAVER_PATH"
fi

# Create Applications symlink
echo "🔗 Creating Applications link..."
ln -sf /Applications "$BUILD_DIR/Applications"

# Download dependencies
echo "📦 Downloading dependencies..."
mkdir -p "$BUILD_DIR/Dependencies"

# Download yt-dlp
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o "$BUILD_DIR/Dependencies/yt-dlp"
chmod +x "$BUILD_DIR/Dependencies/yt-dlp"

# Download ffmpeg
curl -L https://evermeet.cx/ffmpeg/ffmpeg-6.1.zip -o ffmpeg.zip
unzip -q ffmpeg.zip -d "$BUILD_DIR/Dependencies/"
rm ffmpeg.zip

# Create installer script
echo "🛠️ Creating installer..."
cat > "$BUILD_DIR/Install Dependencies.command" << 'EOF'
#!/bin/bash

echo "Installing WallMotion dependencies..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Copy to /usr/local/bin
sudo mkdir -p /usr/local/bin
sudo cp "$SCRIPT_DIR/Dependencies/yt-dlp" /usr/local/bin/yt-dlp
sudo cp "$SCRIPT_DIR/Dependencies/ffmpeg" /usr/local/bin/ffmpeg
sudo chmod +x /usr/local/bin/yt-dlp
sudo chmod +x /usr/local/bin/ffmpeg

echo "✅ Dependencies installed successfully!"
echo "Now drag WallMotion.app to Applications folder"

read -p "Press Enter to close..."
EOF

chmod +x "$BUILD_DIR/Install Dependencies.command"

# Create README
cat > "$BUILD_DIR/README.txt" << 'EOF'
WallMotion Installation
======================

1. Double-click "Install Dependencies.command"
2. Drag WallMotion.app to Applications folder  
3. Launch WallMotion from Applications

Dependencies installed:
- yt-dlp (YouTube downloader)
- ffmpeg (video processor)

Support: https://github.com/your-username/wallmotion
EOF

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -srcfolder "$BUILD_DIR" -volname "WallMotion" -format UDZO -o "${DMG_NAME}.dmg"

# Clean up
rm -rf "$BUILD_DIR"

echo "✅ DMG created: ${DMG_NAME}.dmg"
echo "📊 Size: $(du -h "${DMG_NAME}.dmg" | cut -f1)"

# Create checksum
shasum -a 256 "${DMG_NAME}.dmg" > "${DMG_NAME}.dmg.sha256"
echo "🔐 Checksum: ${DMG_NAME}.dmg.sha256"

echo ""
echo "🚀 Ready for distribution!"
echo "Upload to S3 and share download link with customers."
