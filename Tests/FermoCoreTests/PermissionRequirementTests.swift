import XCTest
@testable import FermoCore

final class PermissionRequirementTests: XCTestCase {
    func testOnlyWebsiteFilterIsRequired() {
        XCTAssertTrue(PermissionKind.websiteFilter.isRequired)
        XCTAssertFalse(PermissionKind.loginItem.isRequired)
        XCTAssertFalse(PermissionKind.notifications.isRequired)
        XCTAssertFalse(PermissionKind.accessibility.isRequired)
    }

    func testIsReadyRequiresWebsiteFilterOnly() {
        let progress = OnboardingProgress(statuses: [
            PermissionStatus(kind: .websiteFilter, state: .satisfied),
            PermissionStatus(kind: .loginItem, state: .needsApproval),
            PermissionStatus(kind: .notifications, state: .notDetermined),
            PermissionStatus(kind: .accessibility, state: .unavailable)
        ])
        XCTAssertTrue(progress.isReady)
        XCTAssertFalse(progress.isFullyGranted)
        XCTAssertEqual(progress.satisfiedCount, 1)
        XCTAssertEqual(progress.totalCount, 4)
    }

    func testNotReadyWhenWebsiteFilterMissing() {
        let progress = OnboardingProgress(statuses: [
            PermissionStatus(kind: .websiteFilter, state: .needsApproval),
            PermissionStatus(kind: .loginItem, state: .satisfied)
        ])
        XCTAssertFalse(progress.isReady)
    }

    func testFullyGrantedWhenAllSatisfied() {
        let progress = OnboardingProgress(statuses: PermissionKind.allCases.map {
            PermissionStatus(kind: $0, state: .satisfied)
        })
        XCTAssertTrue(progress.isReady)
        XCTAssertTrue(progress.isFullyGranted)
    }
}
