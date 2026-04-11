import XCTest
@testable import SwiftIntelligence

final class StripCodeFencesTests: XCTestCase {

    func testJsonFenceStripped() {
        let input = "```json\n{\"a\": 1}\n```"
        XCTAssertEqual(stripCodeFences(input), "{\"a\": 1}")
    }

    func testPlainFenceStripped() {
        let input = "```\n{\"a\": 1}\n```"
        XCTAssertEqual(stripCodeFences(input), "{\"a\": 1}")
    }

    func testNoFencePassthrough() {
        let input = "{\"a\": 1}"
        XCTAssertEqual(stripCodeFences(input), "{\"a\": 1}")
    }

    func testOnlyOpeningFence() {
        let input = "```json\n{\"a\": 1}"
        XCTAssertEqual(stripCodeFences(input), "{\"a\": 1}")
    }

    func testOnlyClosingFence() {
        let input = "{\"a\": 1}\n```"
        XCTAssertEqual(stripCodeFences(input), "{\"a\": 1}")
    }

    func testWhitespaceAroundFences() {
        let input = "  \n```json\n  {\"a\": 1}  \n```  \n  "
        let result = stripCodeFences(input)
        XCTAssertEqual(result, "{\"a\": 1}")
    }

    func testEmptyString() {
        XCTAssertEqual(stripCodeFences(""), "")
    }

    func testFencesOnly() {
        XCTAssertEqual(stripCodeFences("```json\n```"), "")
    }
}
