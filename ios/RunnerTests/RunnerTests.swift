import Flutter
import UIKit
import XCTest
@testable import Runner

// These native tests are provided for Xcode. They have NOT run on the Linux host.
class RunnerTests: XCTestCase {
  func testClassicFlutterBootstrapAndBrand() {
    XCTAssertTrue(UIApplication.shared.delegate is AppDelegate)
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "alo")
    XCTAssertNotNil((UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController as? FlutterViewController)
  }
  func testMicrophonePermissionIsExplained() {
    let description = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String
    XCTAssertNotNil(description)
    XCTAssertTrue(description?.contains("تراکنش مالی") == true)
  }
  func testPrivacyManifestIsBundled() {
    XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
  }
}
