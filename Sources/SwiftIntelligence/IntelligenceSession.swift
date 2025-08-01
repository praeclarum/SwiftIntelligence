//
//  IntelligenceSession.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
public final class IntelligenceSession {
    let model: IntelligenceModel
    let tools: [any Tool]
    private let implementation: IntelligenceSessionImplementation
    
    /// A full history of interactions, including user inputs and model responses.
    final public var transcript: Transcript { implementation.transcript }
    
    init(model: IntelligenceModel = .appleIntelligence(), tools: [any Tool] = [], instructions: Instructions? = nil) {
        self.model = model
        self.tools = tools
        self.implementation = model.createSessionImplementation(tools: tools, instructions: instructions)
    }
    
    /// Start a new session in blank slate state with instructions builder.
    ///
    /// - Parameters
    ///   - model: The language model to use for this session.
    ///   - guardrails: Controls the guardrails setting for prompt and response filtering. System guardrails is enabled if not specified.
    ///   - tools: Tools to make available to the model for this session.
    ///   - instructions: Instructions that control the model's behavior.
    public convenience init(model: IntelligenceModel, guardrails: LanguageModelSession.Guardrails = .default, tools: [any Tool] = [], @InstructionsBuilder instructions: () throws -> Instructions) rethrows {
        let instructionsValue = try instructions()
        self.init(model: model, tools: tools, instructions: instructionsValue)
    }

    /// Produces a response to a prompt.
    ///
    /// - Parameters:
    ///   - prompt: A prompt for the model to respond to.
    ///   - options: GenerationOptions that control how tokens are sampled from the distribution the model produces.
    /// - Returns: A string composed of the tokens produced by sampling model output.
    @discardableResult
    nonisolated(nonsending) final public func respond(to prompt: String, options: GenerationOptions = GenerationOptions()) async throws -> String {
        try await implementation.respond(to: Prompt(prompt), options: options)
    }

    /// Produces a generated content type as a response to a prompt and schema.
    ///
    /// Consider using the default value of `true` for `includeSchemaInPrompt`.
    /// The exception to the rule is when the model has knowledge about the expected response format, either
    /// because it has been trained on it, or because it has seen exhaustive examples during this session.
    ///
    /// - Parameters:
    ///   - prompt: A prompt for the model to respond to.
    ///   - schema: A schema to guide the output with.
    ///   - includeSchemaInPrompt: Inject the schema into the prompt to bias the model.
    ///   - options: Options that control how tokens are sampled from the distribution the model produces.
    /// - Returns: ``GeneratedContent`` containing the fields and values defined in the schema.
    @discardableResult
    nonisolated(nonsending) final public func respond(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool = true, options: GenerationOptions = GenerationOptions()) async throws -> GeneratedContent {
        try await implementation.respond(to: prompt, schema: schema, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }
    
    /// Produces a generated content type as a response to a prompt and schema.
    ///
    /// Consider using the default value of `true` for `includeSchemaInPrompt`.
    /// The exception to the rule is when the model has knowledge about the expected response format, either
    /// because it has been trained on it, or because it has seen exhaustive examples during this session.
    ///
    /// - Parameters:
    ///   - prompt: A prompt for the model to respond to.
    ///   - schema: A schema to guide the output with.
    ///   - includeSchemaInPrompt: Inject the schema into the prompt to bias the model.
    ///   - options: Options that control how tokens are sampled from the distribution the model produces.
    /// - Returns: ``GeneratedContent`` containing the fields and values defined in the schema.
    @discardableResult
    nonisolated(nonsending) final public func respond(to prompt: String, schema: GenerationSchema, includeSchemaInPrompt: Bool = true, options: GenerationOptions = GenerationOptions()) async throws -> GeneratedContent {
        try await implementation.respond(to: Prompt(prompt), schema: schema, includeSchemaInPrompt: includeSchemaInPrompt, options: options)
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
protocol IntelligenceSessionImplementation {
    var transcript: Transcript { get }
    
    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, options: GenerationOptions) async throws -> String

    @discardableResult
    nonisolated(nonsending) func respond(to prompt: Prompt, schema: GenerationSchema, includeSchemaInPrompt: Bool, options: GenerationOptions) async throws -> GeneratedContent
}
