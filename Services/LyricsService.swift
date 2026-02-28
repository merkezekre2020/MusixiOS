import Foundation

/// Protocol for lyrics fetching service - enables dependency injection and testability
protocol LyricsServiceProtocol {
    /// Fetch synchronized lyrics for a song
    /// - Parameters:
    ///   - artist: Artist name
    ///   - title: Song title
    ///   - album: Album name (optional)
    ///   - duration: Song duration in seconds
    /// - Returns: Array of LRCLine objects containing synchronized lyrics
    func fetchLyrics(artist: String, title: String, album: String?, duration: Double) async throws -> [LRCLine]
    
    /// Fetch raw lyrics response from API
    func fetchRawLyrics(artist: String, title: String, album: String?, duration: Double) async throws -> LRCLyricsResponse
}

/// Errors that can occur during lyrics fetching
enum LyricsServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case lyricsNotFound
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for lyrics request."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from lyrics server."
        case .decodingError(let error):
            return "Failed to decode lyrics: \(error.localizedDescription)"
        case .lyricsNotFound:
            return "No lyrics found for this song."
        case .serverError(let code):
            return "Server error (HTTP \(code))."
        }
    }
}

/// Service for fetching synchronized lyrics from LRCLIB API
/// API Documentation: https://lrclib.net/docs
final class LyricsService: LyricsServiceProtocol {
    
    // MARK: - Singleton
    static let shared = LyricsService()
    
    // MARK: - Properties
    private let baseURL = "https://lrclib.net/api/get"
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    
    /// Cache for storing fetched lyrics to reduce API calls
    private var lyricsCache: [String: [LRCLine]] = [:]
    private let cacheQueue = DispatchQueue(label: "lyrics.cache.queue", attributes: .concurrent)
    
    // MARK: - Initialization
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - Cache Management
    
    /// Generate cache key for a song
    private func cacheKey(artist: String, title: String) -> String {
        "\(artist.lowercased())-\(title.lowercased())"
    }
    
    /// Get cached lyrics if available
    private func getCachedLyrics(key: String) -> [LRCLine]? {
        cacheQueue.sync {
            lyricsCache[key]
        }
    }
    
    /// Store lyrics in cache
    private func setCachedLyrics(key: String, lyrics: [LRCLine]) {
        cacheQueue.async(flags: .barrier) {
            self.lyricsCache[key] = lyrics
        }
    }
    
    /// Clear all cached lyrics
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.lyricsCache.removeAll()
        }
    }
    
    // MARK: - API Methods
    
    /// Fetch synchronized lyrics for a song from LRCLIB API
    /// - Parameters:
    ///   - artist: Artist name
    ///   - title: Song title
    ///   - album: Album name (optional but improves accuracy)
    ///   - duration: Song duration in seconds (helps find exact match)
    /// - Returns: Array of parsed LRCLine objects
    func fetchLyrics(
        artist: String,
        title: String,
        album: String? = nil,
        duration: Double
    ) async throws -> [LRCLine] {
        
        // Check cache first
        let cacheKey = self.cacheKey(artist: artist, title: title)
        if let cached = getCachedLyrics(key: cacheKey) {
            return cached
        }
        
        // Fetch from API
        let response = try await fetchRawLyrics(
            artist: artist,
            title: title,
            album: album,
            duration: duration
        )
        
        // Parse synced lyrics if available
        if let syncedLyrics = response.syncedLyrics, !syncedLyrics.isEmpty {
            let parsedLines = LRCParser.parse(syncedLyrics)
            
            // Cache the result
            setCachedLyrics(key: cacheKey, lyrics: parsedLines)
            
            return parsedLines
        }
        
        // Fallback to plain lyrics (no timestamps)
        if let plainLyrics = response.plainLyrics, !plainLyrics.isEmpty {
            // Convert plain lyrics to single line at start
            let singleLine = LRCLine(timestamp: 0.0, text: plainLyrics)
            return [singleLine]
        }
        
        throw LyricsServiceError.lyricsNotFound
    }
    
    /// Fetch raw lyrics response from LRCLIB API
    /// Endpoint: GET https://lrclib.net/api/get
    /// Query params: artist_name, track_name, album_name, duration
    func fetchRawLyrics(
        artist: String,
        title: String,
        album: String? = nil,
        duration: Double
    ) async throws -> LRCLyricsResponse {
        
        // Build URL with query parameters
        var components = URLComponents(string: baseURL)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "duration", value: String(format: "%.0f", duration))
        ]
        
        if let album = album {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw LyricsServiceError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LRCPlayer/1.0", forHTTPHeaderField: "User-Agent")
        
        // Perform request
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw LyricsServiceError.networkError(error)
        }
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsServiceError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            // Decode response
            do {
                let lyricsResponse = try decoder.decode(LRCLyricsResponse.self, from: data)
                return lyricsResponse
            } catch {
                throw LyricsServiceError.decodingError(error)
            }
            
        case 404:
            throw LyricsServiceError.lyricsNotFound
            
        default:
            throw LyricsServiceError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Search for lyrics without exact duration match
    /// Useful when duration is unknown
    func searchLyrics(
        artist: String,
        title: String
    ) async throws -> [LRCLine] {
        // Use estimated duration of 0 to get best match
        return try await fetchLyrics(
            artist: artist,
            title: title,
            album: nil,
            duration: 0
        )
    }
}

// MARK: - Mock Service for Previews/Testing
#if DEBUG
final class MockLyricsService: LyricsServiceProtocol {
    var mockLyrics: [LRCLine] = LRCLine.preview
    var shouldThrowError: LyricsServiceError?
    var delay: TimeInterval = 0.5
    
    func fetchLyrics(
        artist: String,
        title: String,
        album: String?,
        duration: Double
    ) async throws -> [LRCLine] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if let error = shouldThrowError {
            throw error
        }
        
        return mockLyrics
    }
    
    func fetchRawLyrics(
        artist: String,
        title: String,
        album: String?,
        duration: Double
    ) async throws -> LRCLyricsResponse {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if let error = shouldThrowError {
            throw error
        }
        
        return LRCLyricsResponse(
            id: 1,
            trackName: title,
            artistName: artist,
            albumName: album ?? "Unknown Album",
            duration: duration,
            instrumental: false,
            plainLyrics: nil,
            syncedLyrics: "[00:00.00]Test lyrics"
        )
    }
}
#endif