import XCTest
import FoundationModels
@testable import SwiftIntelligence

final class OpenAIAPITests: XCTestCase {

    private func apiKey() throws -> String {
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set — skipping OpenAI API tests")
        }
        return key
    }

    func testSimpleTextResponse() async throws {
        let key = try apiKey()
        IntelligenceModel.openAIApiKey = key
        let session = IntelligenceSession(model: .openAI(model: "gpt-4o-mini"))
        let response = try await session.respond(to: "What is 2+2? Answer with just the number.")
        XCTAssertTrue(response.contains("4"), "Expected '4' in response: \(response)")
    }

    func testTranscriptAfterResponse() async throws {
        let key = try apiKey()
        IntelligenceModel.openAIApiKey = key
        let session = IntelligenceSession(model: .openAI(model: "gpt-4o-mini"))
        _ = try await session.respond(to: "Say hi")
        let json = try session.transcript.getJSON()
        XCTAssertFalse(json.isEmpty)
    }
}
