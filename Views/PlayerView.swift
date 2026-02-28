import SwiftUI

/// Full-screen player view with artwork, controls, and synchronized lyrics
struct PlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: PlayerTab = .lyrics
    
    enum PlayerTab {
        case lyrics
        case queue
    }
    
    var body: some View {
        ZStack {
            // Dynamic gradient background based on artwork
            LinearGradient(
                colors: playerViewModel.backgroundColors + [
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Dismiss handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                    
                    // Header with dismiss button
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("Now Playing")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        // More options button
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Artwork
                    ArtworkView(
                        artwork: playerViewModel.artwork,
                        isPlaying: playerViewModel.isPlaying
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, 30)
                    
                    // Song Info
                    VStack(spacing: 8) {
                        Text(playerViewModel.songTitle)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                        
                        Text(playerViewModel.artistName)
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(.top, 30)
                    .padding(.horizontal, 40)
                    
                    // Progress Bar
                    VStack(spacing: 8) {
                        // Custom slider
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 4)
                                
                                // Progress fill
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * CGFloat(playerViewModel.progress), height: 4)
                                
                                // Draggable handle
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 12, height: 12)
                                    .offset(x: geometry.size.width * CGFloat(playerViewModel.progress) - 6)
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let percentage = min(max(value.location.x / geometry.size.width, 0), 1)
                                                playerViewModel.seekToPercentage(percentage)
                                            }
                                    )
                            }
                        }
                        .frame(height: 20)
                        
                        // Time labels
                        HStack {
                            Text(playerViewModel.formattedCurrentTime)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text(playerViewModel.formattedDuration)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 30)
                    
                    // Playback Controls
                    HStack(spacing: 40) {
                        // Shuffle Button
                        Button(action: { playerViewModel.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 22))
                                .foregroundColor(playerViewModel.isShuffleEnabled ? .pink : .white.opacity(0.7))
                        }
                        
                        // Previous Button
                        Button(action: { playerViewModel.skipToPrevious() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        
                        // Play/Pause Button
                        Button(action: { playerViewModel.togglePlayback() }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                
                                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.black)
                                    .offset(x: playerViewModel.isPlaying ? 0 : 2)
                            }
                        }
                        
                        // Next Button
                        Button(action: { playerViewModel.skipToNext() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        
                        // Repeat Button
                        Button(action: { playerViewModel.cycleRepeatMode() }) {
                            Image(systemName: playerViewModel.repeatMode.iconName)
                                .font(.system(size: 22))
                                .foregroundColor(playerViewModel.repeatMode != .none ? .pink : .white.opacity(0.7))
                        }
                    }
                    .padding(.top, 30)
                    
                    // Lyrics Section
                    LyricsPanel(
                        lyrics: playerViewModel.lyrics,
                        activeIndex: playerViewModel.activeLyricsIndex,
                        isLoading: playerViewModel.isLoadingLyrics
                    )
                    .frame(height: 280)
                    .padding(.top, 40)
                    
                    // Bottom padding for safe area
                    Spacer(minLength: 40)
                }
            }
        }
    }
}

// MARK: - Artwork View

struct ArtworkView: View {
    let artwork: UIImage?
    let isPlaying: Bool
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Shadow/glow effect
            if let artwork = artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 280, height: 280)
                    .blur(radius: 40)
                    .opacity(0.5)
            }
            
            // Main artwork
            if let artwork = artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 20)
            } else {
                ZStack {
                    Color.gray.opacity(0.3)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 280, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Vinyl record effect when playing
            if isPlaying {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: 20, height: 20)
                    )
            }
        }
    }
}

// MARK: - Lyrics Panel

struct LyricsPanel: View {
    let lyrics: [LRCLine]
    let activeIndex: Int
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Lyrics")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
            }
            .padding(.horizontal, 40)
            
            // Lyrics content
            if lyrics.isEmpty || (lyrics.count == 1 && lyrics[0].text == "Lyrics not found for this song.") {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text(lyrics.first?.text ?? "No lyrics available")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Synchronized lyrics
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            // Top spacer for centering
                            Spacer(minLength: 100)
                            
                            ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                                LyricLineView(
                                    text: line.text,
                                    isActive: index == activeIndex,
                                    isPast: index < activeIndex
                                )
                                .id(line.id)
                            }
                            
                            // Bottom spacer for centering
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 40)
                    }
                    .onChange(of: activeIndex) { newIndex in
                        // Auto-scroll to active line
                        if newIndex < lyrics.count {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lyrics[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Lyric Line View

struct LyricLineView: View {
    let text: String
    let isActive: Bool
    let isPast: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: isActive ? 22 : 18, weight: isActive ? .semibold : .regular))
            .foregroundColor(isActive ? .white : (isPast ? .white.opacity(0.4) : .white.opacity(0.6)))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .scaleEffect(isActive ? 1.05 : 1.0)
            .blur(radius: isActive ? 0 : (isPast ? 1 : 0.5))
            .animation(.easeInOut(duration: 0.3), value: isActive)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView(playerViewModel: PlayerViewModel())
            .preferredColorScheme(.dark)
    }
}