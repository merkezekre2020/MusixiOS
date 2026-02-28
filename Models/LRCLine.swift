import Foundation

/// Represents a single line of synchronized lyrics with timestamp
/// LRC Format: [mm:ss.xx]Lyrics text
struct LRCLine: Identifiable, Equatable, Hashable {
    let id = UUID()
    /// Timestamp in seconds (e.g., 12.34 for [00:12.34])
    let timestamp: Double
    /// The lyrics text for this timestamp
    let text: String
    
    /// Formatted timestamp for display (mm:ss)
    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Check if this line is currently active based on current playback time
    /// - Parameters:
    ///   - currentTime: Current playback time in seconds
    ///   - nextLineTimestamp: Timestamp of the next line (nil if this is the last line)
    /// - Returns: True if this line should be highlighted
    func isActive(at currentTime: Double, nextLineTimestamp: Double?) -> Bool {
        if currentTime < timestamp {
            return false
        }
        if let nextLineTimestamp = nextLineTimestamp {
            return currentTime < nextLineTimestamp
        }
        return true
    }
}

// MARK: - LRCParser
/// Parses LRC format lyrics into structured LRCLine objects
enum LRCParser {
    
    /// Regular expression pattern for LRC timestamp [mm:ss.xx] or [mm:ss:xx]
    private static let timestampPattern = #"\[(\d{2}):(\d{2})[\.:\](\d{2,3})\]"#
    
    /// Parses raw LRC format text into array of LRCLine objects
    /// - Parameter lrcText: Raw LRC formatted lyrics text
    /// - Returns: Array of LRCLine objects sorted by timestamp
    static func parse(_ lrcText: String) -> [LRCLine] {
        let lines = lrcText.components(separatedBy: .newlines)
        var parsedLines: [LRCLine] = []
        
        let regex = try? NSRegularExpression(pattern: timestampPattern, options: [])
        
        for line in lines {
            let nsRange = NSRange(line.startIndex..., in: line)
            let matches = regex?.matches(in: line, options: [], range: nsRange) ?? []
            
            // Extract lyrics text (everything after the last timestamp)
            let textStartIndex: String.Index
            if let lastMatch = matches.last {
                let matchEnd = lastMatch.range.upperBound
                textStartIndex = String.Index(utf16Offset: matchEnd, in: line)
            } else {
                continue // No timestamp found, skip line
            }
            
            let lyricsText = String(line[textStartIndex...]).trimmingCharacters(in: .whitespaces)
            
            // Create an LRCLine for each timestamp in the line
            for match in matches {
                guard let timestamp = extractTimestamp(from: match, in: line) else { continue }
                let lrcline = LRCLine(timestamp: timestamp, text: lyricsText)
                parsedLines.append(lrcline)
            }
        }
        
        // Sort by timestamp and remove duplicates (same timestamp, keep first)
        let sortedLines = parsedLines.sorted { $0.timestamp < $1.timestamp }
        var uniqueLines: [LRCLine] = []
        var lastTimestamp: Double = -1
        
        for line in sortedLines {
            if line.timestamp != lastTimestamp {
                uniqueLines.append(line)
                lastTimestamp = line.timestamp
            }
        }
        
        return uniqueLines
    }
    
    /// Extracts timestamp from regex match
    /// - Parameters:
    ///   - match: NSTextCheckingResult containing the match
    ///   - string: The original string
    /// - Returns: Timestamp in seconds, or nil if parsing fails
    private static func extractTimestamp(from match: NSTextCheckingResult, in string: String) -> Double? {
        guard match.numberOfRanges >= 4 else { return nil }
        
        let minutesRange = match.range(at: 1)
        let secondsRange = match.range(at: 2)
        let millisecondsRange = match.range(at: 3)
        
        guard let minutes = Double(substring(from: minutesRange, in: string)),
              let seconds = Double(substring(from: secondsRange, in: string)),
              let millisecondsValue = Double(substring(from: millisecondsRange, in: string)) else {
            return nil
        }
        
        // Convert milliseconds (handle both 2-digit and 3-digit formats)
        let milliseconds = millisecondsValue < 100 ? millisecondsValue * 10 : millisecondsValue
        
        return minutes * 60 + seconds + milliseconds / 1000.0
    }
    
    /// Helper to extract substring from NSRange
    private static func substring(from range: NSRange, in string: String) -> String {
        guard let swiftRange = Range(range, in: string) else { return "" }
        return String(string[swiftRange])
    }
}

// MARK: - Lyrics Response Model
/// Response model for LRCLIB API
struct LRCLyricsResponse: Codable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String
    let duration: Double
    let instrumental: Bool
    let plainLyrics: String?
    let syncedLyrics: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case trackName = "trackName"
        case artistName = "artistName"
        case albumName = "albumName"
        case duration
        case instrumental
        case plainLyrics = "plainLyrics"
        case syncedLyrics = "syncedLyrics"
    }
}

// MARK: - Preview Data
extension LRCLine {
    static let preview: [LRCLine] = [
        LRCLine(timestamp: 0.0, text: "♪ Music Start ♪"),
        LRCLine(timestamp: 12.5, text: "Is this the real life?"),
        LRCLine(timestamp: 15.2, text: "Is this just fantasy?"),
        LRCLine(timestamp: 18.0, text: "Caught in a landslide"),
        LRCLine(timestamp: 21.5, text: "No escape from reality"),
        LRCLine(timestamp: 27.0, text: "Open your eyes"),
        LRCLine(timestamp: 30.0, text: "Look up to the skies and see"),
        LRCLine(timestamp: 36.0, text: "I'm just a poor boy, I need no sympathy"),
        LRCLine(timestamp: 42.0, text: "Because I'm easy come, easy go"),
        LRCLine(timestamp: 45.5, text: "Little high, little low"),
        LRCLine(timestamp: 49.0, text: "Any way the wind blows doesn't really matter to me")
    ]
}