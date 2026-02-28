# 🎵 MusixiOS

[![iOS](https://img.shields.io/badge/iOS-15.0%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.7%2B-orange)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0%2B-green)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](LICENSE)

A beautiful, full-featured music player application for iOS built with **SwiftUI**, featuring synchronized lyrics, dynamic backgrounds, and a modern MVVM architecture.

![App Preview](https://via.placeholder.com/300x600/1a1a2e/ffffff?text=MusixiOS+Preview)

## ✨ Features

### 🎵 Music Playback
- **Local Music Library** - Access and play songs from your device's music library
- **Full Playback Controls** - Play, pause, skip, previous, seek
- **Playback Modes** - Shuffle and repeat (all/one/none)
- **Background Audio** - Continue playback when app is in background
- **Remote Controls** - Control playback from Control Center and Lock Screen

### 🎨 Beautiful UI
- **Dynamic Backgrounds** - Artwork-based color extraction for immersive experience
- **Mini Player** - Persistent mini player with quick controls
- **Full-screen Player** - Elegant full-screen player with gesture controls
- **Dark Mode Support** - Optimized for both light and dark themes

### 📝 Synchronized Lyrics
- **Real-time Lyrics** - Lyrics synchronized with playback progress
- **LRCLIB Integration** - Fetches lyrics from LRCLIB API
- **Auto-scrolling** - Automatically scrolls to current line
- **Visual Effects** - Active line highlighting with blur effects on past lines
- **LRC Format Support** - Standard LRC format with timestamp parsing

## 📱 Screenshots

| Library | Player | Lyrics |
|---------|--------|--------|
| ![Library](https://via.placeholder.com/200x400/2d2d44/ffffff?text=Library) | ![Player](https://via.placeholder.com/200x400/1a1a2e/ffffff?text=Player) | ![Lyrics](https://via.placeholder.com/200x400/16213e/ffffff?text=Lyrics) |

## 🏗️ Architecture

```
MusixiOS/
├── Models/
│   ├── Song.swift              # Music item model
│   └── LRCLine.swift           # Lyrics line model
├── Services/
│   ├── MusicProvider.swift     # MediaPlayer integration
│   └── LyricsService.swift     # LRCLIB API client
├── Managers/
│   └── PlaybackManager.swift   # Audio playback manager
├── ViewModels/
│   └── PlayerViewModel.swift   # Player state management
└── Views/
    ├── MainTabView.swift       # Root navigation
    ├── LibraryView.swift       # Music library
    ├── PlayerView.swift        # Full-screen player
    └── ContentView.swift       # Main content
```

## 🚀 Getting Started

### Requirements
- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- Physical iOS device or simulator with music library access

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/merkezekre2020/MusixiOS.git
   cd MusixiOS
   ```

2. **Open in Xcode**
   ```bash
   open MusixiOS.xcodeproj
   ```

3. **Build and Run**
   - Select your target device/simulator
   - Press `Cmd+R` to build and run
   - Grant music library permission when prompted

### Permissions

Add the following to your `Info.plist`:

```xml
<key>NSAppleMusicUsageDescription</key>
<string>This app needs access to your music library to play your songs.</string>
```

## 🔧 Technical Stack

| Technology | Purpose |
|------------|---------|
| **SwiftUI** | Modern declarative UI framework |
| **AVFoundation** | Audio playback (AVAudioPlayer) |
| **MediaPlayer** | Local music library access |
| **Combine** | Reactive state management |
| **MVVM** | Clean architecture pattern |
| **LRCLIB API** | Synchronized lyrics source |

## 📦 Key Components

### Models
- **`Song`** - Represents a music track with metadata, artwork, and MediaPlayer integration
- **`LRCLine`** - Represents a synchronized lyrics line with timestamp parsing

### Services
- **`MusicProvider`** - Singleton for accessing local music library
- **`LyricsService`** - Fetches and parses lyrics from LRCLIB API

### Managers
- **`PlaybackManager`** - Singleton managing audio playback, queue, and system integration

### ViewModels
- **`PlayerViewModel`** - Manages player UI state and bridges Views with Services

## 🎵 Lyrics API

The app uses [LRCLIB](https://lrclib.net/) for synchronized lyrics:

```
GET https://lrclib.net/api/get?artist_name={artist}&track_name={title}&duration={duration}
```

Response includes:
- `syncedLyrics` - LRC format with timestamps
- `plainLyrics` - Plain text lyrics
- `instrumental` - Boolean flag

## 🛠️ Build Automation

This project includes GitHub Actions workflows for automated builds:

- **Build Unsigned IPA** - Creates unsigned IPA for testing
- See `.github/workflows/` for configuration

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [LRCLIB](https://lrclib.net/) - For providing the synchronized lyrics API
- Apple - For SwiftUI, AVFoundation, and MediaPlayer frameworks

## 📧 Contact

For questions or support, please open an issue on GitHub.

---

Made with ❤️ for music lovers
