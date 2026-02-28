import SwiftUI

/// Root content view of the application
/// Serves as the main entry point for the SwiftUI view hierarchy
struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}