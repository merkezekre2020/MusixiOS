import SwiftUI

/// Main tab view containing the primary navigation structure of the app
/// Acts as the root view after app launch
struct MainTabView: View {
    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var selectedTab: Tab = .library
    @State private var showPlayerSheet = false
    
    enum Tab {
        case library
        case nowPlaying
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Library Tab
                LibraryView(playerViewModel: playerViewModel)
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }
                    .tag(Tab.library)
                
                // Now Playing Tab (shows mini player or placeholder)
                NowPlayingPlaceholderView(playerViewModel: playerViewModel)
                    .tabItem {
                        Label("Now Playing", systemImage: "play.circle.fill")
                    }
                    .tag(Tab.nowPlaying)
            }
            .tint(.pink)
            
            // Mini Player Overlay
            if playerViewModel.hasCurrentSong {
                VStack {
                    Spacer()
                    MiniPlayerView(playerViewModel: playerViewModel) {
                        showPlayerSheet = true
                    }
                    .padding(.bottom, 49) // Tab bar height
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .sheet(isPresented: $showPlayerSheet) {
            PlayerView(playerViewModel: playerViewModel)
        }
    }
}

/// Mini player shown at bottom of screen when a song is playing
struct MiniPlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork
                if let artwork = playerViewModel.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                } else {
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                }
                
                // Song Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(playerViewModel.songTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(playerViewModel.artistName)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Play/Pause Button
                Button(action: {
                    playerViewModel.togglePlayback()
                }) {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.pink)
                        .frame(width: 44, height: 44)
                }
                
                // Next Button
                Button(action: {
                    playerViewModel.skipToNext()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(
                // Progress bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.pink)
                        .frame(width: geometry.size.width * CGFloat(playerViewModel.progress), height: 2)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Placeholder view for the Now Playing tab when no song is selected
struct NowPlayingPlaceholderView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        ZStack {
            // Dynamic background
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.3),
                    Color.blue.opacity(0.2),
                    Color.black.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if playerViewModel.hasCurrentSong {
                // Show mini preview of current player
                VStack(spacing: 30) {
                    if let artwork = playerViewModel.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250, height: 250)
                            .cornerRadius(20)
                            .shadow(radius: 20)
                    } else {
                        ZStack {
                            Color.gray.opacity(0.3)
                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 250, height: 250)
                        .cornerRadius(20)
                    }
                    
                    VStack(spacing: 8) {
                        Text(playerViewModel.songTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(playerViewModel.artistName)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    // Playback controls
                    HStack(spacing: 40) {
                        Button(action: { playerViewModel.skipToPrevious() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 30))
                        }
                        
                        Button(action: { playerViewModel.togglePlayback() }) {
                            Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 70))
                        }
                        
                        Button(action: { playerViewModel.skipToNext() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 30))
                        }
                    }
                    .foregroundColor(.primary)
                }
                .padding()
            } else {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    Text("No Song Playing")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select a song from your library to start playing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}