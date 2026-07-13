import XCTest
@testable import KujtoCore

final class LocalizationAuditTests: XCTestCase {

    private func audit(_ json: String, locale: String = "sq") throws -> [LocalizationFinding] {
        try LocalizationAudit.audit(catalogData: Data(json.utf8), locale: locale)
    }

    func testMissingTranslationIsReported() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "strings": {
            "Hello": { "localizations": {} }
          }
        }
        """
        let findings = try audit(json)
        XCTAssertEqual(findings, [LocalizationFinding(key: "Hello", locale: "sq", kind: .missing)])
    }

    func testTranslatedKeyIsClean() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "strings": {
            "Hello": {
              "localizations": {
                "sq": { "stringUnit": { "state": "translated", "value": "Përshëndetje" } }
              }
            }
          }
        }
        """
        XCTAssertTrue(try audit(json).isEmpty)
    }

    func testNeedsReviewIsReported() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "strings": {
            "Bye": {
              "localizations": {
                "sq": { "stringUnit": { "state": "needs_review", "value": "Mirupafshim" } }
              }
            }
          }
        }
        """
        let findings = try audit(json)
        XCTAssertEqual(findings.map { $0.kind }, [.needsReview])
    }

    func testPlaceholderMismatchIsReported() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "strings": {
            "%lld items by %@": {
              "localizations": {
                "sq": { "stringUnit": { "state": "translated", "value": "%@ artikuj" } }
              }
            }
          }
        }
        """
        let findings = try audit(json)
        XCTAssertEqual(findings.map { $0.kind }, [.placeholderMismatch])
    }

    func testMatchingPlaceholdersInAnyOrderAreClean() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "strings": {
            "%1$@ sent %2$lld": {
              "localizations": {
                "sq": { "stringUnit": { "state": "translated", "value": "%2$lld nga %1$@" } }
              }
            }
          }
        }
        """
        XCTAssertTrue(try audit(json).isEmpty)
    }

    func testShouldTranslateFalseIsSkipped() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "strings": {
            "BrandName": { "shouldTranslate": false, "localizations": {} }
          }
        }
        """
        XCTAssertTrue(try audit(json).isEmpty)
    }

    func testAuditingSourceLanguageReturnsNothing() throws {
        let json = """
        {
          "sourceLanguage": "en",
          "strings": { "Hello": { "localizations": {} } }
        }
        """
        XCTAssertTrue(try audit(json, locale: "en").isEmpty)
    }

    func testInvalidCatalogThrows() {
        XCTAssertThrowsError(try audit("not json"))
    }

    func testFormatSpecifierExtractionIgnoresEscapedPercent() {
        XCTAssertEqual(LocalizationAudit.formatSpecifiers(in: "100%% done with %@"), ["%@"])
    }
}
