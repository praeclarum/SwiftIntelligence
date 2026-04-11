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

        // TODO: Implement full tool dispatch that converts MLX ToolCall arguments to GeneratedContent
        let tools = self.intelligenceTools
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
                let result = try await itool.icall(arguments: arguments)
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
        let promptText = extractText(from: segments)
        let response = try await chatSession!.respond(to: promptText)
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
        let responseText = try await chatSession!.respond(to: fullPrompt)

        // Strip markdown code fences if present
        let cleaned = Self.stripCodeFences(responseText)
        let responseContent = try GeneratedContent(json: cleaned)
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

    private static func stripCodeFences(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") {
            s = String(s.dropFirst("```json".count))
        } else if s.hasPrefix("```") {
            s = String(s.dropFirst("```".count))
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast("```".count))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
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
