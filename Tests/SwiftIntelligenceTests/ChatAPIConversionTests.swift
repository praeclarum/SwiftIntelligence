import XCTest
import FoundationModels
@testable import SwiftIntelligence

final class ChatAPIConversionTests: XCTestCase {

    private func makeSession() -> ChatAPISessionImplementation {
        ChatAPISessionImplementation(
            model: "test", baseURL: "https://example.com/v1",
            apiKey: "fake", tools: [], instructions: nil)
    }

    func testBuildMessagesFromInstructions() {
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(
                segments: [.text(Transcript.TextSegment(content: "System prompt"))],
                toolDefinitions: []))
        ]
        let messages = makeSession().buildMessages(from: entries)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[0].content, "System prompt")
    }

    func testBuildMessagesFromPrompt() {
        let entries: [Transcript.Entry] = [
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "Hi"))],
                options: GenerationOptions(),
                responseFormat: nil))
        ]
        let messages = makeSession().buildMessages(from: entries)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].role, "user")
        XCTAssertEqual(messages[0].content, "Hi")
    }

    func testBuildMessagesFromResponse() {
        let entries: [Transcript.Entry] = [
            .response(Transcript.Response(
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(content: "I'm fine"))]))
        ]
        let messages = makeSession().buildMessages(from: entries)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].role, "assistant")
        XCTAssertEqual(messages[0].content, "I'm fine")
    }

    func testBuildMessagesFromToolOutput() {
        let entries: [Transcript.Entry] = [
            .toolOutput(Transcript.ToolOutput(
                id: "call-123",
                toolName: "my_tool",
                segments: [.text(Transcript.TextSegment(content: "{\"result\": 42}"))]))
        ]
        let messages = makeSession().buildMessages(from: entries)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].role, "tool")
        XCTAssertEqual(messages[0].tool_call_id, "call-123")
        XCTAssertEqual(messages[0].name, "my_tool")
        XCTAssertEqual(messages[0].content, "{\"result\": 42}")
    }

    func testBuildMessagesMultiEntryConversation() {
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(
                segments: [.text(Transcript.TextSegment(content: "Be brief"))],
                toolDefinitions: [])),
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "Hello"))],
                options: GenerationOptions(),
                responseFormat: nil)),
            .response(Transcript.Response(
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(content: "Hi"))])),
            .prompt(Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "Bye"))],
                options: GenerationOptions(),
                responseFormat: nil)),
        ]
        let messages = makeSession().buildMessages(from: entries)
        XCTAssertEqual(messages.count, 4)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[1].role, "user")
        XCTAssertEqual(messages[2].role, "assistant")
        XCTAssertEqual(messages[3].role, "user")
    }

    func testBuildMessagesEmptyInstructionsSkipped() {
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(segments: [], toolDefinitions: []))
        ]
        let messages = makeSession().buildMessages(from: entries)
        XCTAssertEqual(messages.count, 0, "Empty instruction text should produce no message")
    }
}
