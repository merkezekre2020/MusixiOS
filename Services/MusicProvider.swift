import Foundation
import MediaPlayer
import Combine

/// Protocol for music library access - enables dependency injection and testability
protocol MusicProviderProtocol {
    /// Request authorization to access music library
    func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus
    /// Get current authorization status
    var authorizationStatus: MPMediaLibraryAuthorizationStatus { get }
    /// Fetch all songs from local library
    func fetchSongs() async throws -> [Song]
    /// Search songs by query string
    func searchSongs(query: String) async throws -> [Song]
}

/// Errors that can occur during music library operations
enum MusicProviderError: Error, LocalizedError {
    case unauthorized
    case denied
    case restricted
    case fetchFailed(String)
    case noSongsFound
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Music library access not authorized. Please grant access in Settings."
        case .denied:
            return "Access to music library was denied."
        case .restricted:
            return "Music library access is restricted on this device."
        case .fetchFailed(let message):
            return "Failed to fetch songs: \(message)"
        case .noSongsFound:
            return "No songs found in your music library."
        }
    }
}

/// Manages access to the device's local music library using MediaPlayer framework
/// Implements MusicProviderProtocol for dependency injection and testability
final class MusicProvider: MusicProviderProtocol {
    
    // MARK: - Singleton
    static let shared = MusicProvider()
    
    // MARK: - Properties
    private let mediaLibrary = MPMediaLibrary.default()
    private var cachedSongs: [Song] = []
    private var cacheTimestamp: Date?
    private let cacheValidityInterval: TimeInterval = 60 // Cache valid for 60 seconds
    
    /// Current authorization status for music library access
    var authorizationStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Authorization
    
    /// Request authorization to access the music library
    /// - Returns: The authorization status after request
    @discardableResult
    func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        let status = MPMediaLibrary.authorizationStatus()
        
        // Already authorized or restricted
        if status == .authorized || status == .restricted {
            return status
        }
        
        // Request authorization
        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { newStatus in
                continuation.resume(returning: newStatus)
            }
        }
    }
    
    /// Check if access is authorized, throwing appropriate error if not
    private func verifyAuthorization() throws {
        let status = authorizationStatus
        switch status {
        case .notDetermined:
            throw MusicProviderError.unauthorized
        case .denied:
            throw MusicProviderError.denied
        case .restricted:
            throw MusicProviderError.restricted
        case .authorized:
            return
        @unknown default:
            throw MusicProviderError.unauthorized
        }
    }
    
    // MARK: - Song Fetching
    
    /// Fetch all songs from the local music library
    /// - Returns: Array of Song objects sorted by title
    /// - Throws: MusicProviderError if authorization fails or fetch fails
    func fetchSongs() async throws -> [Song] {
        // Check cache first
        if let cacheTimestamp = cacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < cacheValidityInterval,
           !cachedSongs.isEmpty {
            return cachedSongs
        }
        
        // Verify authorization
        try verifyAuthorization()
        
        // Create query for all songs
        let query = MPMediaQuery.songs()
        
        // Filter out cloud items if not downloaded
        query.addFilterPredicate(MPMediaPropertyPredicate(
            value: false,
            forProperty: MPMediaItemPropertyIsCloudItem
        ))
        
        guard let mediaItems = query.items, !mediaItems.isEmpty else {
            throw MusicProviderError.noSongsFound
        }
        
        // Convert to Song models
        let songs = mediaItems.compactMap { item -> Song? in
            // Validate essential properties
            guard item.title != nil else { return nil }
            return Song(from: item)
        }
        
        // Sort by title
        let sortedSongs = songs.sorted { $0.title < $1.title }
        
        // Update cache
        cachedSongs = sortedSongs
        cacheTimestamp = Date()
        
        return sortedSongs
    }
    
    /// Search songs in the library by query string
    /// - Parameter query: Search query to match against title, artist, or album
    /// - Returns: Filtered array of matching songs
    /// - Throws: MusicProviderError if fetch fails
    func searchSongs(query: String) async throws -> [Song] {
        let allSongs = try await fetchSongs()
        
        guard !query.isEmpty else {
            return allSongs
        }
        
        let lowercasedQuery = query.lowercased()
        return allSongs.filter { song in
            song.searchableText.contains(lowercasedQuery)
        }
    }
    
    /// Get songs by a specific artist
    /// - Parameter artist: Artist name to search for
    /// - Returns: Array of songs by the specified artist
    func getSongs(byArtist artist: String) async throws -> [Song] {
        let allSongs = try await fetchSongs()
        return allSongs.filter { $0.artist.lowercased() == artist.lowercased() }
    }
    
    /// Get songs from a specific album
    /// - Parameter album: Album name to search for
    /// - Returns: Array of songs from the specified album
    func getSongs(fromAlbum album: String) async throws -> [Song] {
        let allSongs = try await fetchSongs()
        return allSongs.filter { $0.album.lowercased() == album.lowercased() }
    }
    
    /// Clear the song cache (useful after library changes)
    func clearCache() {
        cachedSongs = []
        cacheTimestamp = nil
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    /// Posted when the music library changes
    static let musicLibraryDidChange = Notification.Name("musicLibraryDidChange")
}