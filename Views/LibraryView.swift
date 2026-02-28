import SwiftUI
import MediaPlayer

/// Library view displaying all songs with search functionality
struct LibraryView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel = LibraryViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $viewModel.searchQuery)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    // Content
                    if viewModel.isLoading {
                        LoadingView()
                    } else if let error = viewModel.errorMessage {
                        ErrorView(message: error) {
                            await viewModel.loadSongs()
                        }
                    } else if viewModel.filteredSongs.isEmpty {
                        EmptyLibraryView(
                            hasPermission: viewModel.authorizationStatus == .authorized,
                            isSearching: !viewModel.searchQuery.isEmpty
                        )
                    } else {
                        SongListView(
                            songs: viewModel.filteredSongs,
                            currentSong: playerViewModel.currentSong,
                            isPlaying: playerViewModel.isPlaying,
                            onSongSelected: { song in
                                handleSongSelected(song)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadSongs()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await viewModel.requestAuthorizationAndLoad()
        }
        .alert("Permission Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Please allow access to your music library in Settings to use this app.")
        }
    }
    
    /// Handle song selection from the list
    private func handleSongSelected(_ song: Song) {
        // If selecting a different song, set queue and play
        if playerViewModel.currentSong?.id != song.id {
            playerViewModel.setQueue(viewModel.filteredSongs, startIndex: viewModel.filteredSongs.firstIndex(where: { $0.id == song.id }) ?? 0)
        }
        playerViewModel.play(song: song)
    }
}

// MARK: - ViewModel

/// ViewModel for LibraryView managing data and state
@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var filteredSongs: [Song] = []
    @Published var searchQuery: String = "" {
        didSet {
            filterSongs()
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert: Bool = false
    
    private let musicProvider: MusicProviderProtocol
    
    init(musicProvider: MusicProviderProtocol = MusicProvider.shared) {
        self.musicProvider = musicProvider
        self.authorizationStatus = musicProvider.authorizationStatus
    }
    
    /// Request authorization and load songs if authorized
    func requestAuthorizationAndLoad() async {
        let status = await musicProvider.requestAuthorization()
        authorizationStatus = status
        
        switch status {
        case .authorized:
            await loadSongs()
        case .denied, .restricted:
            showPermissionAlert = true
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    /// Load songs from music library
    func loadSongs() async {
        isLoading = true
        errorMessage = nil
        
        do {
            songs = try await musicProvider.fetchSongs()
            filterSongs()
            isLoading = false
        } catch MusicProviderError.unauthorized {
            errorMessage = "Please allow access to your music library."
            isLoading = false
        } catch MusicProviderError.denied {
            errorMessage = "Access to music library was denied. Please enable it in Settings."
            isLoading = false
        } catch MusicProviderError.noSongsFound {
            errorMessage = nil // Show empty state
            songs = []
            filteredSongs = []
            isLoading = false
        } catch {
            errorMessage = "Failed to load songs: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Filter songs based on search query
    private func filterSongs() {
        if searchQuery.isEmpty {
            filteredSongs = songs
        } else {
            let query = searchQuery.lowercased()
            filteredSongs = songs.filter { song in
                song.title.lowercased().contains(query) ||
                song.artist.lowercased().contains(query) ||
                song.album.lowercased().contains(query)
            }
        }
    }
}

// MARK: - Subviews

/// Search bar component
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search songs, artists, albums...", text: $text)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

/// Song list view
struct SongListView: View {
    let songs: [Song]
    let currentSong: Song?
    let isPlaying: Bool
    let onSongSelected: (Song) -> Void
    
    var body: some View {
        List {
            ForEach(songs) { song in
                SongRowView(
                    song: song,
                    isPlaying: currentSong?.id == song.id && isPlaying,
                    isCurrentSong: currentSong?.id == song.id
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onSongSelected(song)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

/// Individual song row
struct SongRowView: View {
    let song: Song
    let isPlaying: Bool
    let isCurrentSong: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artwork = song.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(6)
            }
            
            // Song Info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 16, weight: isCurrentSong ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundColor(isCurrentSong ? .pink : .primary)
                
                Text("\(song.artist) • \(song.album)")
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Playing indicator or duration
            if isPlaying {
                PlayingIndicator()
                    .frame(width: 20, height: 20)
            } else {
                Text(song.formattedDuration)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Animated playing indicator
struct PlayingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.pink)
                    .frame(width: 3, height: animating ? 16 : 6)
                    .animation(
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            animating = true
        }
    }
}

/// Loading view
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your music...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Error view with retry button
struct ErrorView: View {
    let message: String
    let onRetry: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                Task {
                    await onRetry()
                }
            }
            .buttonStyle(.bordered)
            .tint(.pink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Empty library view
struct EmptyLibraryView: View {
    let hasPermission: Bool
    let isSearching: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isSearching ? "magnifyingglass" : "music.note.list")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            
            if isSearching {
                Text("No Results")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if hasPermission {
                Text("No Songs Found")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Add music to your library using the Music app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Permission Required")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Allow access to your music library to see your songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView(playerViewModel: PlayerViewModel())
    }
}