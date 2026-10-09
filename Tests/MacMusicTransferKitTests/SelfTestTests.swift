import Foundation
import Testing
@testable import MacMusicTransferKit

/// The self-test's own WAVs (R4) are in MacMusic's format; run outside
/// the packaged app, it refuses rather than using the development tools.
@Suite struct SelfTestTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    @Test func itsTonesAreMacMusicWAVs() throws {
        let url = f.url("tone.wav")
        try SelfTest.tone(seconds: 1, hertz: 440).write(to: url)
        #expect(MacMusicWAVValidator.check(url).accepted)
    }

    @Test func onlyInThePackagedApp() async {
        #expect(!Bundled.isApp)
        let (passed, report) = await SelfTest.run(helpers: Bundled.helpers, template: Bundled.template)
        #expect(!passed)
        #expect(report.last == "FAIL: not run from the packaged app")
    }
}
