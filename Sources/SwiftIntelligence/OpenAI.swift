//
//  OpenAI.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
struct OpenAIToolDefinition: Codable {
    let type: String
    let name: String
    let description: String
    let parameters: GenerationSchema
}

struct OpenAIMessage: Codable {
    let id: String?
    let type: String
    let role: String
    let content: [OpenAIContent]
}

struct OpenAIContent: Codable {
    let type: String
    let text: String
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
nonisolated struct OpenAIResponsesRequest: Codable {
    let model: String
    let input: [OpenAIMessage]
    let tools: [OpenAIToolDefinition]
}

nonisolated struct OpenAIResponsesResponse: Codable {
    let id: String
    let object: String
    let status: String
    let error: String?
    let model: String
    let output: [OpenAIMessage]
    let usage: OpenAIUsage
}

struct OpenAIUsage: Codable {
    let input_tokens: Int
    let input_tokens_details: InputTokensDetails
    let output_tokens: Int
    let output_tokens_details: OutputTokensDetails
    let total_tokens: Int
    
    struct InputTokensDetails: Codable {
        let cached_tokens: Int
    }
    struct OutputTokensDetails: Codable {
        let reasoning_tokens: Int
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
extension Tool {
    nonisolated var openAIToolDefinition: OpenAIToolDefinition {
        OpenAIToolDefinition(type: "function", name: name, description: description, parameters: parameters)
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
extension Transcript.Segment {
    nonisolated var openAIContent: OpenAIContent? {
        switch self {
        case .text(let textSegment):
            return OpenAIContent(type: "input_text", text: textSegment.content)
        default:
            print("OpenAI does not support image segments yet.")
            return nil
        }
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
extension Transcript.Entry {
    nonisolated var openAIMessage: OpenAIMessage {
        var content: [OpenAIContent] = []
        var role: String = "user"
        switch self {
        case .instructions(let instructions):
            role = "developer"
            content.append(contentsOf: instructions.segments.compactMap { $0.openAIContent })
        case .prompt(let prompt):
            content.append(contentsOf: prompt.segments.compactMap { $0.openAIContent })
        default:
            // TODO
            print("OpenAI does not support this transcript entry type yet: \(self)")
        }
        return OpenAIMessage(
            id: nil,
            type: "message",
            role: role,
            content: content)
    }
}

nonisolated struct OpenAIErrorResponse: Codable {
    let error: Error
    
    struct Error: Codable {
        let message: String
        let type: String
        let code: String?
        let param: String?
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
nonisolated class OpenAISessionImplementation: IntelligenceSessionImplementation {
    private let apiKey: String
    private let model: String
    private let tools: [String: any Tool]
    private var transcriptEntries: [Transcript.Entry] = []

    init(model: String, apiKey: String, tools: [any Tool], instructions: Instructions?) {
        self.model = model
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
    
    nonisolated private func addPromptToTranscript(_ prompt: Prompt, options: GenerationOptions) {
        let segments: [Transcript.Segment] = prompt.transcriptSegments
        let responseFormat: Transcript.ResponseFormat? = nil // TODO
        transcriptEntries.append(.prompt(Transcript.Prompt(segments: segments, options: options, responseFormat: responseFormat)))
    }
    
    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, options: GenerationOptions) async throws -> String {
        addPromptToTranscript(prompt, options: options)
        throw NSError(domain: "SwiftIntelligence", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI session implementation not yet implemented."])
    }
    
    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool, options: GenerationOptions) async throws -> GeneratedContent {
        addPromptToTranscript(prompt, options: options)
        let requestObject = OpenAIResponsesRequest(
            model: model,
            input: transcriptEntries.map { $0.openAIMessage },
            tools: tools.values.map { $0.openAIToolDefinition })
//        print(requestObject)
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestObject)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.error.message])
            }
            throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI API request failed with status code \(httpResponse.statusCode)"])
        }
        let jsonDecoder = JSONDecoder()
        let responseObject = try jsonDecoder.decode(OpenAIResponsesResponse.self, from: data)
        let responseContent = try GeneratedContent(json: responseObject.output[0].content[0].text)
//        let responseString = String(data: data, encoding: .utf8) ?? ""
//        print("Response:\n\(responseString)")
        return responseContent
    }
}
