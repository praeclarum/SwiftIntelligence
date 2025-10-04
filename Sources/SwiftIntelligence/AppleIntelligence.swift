//
//  AppleIntelligence.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

final class AppleIntelligenceSessionImplementation: IntelligenceSessionImplementation {
    private let session: LanguageModelSession
    
    init(model: SystemLanguageModel, tools: [any Tool], instructions: Instructions?) {
        self.session = LanguageModelSession(model: model, tools: tools, instructions: instructions)
//        print(self.session.transcript.json)
    }
    
    var transcript: Transcript { session.transcript }
    
    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, options: GenerationOptions) async throws -> String {
        let response = try await session.respond(to: prompt, options: options)
        return response.content
    }
    
    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool, options: GenerationOptions) async throws -> GeneratedContent {
        let response = try await session.respond(to: prompt, schema: schema, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
        return response.content
    }
}
