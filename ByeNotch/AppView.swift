import SwiftUI

@MainActor
struct AppView: View {
    
    @State var isNotchHidden = false
    @Environment(\.openURL) var openURL
    let notch = NotchManager()
    
    var body: some View {
        
        Button() {
            isNotchHidden.toggle()
            
            Task(priority: .high) {
                try await notch.toggleNotch(hideNotch: isNotchHidden)
            }
        } label: {
            Text(isNotchHidden ? "Hi Notch" : "Bye Notch")
        }
            
        Divider()
            
        Button(action: About, label: { Text("About") })
        Button(action: QuitApp, label: { Text("Quit") })
    }
    
    func About() {
        if let url = URL(string: "https://www.ignaciojuarez.com") {
            openURL(url)
        }
    }
    
    func QuitApp() {
        NSApplication.shared.terminate(nil)
    }
    
}

#Preview {
    AppView()
}
