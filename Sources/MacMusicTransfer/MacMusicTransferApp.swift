import SwiftUI
import MacMusicTransferKit

/// MacMusic Transfer Utility: one window (Stage 3, U1-U9).
@main
struct MacMusicTransferApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("MacMusic Transfer", id: "main") {
            MainWindowView(model: model)
                .onAppear { delegate.model = model }
                .background(WindowFinder { delegate.watch($0) })
        }
        .defaultSize(width: 760, height: 720)
        .windowResizability(.contentMinSize)
    }
}
