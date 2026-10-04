import XCTest
@testable import OpenDevUtils

/// Localization tests: format strings must work with arguments in all four
/// languages (regression guard for the variadic `L()` forwarding) and the
/// keys introduced by the performance/bug fixes must exist everywhere.
final class L10nTests: XCTestCase {

    private var savedLanguage: AppLanguage = LanguageManager.shared.language

    override func tearDown() {
        LanguageManager.shared.language = savedLanguage
        super.tearDown()
    }

    // MARK: - Format arguments

    func testTwoIntegerArgumentsAreFormatted() {
        for language in AppLanguage.allCases {
            LanguageManager.shared.language = language
            let message = L(.jsonTooLarge, 5, 50)
            XCTAssertTrue(message.contains("5"), "\(language): \(message)")
            XCTAssertTrue(message.contains("50"), "\(language): \(message)")
            XCTAssertFalse(message.contains("["), "array must not leak into format args: \(language): \(message)")
            XCTAssertFalse(message.contains("%d"), "unsubstituted placeholder: \(language): \(message)")
        }
    }

    func testOneStringArgumentIsFormatted() {
        for language in AppLanguage.allCases {
            LanguageManager.shared.language = language
            let message = L(.cronAt, "15")
            XCTAssertTrue(message.contains("15"), "\(language): \(message)")
            XCTAssertFalse(message.contains("%@"), "\(language): \(message)")
        }
    }

    // MARK: - Keys added by this round of fixes

    func testOutputTruncatedExistsInAllLanguages() {
        for language in AppLanguage.allCases {
            LanguageManager.shared.language = language
            let message = L(.outputTruncated, 100, 5000)
            XCTAssertFalse(message.isEmpty, "\(language)")
            XCTAssertTrue(message.contains("100"), "\(language): \(message)")
            XCTAssertTrue(message.contains("5000"), "\(language): \(message)")
            XCTAssertFalse(message.contains("%d"), "\(language): \(message)")
        }
    }

    func testInputTooLargeExistsInAllLanguages() {
        for language in AppLanguage.allCases {
            LanguageManager.shared.language = language
            let message = L(.inputTooLarge, 20, 50)
            XCTAssertTrue(message.contains("20"), "\(language): \(message)")
            XCTAssertTrue(message.contains("50"), "\(language): \(message)")
            XCTAssertFalse(message.contains("%d"), "\(language): \(message)")
        }
    }

    func testBase64NotTextExistsInAllLanguages() {
        for language in AppLanguage.allCases {
            LanguageManager.shared.language = language
            let message = L(.base64NotText)
            XCTAssertFalse(message.isEmpty, "\(language)")
            XCTAssertFalse(message.contains("%"), "\(language): \(message)")
        }
    }

    func testInvalidBase64ExistsInAllLanguages() {
        for language in AppLanguage.allCases {
            LanguageManager.shared.language = language
            XCTAssertFalse(L(.invalidBase64).isEmpty, "\(language)")
        }
    }

    // MARK: - Keys added by the second round of fixes

    private var newKeys: [LocalizedString] = [
        .copied, .noQRCodeFound, .clipboardHasNoImage, .tooManyMatches,
        .regexTooSlow, .invalidPercentEncoding, .urlNotFound,
    ]

    func testSecondRoundKeysExistInAllLanguages() {
        for language in AppLanguage.allCases {
            LanguageManager.shared.language = language
            for key in newKeys {
                let message = L(key)
                XCTAssertFalse(message.isEmpty, "\(language) \(key)")
                XCTAssertFalse(message.contains("%") && !message.contains("%d") && !message.contains("%@"),
                               "unsubstituted placeholder in \(language) \(key): \(message)")
            }
        }
    }

    func testTooManyMatchesFormatsCount() {
        for language in AppLanguage.allCases {
            LanguageManager.shared.language = language
            let message = L(.tooManyMatches, 500)
            XCTAssertTrue(message.contains("500"), "\(language): \(message)")
            XCTAssertFalse(message.contains("%d"), "\(language): \(message)")
        }
    }
}
