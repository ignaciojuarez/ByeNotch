import SwiftUI

struct AppView: View {
    
    @State var isNotchRemoved = false
    @Environment(\.openURL) var openURL
    
    var body: some View {
        
        Button(action: {
        isNotchRemoved.toggle()
        RemoveNotch()
        }) { Text(isNotchRemoved ? "Hi Notch" : "Bye Notch")}
            
        Divider()
            
        Button(action: About, label: { Text("About") })
        Button(action: QuitApp, label: { Text("Quit") })
    }
    
    func About() {
        if let url = URL(string: "https://www.ignaciojuarez.com") {
            openURL(url)
        }
    }
    
    func RemoveNotch() {
        let result = isNotchRemoved ? getModdedResolution() : getDefaultResolution()
        if result != ("No", "Match") {
            changeResolution(width: result.0, height: result.1)
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


