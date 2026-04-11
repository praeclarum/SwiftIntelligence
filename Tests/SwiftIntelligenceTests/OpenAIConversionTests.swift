import XCTest
import FoundationModels
@testable import SwiftIntelligence

final class OpenAIConversionTests: XCTestCase {

    func testTextSegmentConvertsToOpenAIContent() {
        let segment = Transcript.Segment.text(Transcript.TextSegment(content: "hello"))
        let content = segment.openAIContent
        XCTAssertNotNil(content)
        XCTAssertEqual(content?.type, "input_text")
        XCTAssertEqual(content?.text, "hello")
    }

    func testInstructionsEntryConvertsToOpenAIMessage() {
        let entry = Transcript.Entry.instructions(
            Transcript.Instructions(
                segments: [.text(Transcript.TextSegment(content: "Be helpful"))],
                toolDefinitions: []))
        let message = entry.openAIMessage
        XCTAssertEqual(message.role, "developer")
        XCTAssertEqual(message.type, "message")
        XCTAssertEqual(message.content?.count, 1)
        XCTAssertEqual(message.content?.first?.text, "Be helpful")
    }

    func testPromptEntryConvertsToOpenAIMessage() {
        let entry = Transcript.Entry.prompt(
            Transcript.Prompt(
                segments: [.text(Transcript.TextSegment(content: "What is 2+2?"))],
                options: GenerationOptions(),
                responseFormat: nil))
        let message = entry.openAIMessage
        XCTAssertEqual(message.role, "user")
        XCTAssertEqual(message.type, "message")
        XCTAssertEqual(message.content?.first?.text, "What is 2+2?")
    }

    func testEmptySegmentsProduceEmptyContent() {
        let entry = Transcript.Entry.instructions(
            Transcript.Instructions(segments: [], toolDefinitions: []))
        let message = entry.openAIMessage
        XCTAssertEqual(message.content?.count, 0)
    }

    func testMultipleSegmentsConcatenated() {
        let entry = Transcript.Entry.prompt(
            Transcript.Prompt(
                segments: [
                    .text(Transcript.TextSegment(content: "Hello")),
                    .text(Transcript.TextSegment(content: "World")),
                ],
                options: GenerationOptions(),
                responseFormat: nil))
        let message = entry.openAIMessage
        XCTAssertEqual(message.content?.count, 2)
        XCTAssertEqual(message.content?[0].text, "Hello")
        XCTAssertEqual(message.content?[1].text, "World")
    }
}
