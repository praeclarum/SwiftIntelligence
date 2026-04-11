import XCTest
import FoundationModels
@testable import SwiftIntelligence

final class TranscriptSerializationTests: XCTestCase {

    func testTranscriptGetJSONProducesValidJSON() throws {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "test"))],
                options: GenerationOptions(),
                responseFormat: nil)),
            .response(Transcript.Response(
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(content: "result"))])),
        ])
        let json = try transcript.getJSON()
        XCTAssertFalse(json.isEmpty)
        let data = json.data(using: .utf8)
        XCTAssertNotNil(data)
        let parsed = try JSONSerialization.jsonObject(with: data!)
        XCTAssertTrue(parsed is [String: Any] || parsed is [Any])
    }

    func testTranscriptJsonProperty() {
        let transcript = Transcript(entries: [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "hello"))],
                options: GenerationOptions(),
                responseFormat: nil)),
        ])
        let json = transcript.json
        XCTAssertFalse(json.isEmpty)
        XCTAssertNotEqual(json, "{}")
    }

    func testEmptyTranscriptSerializes() throws {
        let transcript = Transcript(entries: [])
        let json = try transcript.getJSON()
        XCTAssertFalse(json.isEmpty)
    }
}
