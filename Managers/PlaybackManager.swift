import Foundation
import AVFoundation
import Combine
import MediaPlayer

/// Protocol for playback management - enables testing and dependency injection
protocol PlaybackManagerProtocol: AnyObject {
    var currentSong: Song? { get }
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var progress: Double { get }
    
    func play(song: Song)
    func play()
    func pause()
    func togglePlayback()
    func seek(to time: TimeInterval)
    func skipToNext()
    func skipToPrevious()
}

/// Manages audio playback using AVFoundation
/// Singleton pattern ensures single audio session across the app
/// Publishes playback state updates via Combine framework
final class PlaybackManager: NSObject, ObservableObject, PlaybackManagerProtocol {
    
    // MARK: - Singleton
    static let shared = PlaybackManager()
    
    // MARK: - Published Properties
    /// Currently playing song
    @Published private(set) var currentSong: Song?
    
    /// Whether audio is currently playing
    @Published private(set) var isPlaying: Bool = false
    
    /// Current playback time in seconds
    @Published private(set) var currentTime: TimeInterval = 0
    
    /// Total duration of current song in seconds
    @Published private(set) var duration: TimeInterval = 0
    
    /// Playback progress as percentage (0.0 to 1.0)
    @Published private(set) var progress: Double = 0
    
    /// Current playback queue
    @Published private(set) var queue: [Song] = []
    
    /// Current index in the queue
    @Published private(set) var currentIndex: Int = 0
    
    /// Whether shuffle mode is enabled
    @Published var isShuffleEnabled: Bool = false
    
    /// Current repeat mode
    @Published var repeatMode: RepeatMode = .none
    
    // MARK: - Private Properties
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    /// Time update interval in seconds (0.1s for precise lyrics sync)
    private let updateInterval: TimeInterval = 0.1
    
    /// Audio session for managing audio behavior
    private let audioSession = AVAudioSession.sharedInstance()
    
    /// Shuffle indices for random playback
    private var shuffledIndices: [Int] = []
    
    // MARK: - Enums
    enum RepeatMode: String, CaseIterable {
        case none = "repeat"
        case one = "repeat.1"
        case all = "repeat.all"
        
        var iconName: String {
            switch self {
            case .none: return "repeat"
            case .one: return "repeat.1"
            case .all: return "repeat"
            }
        }
        
        mutating func next() {
            switch self {
            case .none: self = .all
            case .all: self = .one
            case .one: self = .none
            }
        }
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        setupNotifications()
    }
    
    deinit {
        timer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    /// Configure audio session for background playback
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth]
            )
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    /// Setup remote control commands for lock screen/Control Center
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipToNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipToPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    
    /// Setup notifications for audio interruptions
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)
    }
    
    /// Handle audio interruptions (phone calls, etc.)
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began - pause playback
            pause()
        case .ended:
            // Interruption ended - resume if appropriate
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        @unknown default:
            break
        }
    }
    
    /// Update now playing info for lock screen
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        if let artwork = song.artwork {
            let mediaArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Timer
    
    /// Start the timer for time updates
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    /// Stop the timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Update current time and progress
    private func updateProgress() {
        guard let player = player else { return }
        
        currentTime = player.currentTime
        duration = player.duration
        progress = duration > 0 ? currentTime / duration : 0
        
        updateNowPlayingInfo()
        
        // Check if song finished
        if currentTime >= duration - 0.1 {
            handleSongFinished()
        }
    }
    
    /// Handle song completion
    private func handleSongFinished() {
        switch repeatMode {
        case .one:
            seek(to: 0)
            play()
        case .all:
            skipToNext()
        case .none:
            if currentIndex < queue.count - 1 {
                skipToNext()
            } else {
                pause()
                seek(to: 0)
            }
        }
    }
    
    // MARK: - Playback Control
    
    /// Play a specific song
    func play(song: Song) {
        // Find or add song to queue
        if let index = queue.firstIndex(where: { $0.id == song.id }) {
            currentIndex = index
        } else {
            queue.insert(song, at: currentIndex)
        }
        
        loadAndPlayCurrentSong()
    }
    
    /// Load and play the current song
    private func loadAndPlayCurrentSong() {
        guard currentIndex < queue.count else { return }
        
        let song = queue[currentIndex]
        currentSong = song
        
        // Get audio URL from MPMediaItem
        guard let mediaItem = song.mediaItem,
              let assetURL = mediaItem.value(forProperty: MPMediaItemPropertyAssetURL) as? URL else {
            print("Failed to get asset URL for song")
            skipToNext()
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: assetURL)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            
            play()
        } catch {
            print("Failed to create audio player: \(error.localizedDescription)")
            skipToNext()
        }
    }
    
    /// Resume playback
    func play() {
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
    }
    
    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
    }
    
    /// Toggle between play and pause
    func togglePlayback() {
        isPlaying ? pause() : play()
    }
    
    /// Seek to specific time
    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        player?.currentTime = clampedTime
        currentTime = clampedTime
        progress = duration > 0 ? currentTime / duration : 0
        updateNowPlayingInfo()
    }
    
    /// Seek by percentage (0.0 to 1.0)
    func seekToPercentage(_ percentage: Double) {
        let clampedPercentage = max(0, min(percentage, 1.0))
        let targetTime = duration * clampedPercentage
        seek(to: targetTime)
    }
    
    /// Skip to next song
    func skipToNext() {
        guard !queue.isEmpty else { return }
        
        let nextIndex: Int
        if isShuffleEnabled {
            nextIndex = getNextShuffledIndex()
        } else {
            nextIndex = (currentIndex + 1) % queue.count
        }
        
        currentIndex = nextIndex
        loadAndPlayCurrentSong()
    }
    
    /// Skip to previous song
    func skipToPrevious() {
        guard !queue.isEmpty else { return }
        
        // If more than 3 seconds in, restart song
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        let prevIndex: Int
        if isShuffleEnabled {
            prevIndex = getPreviousShuffledIndex()
        } else {
            prevIndex = currentIndex > 0 ? currentIndex - 1 : queue.count - 1
        }
        
        currentIndex = prevIndex
        loadAndPlayCurrentSong()
    }
    
    // MARK: - Queue Management
    
    /// Set the playback queue with array of songs
    func setQueue(_ songs: [Song], startIndex: Int = 0) {
        queue = songs
        currentIndex = min(startIndex, songs.count - 1)
        generateShuffledIndices()
    }
    
    /// Generate shuffled indices for shuffle mode
    private func generateShuffledIndices() {
        shuffledIndices = Array(0..<queue.count).shuffled()
        // Ensure we don't start with the same song twice
        if let firstIndex = shuffledIndices.first, firstIndex == currentIndex, shuffledIndices.count > 1 {
            shuffledIndices.swapAt(0, 1)
        }
    }
    
    /// Get next index in shuffle mode
    private func getNextShuffledIndex() -> Int {
        guard let currentPosition = shuffledIndices.firstIndex(of: currentIndex) else {
            return (currentIndex + 1) % queue.count
        }
        let nextPosition = (currentPosition + 1) % shuffledIndices.count
        return shuffledIndices[nextPosition]
    }
    
    /// Get previous index in shuffle mode
    private func getPreviousShuffledIndex() -> Int {
        guard let currentPosition = shuffledIndices.firstIndex(of: currentIndex) else {
            return currentIndex > 0 ? currentIndex - 1 : queue.count - 1
        }
        let prevPosition = (currentPosition - 1 + shuffledIndices.count) % shuffledIndices.count
        return shuffledIndices[prevPosition]
    }
    
    /// Toggle shuffle mode
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            generateShuffledIndices()
        }
    }
    
    /// Cycle through repeat modes
    func cycleRepeatMode() {
        repeatMode.next()
    }
}

// MARK: - AVAudioPlayerDelegate
extension PlaybackManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        handleSongFinished()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        skipToNext()
    }
}