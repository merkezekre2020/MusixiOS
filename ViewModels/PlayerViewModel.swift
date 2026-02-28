import Foundation
import Combine
import SwiftUI

/// ViewModel for the PlayerView - manages UI state and business logic
/// Bridges between Views and Services/Managers
@MainActor
final class PlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    /// Current song being played
    @Published private(set) var currentSong: Song?
    
    /// Whether audio is currently playing
    @Published private(set) var isPlaying: Bool = false
    
    /// Current playback time in seconds
    @Published private(set) var currentTime: TimeInterval = 0
    
    /// Total duration of current song
    @Published private(set) var duration: TimeInterval = 0
    
    /// Playback progress (0.0 to 1.0)
    @Published private(set) var progress: Double = 0
    
    /// Current lyrics lines with synchronized timestamps
    @Published private(set) var lyrics: [LRCLine] = []
    
    /// Currently active lyrics line index
    @Published private(set) var activeLyricsIndex: Int = 0
    
    /// Whether lyrics are currently loading
    @Published private(set) var isLoadingLyrics: Bool = false
    
    /// Error message for lyrics loading
    @Published private(set) var lyricsError: String?
    
    /// Background colors extracted from artwork for dynamic theming
    @Published private(set) var backgroundColors: [Color] = [
        Color.purple.opacity(0.6),
        Color.blue.opacity(0.4)
    ]
    
    /// Whether shuffle mode is enabled
    @Published var isShuffleEnabled: Bool = false
    
    /// Current repeat mode
    @Published var repeatMode: PlaybackManager.RepeatMode = .none
    
    /// Currently selected playback queue
    @Published var queue: [Song] = []
    
    // MARK: - Dependencies
    private let playbackManager: PlaybackManager
    private let lyricsService: LyricsServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    /// Task for lyrics fetching (to allow cancellation)
    private var lyricsFetchTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    /// Formatted current time string (e.g., "1:23")
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    /// Formatted duration string (e.g., "3:45")
    var formattedDuration: String {
        formatTime(duration)
    }
    
    /// Check if there's a current song
    var hasCurrentSong: Bool {
        currentSong != nil
    }
    
    /// Song title or placeholder
    var songTitle: String {
        currentSong?.title ?? "Not Playing"
    }
    
    /// Artist name or placeholder
    var artistName: String {
        currentSong?.artist ?? "Select a song"
    }
    
    /// Album name or placeholder
    var albumName: String {
        currentSong?.album ?? ""
    }
    
    /// Current artwork image
    var artwork: UIImage? {
        currentSong?.artwork
    }
    
    /// Whether lyrics are available
    var hasLyrics: Bool {
        !lyrics.isEmpty
    }
    
    /// Current active lyrics line for scrolling
    var activeLyricsLineId: UUID? {
        guard activeLyricsIndex < lyrics.count else { return nil }
        return lyrics[activeLyricsIndex].id
    }
    
    // MARK: - Initialization
    init(
        playbackManager: PlaybackManager = .shared,
        lyricsService: LyricsServiceProtocol = LyricsService.shared
    ) {
        self.playbackManager = playbackManager
        self.lyricsService = lyricsService
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    /// Setup Combine bindings to playback manager
    private func setupBindings() {
        // Bind to playback manager's published properties
        playbackManager.$currentSong
            .receive(on: DispatchQueue.main)
            .sink { [weak self] song in
                self?.currentSong = song
                self?.fetchLyrics()
                self?.extractColors()
            }
            .store(in: &cancellables)
        
        playbackManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
            }
            .store(in: &cancellables)
        
        playbackManager.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
                self?.updateActiveLyricsIndex()
            }
            .store(in: &cancellables)
        
        playbackManager.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.duration = duration
            }
            .store(in: &cancellables)
        
        playbackManager.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.progress = progress
            }
            .store(in: &cancellables)
        
        playbackManager.$isShuffleEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isShuffleEnabled = isEnabled
            }
            .store(in: &cancellables)
        
        playbackManager.$repeatMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.repeatMode = mode
            }
            .store(in: &cancellables)
        
        playbackManager.$queue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] queue in
                self?.queue = queue
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Play a specific song
    func play(song: Song) {
        playbackManager.play(song: song)
    }
    
    /// Resume playback
    func play() {
        playbackManager.play()
    }
    
    /// Pause playback
    func pause() {
        playbackManager.pause()
    }
    
    /// Toggle between play and pause
    func togglePlayback() {
        playbackManager.togglePlayback()
    }
    
    /// Seek to specific time
    func seek(to time: TimeInterval) {
        playbackManager.seek(to: time)
    }
    
    /// Seek by percentage (0.0 to 1.0)
    func seekToPercentage(_ percentage: Double) {
        playbackManager.seekToPercentage(percentage)
    }
    
    /// Skip to next song
    func skipToNext() {
        playbackManager.skipToNext()
    }
    
    /// Skip to previous song
    func skipToPrevious() {
        playbackManager.skipToPrevious()
    }
    
    /// Toggle shuffle mode
    func toggleShuffle() {
        playbackManager.toggleShuffle()
    }
    
    /// Cycle through repeat modes
    func cycleRepeatMode() {
        playbackManager.cycleRepeatMode()
    }
    
    /// Set the playback queue
    func setQueue(_ songs: [Song], startIndex: Int = 0) {
        playbackManager.setQueue(songs, startIndex: startIndex)
    }
    
    /// Refresh lyrics for current song
    func refreshLyrics() {
        fetchLyrics()
    }
    
    // MARK: - Private Methods
    
    /// Fetch lyrics for the current song
    private func fetchLyrics() {
        // Cancel any existing fetch task
        lyricsFetchTask?.cancel()
        
        // Reset state
        lyrics = []
        activeLyricsIndex = 0
        lyricsError = nil
        
        guard let song = currentSong else { return }
        
        isLoadingLyrics = true
        
        // Create new fetch task
        lyricsFetchTask = Task { @MainActor in
            do {
                let fetchedLyrics = try await lyricsService.fetchLyrics(
                    artist: song.artist,
                    title: song.title,
                    album: song.album,
                    duration: song.duration
                )
                
                // Check if task was cancelled or song changed
                guard !Task.isCancelled, currentSong?.id == song.id else { return }
                
                self.lyrics = fetchedLyrics
                self.isLoadingLyrics = false
                
            } catch LyricsServiceError.lyricsNotFound {
                self.lyrics = [LRCLine(timestamp: 0, text: "Lyrics not found for this song.")]
                self.isLoadingLyrics = false
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                self.lyricsError = error.localizedDescription
                self.lyrics = [LRCLine(timestamp: 0, text: "Failed to load lyrics.")]
                self.isLoadingLyrics = false
            }
        }
    }
    
    /// Update the active lyrics index based on current time
    private func updateActiveLyricsIndex() {
        guard !lyrics.isEmpty else {
            activeLyricsIndex = 0
            return
        }
        
        // Find the line that should be active
        var newIndex = 0
        for (index, line) in lyrics.enumerated() {
            if currentTime >= line.timestamp {
                newIndex = index
            } else {
                break
            }
        }
        
        // Only update if changed to avoid unnecessary UI updates
        if newIndex != activeLyricsIndex {
            activeLyricsIndex = newIndex
        }
    }
    
    /// Extract dominant colors from artwork for dynamic background
    private func extractColors() {
        guard let artwork = currentSong?.artwork else {
            // Default gradient colors
            backgroundColors = [
                Color.purple.opacity(0.6),
                Color.blue.opacity(0.4)
            ]
            return
        }
        
        // Extract colors from image
        let colors = artwork.dominantColors(count: 2)
        
        if colors.count >= 2 {
            backgroundColors = [
                Color(colors[0]).opacity(0.7),
                Color(colors[1]).opacity(0.5)
            ]
        } else if let color = colors.first {
            backgroundColors = [
                Color(color).opacity(0.7),
                Color.purple.opacity(0.4)
            ]
        } else {
            backgroundColors = [
                Color.purple.opacity(0.6),
                Color.blue.opacity(0.4)
            ]
        }
    }
    
    /// Format time interval to mm:ss string
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - UIImage Extension for Color Extraction
extension UIImage {
    /// Extract dominant colors from image
    func dominantColors(count: Int = 2) -> [UIColor] {
        guard let cgImage = self.cgImage else {
            return [.systemPurple, .systemBlue]
        }
        
        // Resize image for faster processing
        let size = CGSize(width: 50, height: 50)
        UIGraphicsBeginImageContext(size)
        self.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let resizedCGImage = resizedImage.cgImage else {
            UIGraphicsEndImageContext()
            return [.systemPurple, .systemBlue]
        }
        UIGraphicsEndImageContext()
        
        // Sample pixels
        let width = resizedCGImage.width
        let height = resizedCGImage.height
        let dataSize = width * height * 4
        var pixelData = [UInt8](repeating: 0, count: dataSize)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return [.systemPurple, .systemBlue]
        }
        
        context.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Calculate average color
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var pixelCount: CGFloat = 0
        
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let index = (y * width + x) * 4
                let red = CGFloat(pixelData[index]) / 255.0
                let green = CGFloat(pixelData[index + 1]) / 255.0
                let blue = CGFloat(pixelData[index + 2]) / 255.0
                
                r += red
                g += green
                b += blue
                pixelCount += 1
            }
        }
        
        let primaryColor = UIColor(
            red: r / pixelCount,
            green: g / pixelCount,
            blue: b / pixelCount,
            alpha: 1.0
        )
        
        // Create a secondary color (darker shade)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        primaryColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let secondaryColor = UIColor(
            hue: (hue + 0.1).truncatingRemainder(dividingBy: 1.0),
            saturation: saturation,
            brightness: max(brightness * 0.7, 0.3),
            alpha: 1.0
        )
        
        return [primaryColor, secondaryColor]
    }
}