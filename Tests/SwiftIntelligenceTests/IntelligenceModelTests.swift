import XCTest
@testable import SwiftIntelligence

final class IntelligenceModelTests: XCTestCase {

    func testOpenAIRoundTrip() {
        let model = IntelligenceModel.withId("openai:gpt-5")
        XCTAssertEqual(model.id, "openai:gpt-5")
        if case .openAI(let name) = model {
            XCTAssertEqual(name, "gpt-5")
        } else {
            XCTFail("Expected .openAI case")
        }
    }

    func testMLXRoundTrip() {
        let model = IntelligenceModel.withId("mlx:mlx-community/Qwen3-4B-4bit")
        XCTAssertEqual(model.id, "mlx:mlx-community/Qwen3-4B-4bit")
        if case .mlx(let name) = model {
            XCTAssertEqual(name, "mlx-community/Qwen3-4B-4bit")
        } else {
            XCTFail("Expected .mlx case")
        }
    }

    func testChatAPIRoundTrip() {
        let model = IntelligenceModel.withId("chatapi:https://example.com/v1:my-model")
        XCTAssertEqual(model.id, "chatapi:https://example.com/v1:my-model")
        if case .chatAPI(let name, let baseURL) = model {
            XCTAssertEqual(name, "my-model")
            XCTAssertEqual(baseURL, "https://example.com/v1")
        } else {
            XCTFail("Expected .chatAPI case")
        }
    }

    func testAppleIntelligenceFallback() {
        let model = IntelligenceModel.withId("appleIntelligence")
        XCTAssertEqual(model.id, "appleIntelligence")
        if case .appleIntelligence = model {
            // OK
        } else {
            XCTFail("Expected .appleIntelligence case")
        }
    }

    func testUnknownStringFallsBackToAppleIntelligence() {
        let model = IntelligenceModel.withId("something-random")
        if case .appleIntelligence = model {
            // OK — unknown prefix falls back
        } else {
            XCTFail("Expected .appleIntelligence fallback")
        }
    }

    func testKnownSpecsAllProduceValidModels() {
        for spec in IntelligenceModelSpec.knownSpecs {
            let model = spec.model
            XCTAssertEqual(model.id, spec.id, "Spec '\(spec.displayName)' round-trips its id")
        }
    }
}
