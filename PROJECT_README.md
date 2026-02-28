# iOS Music Player App

A professional, full-featured music player application for iOS built with SwiftUI, AVFoundation, MediaPlayer, and MVVM architecture.

## 📱 Features

### Core Functionality
- 🎵 **Local Music Library Access** - Browse and play songs from your device's music library
- ▶️ **Full Playback Controls** - Play, pause, skip, seek, shuffle, and repeat
- 📊 **Progress Tracking** - Real-time progress bar with 0.1s precision
- 🎨 **Dynamic Backgrounds** - Artwork-based color extraction for immersive UI
- 📝 **Synchronized Lyrics** - Real-time lyrics display synced with playback (via LRCLIB API)

### Lyrics Features
- LRC format parsing with timestamp conversion
- Auto-scrolling lyrics panel
- Active line highlighting (bright/white, larger, centered)
- Past lines dimmed and slightly blurred
- Loading states and error handling

## 🏗️ Architecture

The app follows **MVVM (Model-View-ViewModel)** architecture with clean code principles:

```
MusicPlayerApp/
├── Models/
│   ├── Song.swift          # Music item model with MediaPlayer integration
│   └── LRCLine.swift       # Lyrics line model with LRC parsing
├── Services/
│   ├── MusicProvider.swift # Local music library access (MediaPlayer)
│   └── LyricsService.swift # LRCLIB API integration & LRC parsing
├── Managers/
│   └── PlaybackManager.swift # AVFoundation audio playback (Singleton)
├── ViewModels/
│   └── PlayerViewModel.swift # Player state management
└── Views/
    ├── MainTabView.swift   # Root tab navigation
    ├── LibraryView.swift   # Music library browser with search
    └── PlayerView.swift    # Full-screen player with lyrics
```

## 🔧 Technical Stack

- **SwiftUI** - Modern declarative UI
- **AVFoundation** - Audio playback (AVAudioPlayer)
- **MediaPlayer** - Local library access & Now Playing info
- **Combine** - Reactive programming for state management
- **MVVM** - Clean architecture pattern
- **LRCLIB API** - Synchronized lyrics source

## 📋 Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
- Physical device or simulator with music library access

## 🔐 Permissions

The app requires `NSAppleMusicUsageDescription` permission to access the local music library. Users must grant this permission when prompted.

## 🚀 Getting Started

1. Create a new iOS project in Xcode
2. Copy all Swift files to the project
3. Add the `Info.plist` entries for music library access
4. Build and run on a device or simulator
5. Grant music library permission when prompted

## 📦 Key Components

### Models
- **`Song`** - Represents a music track with metadata and artwork
- **`LRCLine`** - Represents a synchronized lyrics line with timestamp

### Services
- **`MusicProvider`** - Singleton for accessing local music library via MediaPlayer
- **`LyricsService`** - Fetches and parses synchronized lyrics from LRCLIB API

### Managers
- **`PlaybackManager`** - Singleton managing audio playback, queue, and remote controls

### ViewModels
- **`PlayerViewModel`** - Bridges Views with Services, manages UI state
- **`LibraryViewModel`** - Manages library data and search functionality

### Views
- **`MainTabView`** - Root view with tab navigation and mini player
- **`LibraryView`** - Searchable song list with artwork display
- **`PlayerView`** - Full-screen player with dynamic background and lyrics panel

## 🎵 LRCLIB API Integration

The app uses the LRCLIB API for synchronized lyrics:

```
GET https://lrclib.net/api/get?artist_name={artist}&track_name={title}&duration={duration}
```

The API returns LRC format lyrics which are parsed into timestamped lines for synchronized display.

## 🎨 UI Design

- Apple Music-inspired design
- Dynamic gradient backgrounds based on album artwork
- Smooth animations and transitions
- Dark mode optimized
- Glassmorphism effects

## 📝 License

This project is provided as a reference implementation for iOS music player development.