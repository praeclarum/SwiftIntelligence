//
//  MLX.swift
//  SwiftIntelligence
//

import Foundation
import FoundationModels
import MLXLLM
@preconcurrency import MLXLMCommon

// ChatSession is documented as "not thread-safe; use from a single task/thread at a time."
// Our usage satisfies this: nonisolated(nonsending) methods inherit the caller's isolation,
// serializing calls from any given isolation domain.
extension ChatSession: @retroactive @unchecked Sendable {}

nonisolated class MLXSessionImplementation: IntelligenceSessionImplementation {
    private let modelId: String
    private let intelligenceTools: [String: any FoundationModels.Tool]
    private let instructionsText: String
    private let toolCallRecorder = ToolCallRecorder()
    private nonisolated(unsafe) var transcriptEntries: [Transcript.Entry] = []
    private nonisolated(unsafe) var chatSession: ChatSession?
    private nonisolated(unsafe) var modelContainer: ModelContainer?

    init(model: String, tools: [any FoundationModels.Tool], instructions: Instructions?) {
        self.modelId = model
        self.intelligenceTools = tools.reduce(into: [:]) { result, tool in
            result[tool.name] = tool
        }

        let instructionSegments = instructions?.transcriptSegments ?? []
        if instructionSegments.count > 0 || tools.count > 0 {
            transcriptEntries.append(.instructions(Transcript.Instructions(
                segments: instructionSegments,
                toolDefinitions: tools.map { Transcript.ToolDefinition(tool: $0) })))
        }

        self.instructionsText = instructionSegments.compactMap { segment in
            switch segment {
            case .text(let textSegment):
                return textSegment.content
            default:
                return nil
            }
        }.joined(separator: "\n")
    }

    var transcript: Transcript {
        Transcript(entries: transcriptEntries)
    }

    // MARK: - Model Loading

    /// Prepares the model by downloading and loading it.
    /// Call this before the first `respond` to avoid latency on the first call.
    nonisolated(nonsending) func prepare(progress: Progress?) async throws {
        guard chatSession == nil else {
            progress?.totalUnitCount = 1
            progress?.completedUnitCount = 1
            return
        }
        progress?.totalUnitCount = 100
        progress?.completedUnitCount = 0
        let container = try await loadModelContainer(id: modelId) { downloadProgress in
            progress?.totalUnitCount = downloadProgress.totalUnitCount
            progress?.completedUnitCount = downloadProgress.completedUnitCount
        }
        self.modelContainer = container

        let mlxTools: [[String: any Sendable]]? = intelligenceTools.isEmpty ? nil : intelligenceTools.values.map { $0.mlxToolSpec }

        let tools = self.intelligenceTools
        let recorder = self.toolCallRecorder
        let toolDispatch: (@Sendable (MLXLMCommon.ToolCall) async throws -> String)? = mlxTools == nil ? nil : { @Sendable toolCall in
            let name = toolCall.function.name
            guard let tool = tools[name] else {
                return "{\"error\": \"Function \(name) not found.\"}"
            }
            guard let itool = tool as? any IntelligenceTool else {
                return "{\"error\": \"Function \(name) not available for calling.\"}"
            }
            do {
                // Convert MLX ToolCall arguments ([String: JSONValue]) to JSON string, then to GeneratedContent
                let jsonObject = toolCall.function.arguments.mapValues { $0.anyValue }
                let jsonData = try JSONSerialization.data(withJSONObject: jsonObject)
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    return "{\"error\": \"Failed to serialize arguments for \(name).\"}"
                }
                let arguments = try GeneratedContent(json: jsonString)

                // Record the tool call in the transcript
                recorder.append(.toolCalls(Transcript.ToolCalls([
                    Transcript.ToolCall(id: UUID().uuidString, toolName: name, arguments: arguments)
                ])))

                let result = try await itool.icall(arguments: arguments)

                // Record the tool output in the transcript
                recorder.append(.toolOutput(Transcript.ToolOutput(
                    id: UUID().uuidString,
                    toolName: name,
                    segments: [.text(Transcript.TextSegment(content: result.jsonString))]
                )))

                return result.jsonString
            } catch {
                return "{\"error\": \"Function \(name) call failed: \(error.localizedDescription)\"}"
            }
        }

        self.chatSession = ChatSession(
            container,
            instructions: instructionsText.isEmpty ? nil : instructionsText,
            tools: mlxTools,
            toolDispatch: toolDispatch
        )
    }

    private nonisolated(nonsending) func ensureLoaded() async throws {
        if chatSession != nil {
            return
        }
        try await prepare(progress: nil)
    }

    // MARK: - Respond

    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, options: GenerationOptions) async throws -> String {
        let segments = prompt.transcriptSegments
        transcriptEntries.append(.prompt(Transcript.Prompt(segments: segments, options: options, responseFormat: nil)))

        try await ensureLoaded()
        guard let chatSession else {
            throw MLXError.modelNotLoaded
        }
        let promptText = extractText(from: segments)
        let response = try await chatSession.respond(to: promptText)

        // Append any tool call/output entries recorded during generation
        transcriptEntries.append(contentsOf: toolCallRecorder.drain())

        // Record the model's final response
        transcriptEntries.append(.response(Transcript.Response(
            assetIDs: [],
            segments: [.text(Transcript.TextSegment(content: response))])))

        return response
    }

    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool, options: GenerationOptions) async throws -> GeneratedContent {
        let segments = prompt.transcriptSegments
        let promptText = extractText(from: segments)

        var fullPrompt = promptText
        if includeSchemaInPrompt {
            let schemaJson = try schema.getJSONSchema(outputFormatting: .prettyPrinted)
            fullPrompt += "\n\nRespond ONLY with a valid JSON object conforming to this schema:\n\(schemaJson)"
        }

        transcriptEntries.append(.prompt(Transcript.Prompt(segments: segments, options: options, responseFormat: nil)))

        try await ensureLoaded()
        guard let chatSession else {
            throw MLXError.modelNotLoaded
        }
        let responseText = try await chatSession.respond(to: fullPrompt)

        // Append any tool call/output entries recorded during generation
        transcriptEntries.append(contentsOf: toolCallRecorder.drain())

        // Strip markdown code fences if present
        let cleaned = stripCodeFences(responseText)
        let responseContent = try GeneratedContent(json: cleaned)

        // Record the model's structured response
        transcriptEntries.append(.response(Transcript.Response(
            assetIDs: [],
            segments: [.text(Transcript.TextSegment(content: cleaned))])))

        return responseContent
    }

    // MARK: - Helpers

    private func extractText(from segments: [Transcript.Segment]) -> String {
        segments.compactMap { segment in
            switch segment {
            case .text(let textSegment):
                return textSegment.content
            default:
                return nil
            }
        }.joined(separator: "\n")
    }

}

/// Thread-safe buffer for recording tool call transcript entries from the `@Sendable` toolDispatch closure.
private final class ToolCallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [Transcript.Entry] = []

    func append(_ entry: Transcript.Entry) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
    }

    func drain() -> [Transcript.Entry] {
        lock.lock()
        defer { lock.unlock() }
        let result = entries
        entries.removeAll()
        return result
    }
}

// MARK: - Tool Conversion

extension FoundationModels.Tool {
    /// Converts a FoundationModels Tool to an MLX ToolSpec dictionary.
    nonisolated var mlxToolSpec: [String: any Sendable] {
        // Encode the GenerationSchema (parameters) to a JSON dictionary
        var parametersDict: [String: any Sendable] = ["type": "object"]
        if let jsonData = try? JSONEncoder().encode(parameters),
           let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: any Sendable] {
            parametersDict = dict
        }

        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parametersDict,
            ] as [String: any Sendable],
        ] as [String: any Sendable]
    }
}

// MARK: - Error Handling

enum MLXError: LocalizedError {
    case modelNotLoaded
    case toolNotFound(String)
    case toolNotCallable(String)
    case argumentSerializationFailed(String)
    case toolCallFailed(String, underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "MLX model is not loaded. Call prepare() before generating responses."
        case .toolNotFound(let name):
            return "Tool '\(name)' was not found."
        case .toolNotCallable(let name):
            return "Tool '\(name)' is not available for calling."
        case .argumentSerializationFailed(let name):
            return "Failed to serialize arguments for tool '\(name)'."
        case .toolCallFailed(let name, let error):
            return "Tool '\(name)' call failed: \(error.localizedDescription)"
        }
    }
}
