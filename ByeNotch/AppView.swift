import SwiftUI

struct AppView: View {
    
    @State var isNotchHidden = false
    @Environment(\.openURL) var openURL
    
    var body: some View {
        
        Button() {
            isNotchHidden.toggle()
            NotchManager.shared.toggleNotch(hideNotch: isNotchHidden)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}


