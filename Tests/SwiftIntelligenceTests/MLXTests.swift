import XCTest
import FoundationModels
@testable import SwiftIntelligence

final class MLXTests: XCTestCase {

    static let mlxModel = "mlx-community/Qwen2.5-0.5B-Instruct-4bit"

    /// MLX requires Metal GPU with the metallib bundled.
    /// In SPM command-line test builds the metallib is absent, causing an uncatchable abort.
    /// Gate on RUN_MLX_TESTS=1 to opt in when running in a suitable environment (e.g. Xcode).
    private func requireMLX() throws {
        guard ProcessInfo.processInfo.environment["RUN_MLX_TESTS"] == "1" else {
            throw XCTSkip("RUN_MLX_TESTS not set — skipping MLX tests (set RUN_MLX_TESTS=1 to enable)")
        }
    }

    func testPrepareDownloadsModel() async throws {
        try requireMLX()
        let session = IntelligenceSession(model: .mlx(model: Self.mlxModel))
        let progress = Progress()
        try await session.prepare(progress: progress)
        XCTAssertEqual(progress.completedUnitCount, progress.totalUnitCount)
    }

    func testSimpleTextResponse() async throws {
        try requireMLX()
        let session = IntelligenceSession(model: .mlx(model: Self.mlxModel))
        let response = try await session.respond(to: "What is 2+2? Answer with just the number.")
        XCTAssertFalse(response.isEmpty, "MLX response should not be empty")
    }

    func testTranscriptAfterResponse() async throws {
        try requireMLX()
        let session = IntelligenceSession(model: .mlx(model: Self.mlxModel))
        _ = try await session.respond(to: "Say hi")
        let json = try session.transcript.getJSON()
        XCTAssertFalse(json.isEmpty)
    }
}
