import Foundation
import XCTest
import KikoNotchKit

final class KikoTestObserver: NSObject, XCTestObservation {
    var passedCount = 0
    var failedCount = 0

    func testCaseDidFinish(_ testCase: XCTestCase) {
        if testCase.testRun?.hasSucceeded == true {
            passedCount += 1
            print("  ✔ [PASS] \(testCase.name)")
        } else {
            failedCount += 1
            print("  ✖ [FAIL] \(testCase.name)")
        }
    }
}

print("=================================================================")
print("             KIKO NOTCH AUTOMATED TEST SUITE RUNNER              ")
print("=================================================================")

// Ensure AppKit environment is active
_ = NSApplication.shared

let observer = KikoTestObserver()
XCTestObservationCenter.shared.addTestObserver(observer)

let testClasses: [XCTestCase.Type] = [
    ThemeTests.self,
    CoreUXTests.self,
    MediaTests.self,
    FileShelfTests.self,
    StorageTests.self,
    ClipboardTests.self,
    ExtensionAndFeatureTests.self,
    ProductivityTests.self,
    DownloadMonitoringTests.self,
    BatteryAndSensorsTests.self,
    UsageRepositoryTests.self,
    WeatherTests.self,
    SystemIntegrationTests.self,
    AIProviderTests.self,
    NavigationTests.self,
    SystemMetricsTests.self,
    SystemActivityTests.self,
    WakaTimeTests.self,
    AIDashboardTests.self
]

var totalTests = 0
var totalFailures = 0

for testClass in testClasses {
    let suiteName = String(describing: testClass)
    print("\n--- Running Suite: \(suiteName) ---")
    let suite = XCTestSuite(forTestCaseClass: testClass)
    suite.run()

    if let run = suite.testRun {
        totalTests += Int(run.testCaseCount)
        totalFailures += Int(run.totalFailureCount)
    }
}

print("\n=================================================================")
print("                       TEST RUN SUMMARY                          ")
print("=================================================================")
print("Total Test Suites: \(testClasses.count)")
print("Total Tests Run:   \(totalTests)")
print("Passed:            \(totalTests - totalFailures)")
print("Failed:            \(totalFailures)")
print("=================================================================")

if totalFailures > 0 {
    print("❌ SOME TESTS FAILED.")
    exit(1)
} else {
    print("✅ ALL TESTS PASSED SUCCESSFULLY.")
    exit(0)
}
