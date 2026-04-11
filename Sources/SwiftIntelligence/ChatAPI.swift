//
//  ChatAPI.swift
//  SwiftIntelligence
//
//  Created by SwiftIntelligence on 4/10/26.
//
//  Implements the OpenAI-compatible Chat Completions API (POST /v1/chat/completions).
//  Works with OpenRouter, Amazon Bedrock, and any provider exposing this endpoint.
//

import Foundation
import FoundationModels

// MARK: - Error Types

enum ChatAPIError: LocalizedError {
    case invalidURL(String)
    case httpError(statusCode: Int, message: String)
    case noChoicesReturned
    case missingContent
    case maxToolIterationsExceeded(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid Chat API URL: \(url)"
        case .httpError(let statusCode, let message):
            return "Chat API request failed (\(statusCode)): \(message)"
        case .noChoicesReturned:
            return "Chat API returned no choices in the response."
        case .missingContent:
            return "Chat API response message has no content."
        case .maxToolIterationsExceeded(let count):
            return "Chat API exceeded maximum tool call iterations (\(count))."
        }
    }
}

nonisolated struct ChatAPIErrorResponse: Codable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let code: String?
        let param: String?
    }
}

// MARK: - Request Types

nonisolated struct ChatAPIRequest: Encodable {
    let model: String
    let messages: [ChatAPIMessage]
    let tools: [ChatAPIToolDefinition]?
    let response_format: ChatAPIResponseFormat?
}

nonisolated struct ChatAPIMessage: Codable {
    let role: String
    let content: String?
    let tool_calls: [ChatAPIToolCall]?
    let tool_call_id: String?
    let name: String?

    init(role: String, content: String?, tool_calls: [ChatAPIToolCall]? = nil, tool_call_id: String? = nil, name: String? = nil) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.tool_call_id = tool_call_id
        self.name = name
    }
}

nonisolated struct ChatAPIToolCall: Codable {
    let id: String
    let type: String
    let function: ChatAPIToolFunction
}

nonisolated struct ChatAPIToolFunction: Codable {
    let name: String
    let arguments: String
}

nonisolated struct ChatAPIToolDefinition: Encodable {
    let type: String
    let function: ChatAPIToolFunctionDefinition

    init(function: ChatAPIToolFunctionDefinition) {
        self.type = "function"
        self.function = function
    }
}

nonisolated struct ChatAPIToolFunctionDefinition: Encodable {
    let name: String
    let description: String
    let parameters: GenerationSchema
}

nonisolated struct ChatAPIResponseFormat: Encodable {
    let type: String
    let json_schema: ChatAPIJsonSchema

    init(schema: GenerationSchema) {
        self.type = "json_schema"
        self.json_schema = ChatAPIJsonSchema(schema: schema)
    }
}

nonisolated struct ChatAPIJsonSchema: Encodable {
    let name: String
    let strict: Bool
    let schema: GenerationSchema

    init(schema: GenerationSchema) {
        self.name = "output_schema"
        self.strict = true
        self.schema = schema
    }
}

// MARK: - Response Types

nonisolated struct ChatAPIResponse: Decodable {
    let id: String
    let object: String?
    let model: String?
    let choices: [ChatAPIChoice]
    let usage: ChatAPIUsage?
}

nonisolated struct ChatAPIChoice: Decodable {
    let index: Int
    let message: ChatAPIMessage
    let finish_reason: String?
}

nonisolated struct ChatAPIUsage: Decodable {
    let prompt_tokens: Int?
    let completion_tokens: Int?
    let total_tokens: Int?
}

// MARK: - Tool Conversion

extension Tool {
    nonisolated var chatAPIToolDefinition: ChatAPIToolDefinition {
        ChatAPIToolDefinition(function: ChatAPIToolFunctionDefinition(
            name: name,
            description: description,
            parameters: parameters
        ))
    }
}

// MARK: - Session Implementation

nonisolated class ChatAPISessionImplementation: IntelligenceSessionImplementation {
    private let apiKey: String
    private let model: String
    private let baseURL: String
    private let tools: [String: any Tool]
    private var transcriptEntries: [Transcript.Entry] = []

    let timeoutInterval: TimeInterval = 2 * 60 // 2 minutes
    let maxToolIterations: Int = 10

    init(model: String, baseURL: String, apiKey: String, tools: [any Tool], instructions: Instructions?) {
        self.model = model
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.tools = tools.reduce(into: [:]) { result, tool in
            result[tool.name] = tool
        }
        let instructionSegments = instructions?.transcriptSegments ?? []
        if instructionSegments.count > 0 || tools.count > 0 {
            transcriptEntries.append(.instructions(Transcript.Instructions(
                segments: instructionSegments,
                toolDefinitions: tools.map { Transcript.ToolDefinition(tool: $0) })))
        }
    }

    var transcript: Transcript {
        Transcript(entries: transcriptEntries)
    }

    nonisolated(nonsending) func prepare(progress: Progress?) async throws {
        progress?.totalUnitCount = 1
        progress?.completedUnitCount = 1
    }

    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, options: GenerationOptions) async throws -> String {
        try await doRespond(to: prompt, schema: nil, includeSchemaInPrompt: false, options: options)
    }

    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool, options: GenerationOptions) async throws -> GeneratedContent {
        let json = try await doRespond(to: prompt, schema: schema, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
        let cleaned = Self.stripCodeFences(json)
        return try GeneratedContent(json: cleaned)
    }

    // MARK: - Core Request Loop

    nonisolated(nonsending) private func doRespond(to prompt: Prompt, schema: GenerationSchema?, includeSchemaInPrompt: Bool, options: GenerationOptions) async throws -> String {
        // Record the prompt in the transcript
        let segments = prompt.transcriptSegments
        transcriptEntries.append(.prompt(Transcript.Prompt(segments: segments, options: options, responseFormat: nil)))

        // Build the full message list from transcript
        var messages = buildMessages(from: transcriptEntries)

        // If includeSchemaInPrompt and we have a schema, append schema to the last user message
        if includeSchemaInPrompt, let schema {
            if let lastIndex = messages.lastIndex(where: { $0.role == "user" }) {
                let existingContent = messages[lastIndex].content ?? ""
                let schemaJson = try schema.getJSONSchema(outputFormatting: .prettyPrinted)
                let augmented = existingContent + "\n\nRespond ONLY with a valid JSON object conforming to this schema:\n" + schemaJson
                messages[lastIndex] = ChatAPIMessage(role: "user", content: augmented)
            }
        }

        // Build tool definitions for the request
        let toolDefs: [ChatAPIToolDefinition]? = tools.isEmpty ? nil : tools.values.map { $0.chatAPIToolDefinition }

        // Build response format for structured output
        let responseFormat: ChatAPIResponseFormat? = schema.map { ChatAPIResponseFormat(schema: $0) }

        // Agentic tool loop
        var responseContent = ""
        var iterations = 0

        while iterations < maxToolIterations {
            iterations += 1

            let response = try await sendRequest(messages: messages, tools: toolDefs, responseFormat: responseFormat)

            guard let choice = response.choices.first else {
                throw ChatAPIError.noChoicesReturned
            }

            let assistantMessage = choice.message

            // If the assistant made tool calls, process them
            if let toolCalls = assistantMessage.tool_calls, !toolCalls.isEmpty {
                // Append the assistant message (with tool_calls) to messages
                messages.append(assistantMessage)

                // Record tool calls in transcript
                var transcriptToolCalls: [Transcript.ToolCall] = []
                for tc in toolCalls {
                    let arguments = try GeneratedContent(json: tc.function.arguments)
                    transcriptToolCalls.append(Transcript.ToolCall(
                        id: tc.id,
                        toolName: tc.function.name,
                        arguments: arguments
                    ))
                }
                transcriptEntries.append(.toolCalls(Transcript.ToolCalls(transcriptToolCalls)))

                // Execute each tool and append results
                for tc in toolCalls {
                    let toolResult = await callTool(name: tc.function.name, arguments: tc.function.arguments)

                    // Append tool result message
                    messages.append(ChatAPIMessage(
                        role: "tool",
                        content: toolResult,
                        tool_call_id: tc.id,
                        name: tc.function.name
                    ))

                    // Record tool output in transcript
                    transcriptEntries.append(.toolOutput(Transcript.ToolOutput(
                        id: tc.id,
                        toolName: tc.function.name,
                        segments: [.text(Transcript.TextSegment(content: toolResult))]
                    )))
                }

                // Continue loop to get next response
                continue
            }

            // No tool calls — this is the final response
            responseContent = assistantMessage.content ?? ""

            // Record the response in transcript
            transcriptEntries.append(.response(Transcript.Response(
                assetIDs: [],
                segments: [.text(Transcript.TextSegment(content: responseContent))]
            )))

            return responseContent
        }

        throw ChatAPIError.maxToolIterationsExceeded(maxToolIterations)
    }

    // MARK: - Message Building

    private func buildMessages(from entries: [Transcript.Entry]) -> [ChatAPIMessage] {
        var messages: [ChatAPIMessage] = []
        for entry in entries {
            switch entry {
            case .instructions(let instructions):
                let text = instructions.segments.compactMap { segment -> String? in
                    switch segment {
                    case .text(let textSegment):
                        return textSegment.content
                    default:
                        return nil
                    }
                }.joined(separator: "\n")
                if !text.isEmpty {
                    messages.append(ChatAPIMessage(role: "system", content: text))
                }
            case .prompt(let prompt):
                let text = prompt.segments.compactMap { segment -> String? in
                    switch segment {
                    case .text(let textSegment):
                        return textSegment.content
                    default:
                        return nil
                    }
                }.joined(separator: "\n")
                messages.append(ChatAPIMessage(role: "user", content: text))
            case .response(let response):
                let text = response.segments.compactMap { segment -> String? in
                    switch segment {
                    case .text(let textSegment):
                        return textSegment.content
                    default:
                        return nil
                    }
                }.joined(separator: "\n")
                messages.append(ChatAPIMessage(role: "assistant", content: text))
            case .toolCalls(let toolCalls):
                let apiToolCalls = toolCalls.map { tc in
                    ChatAPIToolCall(
                        id: tc.id,
                        type: "function",
                        function: ChatAPIToolFunction(
                            name: tc.toolName,
                            arguments: tc.arguments.jsonString
                        )
                    )
                }
                messages.append(ChatAPIMessage(role: "assistant", content: nil, tool_calls: apiToolCalls))
            case .toolOutput(let toolOutput):
                let text = toolOutput.segments.compactMap { segment -> String? in
                    switch segment {
                    case .text(let textSegment):
                        return textSegment.content
                    default:
                        return nil
                    }
                }.joined(separator: "\n")
                messages.append(ChatAPIMessage(
                    role: "tool",
                    content: text,
                    tool_call_id: toolOutput.id,
                    name: toolOutput.toolName
                ))
            @unknown default:
                break
            }
        }
        return messages
    }

    // MARK: - HTTP Request

    nonisolated(nonsending) private func sendRequest(messages: [ChatAPIMessage], tools: [ChatAPIToolDefinition]?, responseFormat: ChatAPIResponseFormat?) async throws -> ChatAPIResponse {
        let trimmedBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(trimmedBase)/chat/completions"
        guard let url = URL(string: urlString) else {
            throw ChatAPIError.invalidURL(urlString)
        }

        let requestObject = ChatAPIRequest(
            model: model,
            messages: messages,
            tools: tools,
            response_format: responseFormat
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutInterval

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestObject)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let message: String
            if let errorResponse = try? JSONDecoder().decode(ChatAPIErrorResponse.self, from: data) {
                message = errorResponse.error.message
            } else {
                message = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw ChatAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(ChatAPIResponse.self, from: data)
    }

    // MARK: - Tool Calling

    nonisolated(nonsending) private func callTool(name: String, arguments: String) async -> String {
        guard let tool: any Tool = tools[name] else {
            return "{\"error\": \"Function \(name) not found.\"}"
        }
        guard let itool = tool as? any IntelligenceTool else {
            return "{\"error\": \"Function \(name) not available for calling.\"}"
        }
        do {
            let args = try GeneratedContent(json: arguments)
            let result = try await itool.icall(arguments: args)
            return result.jsonString
        } catch {
            return "{\"error\": \"Function \(name) call failed: \(error.localizedDescription)\"}"
        }
    }

    // MARK: - Helpers

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
