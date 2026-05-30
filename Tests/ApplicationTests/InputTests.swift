import XCTest
@testable import Application
@testable import Domain

final class InputTests: XCTestCase {

    func testRecipientTrimsAndValidatesDigitsOnly() throws {
        let phone = try RecipientInput.phone(" 11234567890 ")

        XCTAssertEqual(phone, "11234567890")
    }

    func testRecipientRejectsLetters() {
        XCTAssertThrowsError(try RecipientInput.phone("1123abc")) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "recipient")
        }
    }

    func testRecipientRejectsNonASCIIDigits() {
        XCTAssertThrowsError(try RecipientInput.phone("１２３")) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "recipient")
        }
    }

    func testRecipientRejectsTooShortValue() {
        XCTAssertThrowsError(try RecipientInput.phone("123456")) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "recipient")
        }
    }

    func testRecipientRejectsTooLongValue() {
        XCTAssertThrowsError(try RecipientInput.phone("1234567890123456")) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "recipient")
        }
    }

    func testRequiredTextTrimsWhitespace() throws {
        let text = try TextInput.trimmedNonEmpty("  hello  ", field: "question")

        XCTAssertEqual(text, "hello")
    }

    func testRequiredTextRejectsEmptyValue() {
        XCTAssertThrowsError(try TextInput.trimmedNonEmpty("   ", field: "text")) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "text")
        }
    }

    func testTextContentAcceptsMixedBlocksAndDeduplicatesStyles() throws {
        let content = try TextInput.textContent([
            TextBlock(text: [
                TextRun(text: "Hello "),
                TextRun(text: "world", styles: [.bold, .italic, .bold])
            ]),
            TextBlock(type: .bullet, text: [
                TextRun(text: "Pay "),
                TextRun(text: "today", styles: [.bold])
            ])
        ])

        XCTAssertEqual(content[0].text[1].styles, [.bold, .italic])
        XCTAssertEqual(TextContent.plainText(content), "Hello world\nPay today")
    }

    func testClientMessageIdTrimsWhenPresent() throws {
        let clientMessageId = try IdentifierInput.clientMessageId(" cmid-1 ")

        XCTAssertEqual(clientMessageId, "cmid-1")
    }

    func testClientMessageIdAllowsMissingValue() throws {
        let clientMessageId = try IdentifierInput.clientMessageId(nil)

        XCTAssertNil(clientMessageId)
    }

    func testClientMessageIdRejectsBlankPresentValue() {
        XCTAssertThrowsError(try IdentifierInput.clientMessageId("   ")) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "client_message_id")
        }
    }

    func testTextContentAcceptsAllInlineStyleCombinations() throws {
        let styles = TextStyle.allCases
        for mask in 1 ..< (1 << styles.count) {
            let combination = styles.enumerated().compactMap { index, style in
                (mask & (1 << index)) == 0 ? nil : style
            }
            let content = try TextInput.textContent([
                TextBlock(text: [
                    TextRun(text: "hello", styles: combination)
                ])
            ])

            XCTAssertEqual(content[0].text[0].styles, combination)
        }
    }

    func testTextContentRejectsEmptyContent() {
        XCTAssertThrowsError(
            try TextInput.textContent([])
        ) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "content")
        }
    }

    func testTextContentRejectsEmptyRunText() {
        XCTAssertThrowsError(
            try TextInput.textContent([TextBlock(text: [TextRun(text: "")])])
        ) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "content[0].text[0].text")
        }
    }

    func testTextContentRejectsBlankJoinedContent() {
        XCTAssertThrowsError(
            try TextInput.textContent([
                TextBlock(text: [TextRun(text: "   ")]),
                TextBlock(type: .quote, text: [TextRun(text: "\t")])
            ])
        ) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "content")
        }
    }

    func testPageSizeAcceptsBoundariesAndRejectsOutsideRange() throws {
        XCTAssertEqual(try NumberInput.pageSize(nil), 50)
        XCTAssertEqual(try NumberInput.pageSize(1), 1)
        XCTAssertEqual(try NumberInput.pageSize(100), 100)

        XCTAssertThrowsError(try NumberInput.pageSize(0)) { error in
            XCTAssertEqual((error as? DomainError)?.context["field"], "page_size")
        }

        XCTAssertThrowsError(try NumberInput.pageSize(101)) { error in
            XCTAssertEqual((error as? DomainError)?.context["field"], "page_size")
        }
    }

    func testNonNegativeIndexesRejectsEmptyNegativeAndDuplicateValues() throws {
        XCTAssertEqual(
            try NumberInput.nonNegativeIndexes([0, 2], field: "choice_indexes"),
            [0, 2]
        )

        for indexes in [[], [-1], [0, 0]] {
            XCTAssertThrowsError(
                try NumberInput.nonNegativeIndexes(indexes, field: "choice_indexes")
            ) { error in
                XCTAssertEqual((error as? DomainError)?.context["field"], "choice_indexes")
            }
        }
    }

    func testDateRangeRejectsAfterAtOrLaterThanBefore() throws {
        try TimeInput.validateDateRange(
            before: Date(timeIntervalSince1970: 20),
            after: Date(timeIntervalSince1970: 10)
        )

        for after in [
            Date(timeIntervalSince1970: 20),
            Date(timeIntervalSince1970: 30),
        ] {
            XCTAssertThrowsError(
                try TimeInput.validateDateRange(
                    before: Date(timeIntervalSince1970: 20),
                    after: after
                )
            ) { error in
                XCTAssertEqual((error as? DomainError)?.context["field"], "after")
            }
        }
    }

    func testFutureDateRejectsPastDate() {
        XCTAssertThrowsError(
            try TimeInput.futureDate(
                Date(timeIntervalSince1970: 10),
                now: Date(timeIntervalSince1970: 20),
                field: "closes_at"
            )
        ) { error in
            guard let domainError = error as? DomainError else {
                return XCTFail("expected DomainError")
            }

            XCTAssertEqual(domainError.code, .invalidArgument)
            XCTAssertEqual(domainError.context["field"], "closes_at")
        }
    }

}
