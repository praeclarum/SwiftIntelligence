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
    let role: String?
    let content: [OpenAIContent]?
    let status: String?
    let arguments: String?
    let call_id: String?
    let name: String?
    let output: String?
    let summary: [OpenAISummaryText]?
}

struct OpenAISummaryText: Codable {
    let type: String
    let text: String
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
    var text: OpenAIRequestText?
}

nonisolated struct OpenAIRequestText: Codable {
    let format: OpenAIRequestTextFormat
}

nonisolated struct OpenAIRequestTextFormat: Codable {
    let type: String
    let name: String?
    let schema: GenerationSchema
    let strict: Bool
    
    init(schema: GenerationSchema) {
        self.type = "json_schema"
        self.name = "output_schema"
        self.schema = schema
        self.strict = true
    }
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
            content: content,
            status: nil,
            arguments: nil,
            call_id: nil,
            name: nil,
            output: nil,
            summary: nil)
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
    
    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, options: GenerationOptions) async throws -> String {
        let responseContent = try await doRespond(to: prompt, schema: nil, options: options)
        return responseContent
    }
    
    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool, options: GenerationOptions) async throws -> GeneratedContent {
        let responseContentJson = try await doRespond(to: prompt, schema: schema, options: options)
        let responseContent = try GeneratedContent(json: responseContentJson)
        return responseContent
    }
    
    private func addPromptToTranscript(_ prompt: Prompt, options: GenerationOptions) {
        let segments: [Transcript.Segment] = prompt.transcriptSegments
        let responseFormat: Transcript.ResponseFormat? = nil // TODO
        transcriptEntries.append(.prompt(Transcript.Prompt(segments: segments, options: options, responseFormat: responseFormat)))
    }
    
    private func doRespond(to prompt: Prompt, schema: GenerationSchema?, options: GenerationOptions) async throws -> String {
        addPromptToTranscript(prompt, options: options)
        var inputList = transcriptEntries.map { $0.openAIMessage }
        var responseContent = ""
        var needsResponse = true
        while needsResponse {
            let response = try await getResponses(input: inputList, schema: schema)
            inputList.append(contentsOf: response.output)
            needsResponse = false
            for item in response.output {
                if item.type == "function_call" {
                    let toolResult = await callTool(name: item.name, arguments: item.arguments)
                    let toolResponseMessage = OpenAIMessage(
                        id: nil,
                        type: "function_call_output",
                        role: nil,
                        content: nil,
                        status: nil,
                        arguments: nil,
                        call_id: item.call_id,
                        name: nil,
                        output: toolResult,
                        summary: nil
                    )
                    inputList.append(toolResponseMessage)
                    needsResponse = true
                }
                else {
                    if let c = item.content {
                        responseContent = c.first?.text ?? ""
                    }
                }
            }
        }
        return responseContent
    }
    
    private func getResponses(input: [OpenAIMessage], schema: GenerationSchema?) async throws -> OpenAIResponsesResponse {
        var requestObject = OpenAIResponsesRequest(
            model: model,
            input: input,
            tools: tools.values.map { $0.openAIToolDefinition },
            text: nil)
        if let schema {
            requestObject.text = OpenAIRequestText(format: OpenAIRequestTextFormat(schema: schema))
        }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let requestEncoder = JSONEncoder()
        requestEncoder.outputFormatting = .prettyPrinted
        let requestJsonData = try requestEncoder.encode(requestObject)
        request.httpBody = requestJsonData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.error.message])
            }
            throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI API request failed with status code \(httpResponse.statusCode)"])
        }
        let jsonDecoder = JSONDecoder()
        let responseObject = try jsonDecoder.decode(OpenAIResponsesResponse.self, from: data)
        return responseObject
    }
    
    private func callTool(name: String?, arguments: String?) async -> String {
        guard let name else {
            return "{\"error\": \"Missing function name.\"}"
        }
        guard let arguments else {
            return "{\"error\": \"Missing function arguments.\"}"
        }
        guard let tool: any Tool = tools[name] else {
            return "{\"error\": \"Function \(name) not found.\"}"
        }
        guard let itool = tool as? any IntelligenceTool else {
            return "{\"error\": \"Function \(name) not available for calling.\"}"
        }
        do {
            let toolResult = try await itool.icall(arguments: GeneratedContent(json: arguments))
            return toolResult.jsonString
        }
        catch {
            return "{\"error\": \"Function \(name) call failed: \(error.localizedDescription)\"}"
        }
    }
}
