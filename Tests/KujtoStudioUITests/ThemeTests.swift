import XCTest
@testable import KujtoStudioUI

/// The ported theme model: five complete themes, stable lookup, and the
/// seven-token contract Glint defines.
final class ThemeTests: XCTestCase {
    func testFiveBuiltInThemes() {
        XCTAssertEqual(Themes.all.count, 5)
        XCTAssertEqual(Themes.all.map { $0.id },
                       ["aurora", "midnight", "sunset", "forest", "graphite"])
    }

    func testEveryThemeHasSevenNonEmptyTokens() {
        for theme in Themes.all {
            XCTAssertEqual(theme.tokens.all.count, 7, "\(theme.id) token count")
            for token in theme.tokens.all {
                XCTAssertTrue(token.hasPrefix("#"), "\(theme.id) token \(token) should be hex")
                XCTAssertFalse(token.isEmpty)
            }
        }
    }

    func testDefaultIsMidnight() {
        XCTAssertEqual(Themes.default.id, "midnight")
    }

    func testByIDFallsBackToDefault() {
        XCTAssertEqual(Themes.byID("forest").id, "forest")
        XCTAssertEqual(Themes.byID("does-not-exist").id, Themes.default.id)
    }

    func testLightAndDarkMix() {
        // Glint ships both light and dark themes; the set must contain each.
        XCTAssertTrue(Themes.all.contains { $0.isDark })
        XCTAssertTrue(Themes.all.contains { !$0.isDark })
    }
}
