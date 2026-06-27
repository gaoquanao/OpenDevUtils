import SwiftUI

@main
struct devUtilsApp: App {
    init() {
        disableSmartQuotesSystemWide()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 900, height: 600)
    }
}
