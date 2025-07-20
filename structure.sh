# Download yt-dlp pro macOS (Universal Binary)
echo "📺 Downloading yt-dlp..."
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o WallMotion/Resources/Executables/yt-dlp

# Nastav executable permissions
chmod +x WallMotion/Resources/Executables/yt-dlp

# Zkopíruj ffmpeg z Homebrew (už ho máš nainstalovaný)
echo "🎬 Copying ffmpeg from Homebrew..."
cp /opt/homebrew/bin/ffmpeg WallMotion/Resources/Executables/ffmpeg
cp /opt/homebrew/bin/ffprobe WallMotion/Resources/Executables/ffprobe

# Ověř že jsou executable
chmod +x WallMotion/Resources/Executables/ffmpeg
chmod +x WallMotion/Resources/Executables/ffprobe
