import Foundation
import XCTest
@testable import LookAway

final class UpdateTests: XCTestCase {
    func testSemanticVersionComparison() {
        XCTAssertLessThan(ReleaseVersion("1.0.9"), ReleaseVersion("1.0.10"))
        XCTAssertLessThan(ReleaseVersion("1.9"), ReleaseVersion("2.0.0"))
        XCTAssertEqual(ReleaseVersion("1.2"), ReleaseVersion("1.2.0"))
        XCTAssertFalse(ReleaseVersion("2.0") < ReleaseVersion("1.99.99"))
    }

    func testManifestDecoding() throws {
        let json = Data(#"{"version":"1.0.7","url":"https://github.com/longnt27/lookaway/releases/download/v1.0.7/LookAway-1.0.7.zip","sha256":"abc123"}"#.utf8)
        let manifest = try JSONDecoder().decode(ReleaseManifest.self, from: json)
        XCTAssertEqual(manifest.version, "1.0.7")
        XCTAssertEqual(manifest.sha256, "abc123")
        XCTAssertEqual(manifest.url.host, "github.com")
    }
}
