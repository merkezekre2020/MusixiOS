import Foundation
import MediaPlayer
import UIKit

/// Represents a song in the music library
/// Conforms to Identifiable for SwiftUI list rendering and Equatable for comparison
struct Song: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artwork: UIImage?
    let mediaItem: MPMediaItem?
    
    /// Initialize from MPMediaItem
    /// - Parameter mediaItem: MediaPlayer media item from local library
    init(from mediaItem: MPMediaItem) {
        self.id = mediaItem.persistentID.description
        self.title = mediaItem.title ?? "Unknown Title"
        self.artist = mediaItem.artist ?? "Unknown Artist"
        self.album = mediaItem.albumTitle ?? "Unknown Album"
        self.duration = mediaItem.playbackDuration
        self.artwork = mediaItem.artwork?.image(at: CGSize(width: 600, height: 600))
        self.mediaItem = mediaItem
    }
    
    /// Initialize for previews/testing
    init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        artwork: UIImage? = nil,
        mediaItem: MPMediaItem? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artwork = artwork
        self.mediaItem = mediaItem
    }
    
    /// Formatted duration string (e.g., "3:42")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Searchable text combining title, artist, and album
    var searchableText: String {
        "\(title) \(artist) \(album)".lowercased()
    }
}

// MARK: - Preview Data
extension Song {
    static let preview = Song(
        title: "Bohemian Rhapsody",
        artist: "Queen",
        album: "A Night at the Opera",
        duration: 354,
        artwork: nil
    )
    
    static let previewList = [
        Song(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", duration: 354),
        Song(title: "Hotel California", artist: "Eagles", album: "Hotel California", duration: 391),
        Song(title: "Imagine", artist: "John Lennon", album: "Imagine", duration: 183),
        Song(title: "Billie Jean", artist: "Michael Jackson", album: "Thriller", duration: 294),
        Song(title: "Sweet Child O' Mine", artist: "Guns N' Roses", album: "Appetite for Destruction", duration: 356)
    ]
}