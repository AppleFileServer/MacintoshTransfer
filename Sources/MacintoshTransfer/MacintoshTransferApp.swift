import SwiftUI
import MacintoshTransferKit

/// Macintosh Transfer Utility: one window (Stage 3, U1-U9).
@main
struct MacintoshTransferApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    /// `--self-test` (R4): no window; the app's own hfsutils and template
    /// only; prints the report and quits, 0 if it passed.
    init() {
        guard CommandLine.arguments.contains("--self-test") else { return }
        Task.detached {
            let (passed, report) = await SelfTest.run(helpers: Bundled.helpers, template: Bundled.template)
            for line in report { print(line) }
            exit(passed ? 0 : 1)
        }
        DispatchSemaphore(value: 0).wait()          // until the test exits
    }

    var body: some Scene {
        Window("Macintosh Transfer", id: "main") {
            MainWindowView(model: model)
                .onAppear { delegate.model = model }
                .background(WindowFinder { delegate.watch($0) })
        }
        .defaultSize(width: 760, height: 720)
        .windowResizability(.contentMinSize)
    }
}
