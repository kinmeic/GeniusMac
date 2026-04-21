import SwiftUI

@main
struct GeniusMacApp: App {
    @StateObject private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup("Genius") {
            MainView()
                .environmentObject(viewModel)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 448, height: 190)
        .windowResizability(.contentSize)

        Window("设置", id: "settings") {
            SettingsView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 640, height: 560)
        .windowResizability(.contentSize)
    }
}
