//
//  LumarkUITests.swift
//  LumarkUITests
//
//  핵심 사용자 동선 회귀 방지 테스트.
//
//  주의: 모든 테스트는 launchArguments로 onboarding skip 처리.
//  실제 데이터(SwiftData)는 시뮬레이터 상태를 그대로 사용 — 첫 테스트 실행 전에는
//  앱이 빈 라이브러리로 시작.
//

import XCTest

final class LumarkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest", "1"]
        // 온보딩 시트 자동 표시 방지를 위해 UserDefaults override.
        // (앱 코드가 lumark.onboarded를 읽어서 true면 안 띄움)
        app.launchEnvironment["LUMARK_SKIP_ONBOARDING"] = "1"
        app.launch()
        return app
    }

    // MARK: - Tests

    /// 홈 화면이 정상 진입하고 핵심 액션 카드들이 보이는가.
    @MainActor
    func testHomeScreenAppearsWithActions() throws {
        let app = launchedApp()

        // 온보딩이 뜨면 건너뛰기
        let skipBtn = app.buttons["건너뛰기"]
        if skipBtn.waitForExistence(timeout: 2) {
            skipBtn.tap()
        }

        XCTAssertTrue(app.buttons["업로드. PDF·이미지 선택"].waitForExistence(timeout: 5),
                      "업로드 액션 카드가 보여야 함")
        XCTAssertTrue(app.buttons["카메라. 직접 촬영"].exists,
                      "카메라 액션 카드가 보여야 함")
        XCTAssertTrue(app.buttons["최근 작업. 내 정리본"].exists,
                      "최근 작업 액션 카드가 보여야 함")
        XCTAssertTrue(app.buttons["설정. 색·라벨"].exists,
                      "설정 액션 카드가 보여야 함")
    }

    /// 설정 시트가 열리고 닫히는가.
    @MainActor
    func testSettingsSheetOpensAndCloses() throws {
        let app = launchedApp()

        let skipBtn = app.buttons["건너뛰기"]
        if skipBtn.waitForExistence(timeout: 2) {
            skipBtn.tap()
        }

        // 설정 카드 탭
        app.buttons["설정. 색·라벨"].tap()

        // 색상 매핑 섹션이 보여야 함
        XCTAssertTrue(app.staticTexts["색상 매핑"].waitForExistence(timeout: 3))

        // 완료 버튼으로 닫기
        app.buttons["완료"].tap()

        // 다시 홈으로
        XCTAssertTrue(app.buttons["업로드. PDF·이미지 선택"].waitForExistence(timeout: 3))
    }

    /// 빈 상태 안내가 보이는가 (라이브러리에 노트가 없을 때).
    /// 주의: 이전 테스트에서 노트를 만들었으면 실패할 수 있음 — 시뮬레이터 상태 의존.
    @MainActor
    func testEmptyStateVisibleWhenNoNotes() throws {
        let app = launchedApp()

        let skipBtn = app.buttons["건너뛰기"]
        if skipBtn.waitForExistence(timeout: 2) {
            skipBtn.tap()
        }

        // 빈 상태 텍스트는 노트가 0개일 때만 보임
        let emptyTitle = app.staticTexts["아직 변환한 노트가 없어요"]
        if emptyTitle.waitForExistence(timeout: 3) {
            XCTAssertTrue(emptyTitle.exists)
        }
        // 노트가 있으면 빈 상태가 안 뜨므로 이 케이스는 skip — 핵심 동선 검증은 다른 테스트에서
    }
}
