//
//  IntelligenceModel.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

public enum IntelligenceModel: Identifiable {
    case openAI(model: String)
    case appleIntelligence(model: SystemLanguageModel = SystemLanguageModel.default)
    case mlx(model: String)
    
    public var id: String {
        switch self {
        case .openAI(let model):
            "openai:\(model)"
        case .appleIntelligence:
            "appleIntelligence"
        case .mlx(let model):
            "mlx:\(model)"
        }
    }
    
    func createSessionImplementation(tools: [any Tool], instructions: Instructions?) -> IntelligenceSessionImplementation {
        switch self {
        case .openAI(let model):
            OpenAISessionImplementation(model: model, apiKey: IntelligenceModel.openAIApiKey, tools: tools, instructions: instructions)
        case .appleIntelligence(let model):
            AppleIntelligenceSessionImplementation(model: model, tools: tools, instructions: instructions)
        case .mlx(let model):
            MLXSessionImplementation(model: model, tools: tools, instructions: instructions)
        }
    }
    
    public static var openAIApiKey: String {
        get {
            UserDefaults.standard.string(forKey: "SwiftIntelligence.OpenAIAPIKey") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "SwiftIntelligence.OpenAIAPIKey")
        }
    }

    public static func withId(_ modelId: String) -> IntelligenceModel {
        if modelId.hasPrefix("openai:") {
            let modelName = String(modelId.dropFirst("openai:".count))
            return .openAI(model: modelName)
        }
        if modelId.hasPrefix("mlx:") {
            let modelName = String(modelId.dropFirst("mlx:".count))
            return .mlx(model: modelName)
        }
        return .appleIntelligence()
    }
}

public struct IntelligenceModelSpec: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    
    public var model: IntelligenceModel {
        IntelligenceModel.withId(id)
    }
    
    public static let knownSpecs: [IntelligenceModelSpec] = [
        IntelligenceModelSpec(id: "appleIntelligence", displayName: "Apple Intelligence"),
        IntelligenceModelSpec(id: "openai:gpt-5", displayName: "OpenAI GPT-5"),
        IntelligenceModelSpec(id: "openai:gpt-5-mini", displayName: "OpenAI GPT-5 Mini"),
        IntelligenceModelSpec(id: "openai:gpt-5-nano", displayName: "OpenAI GPT-5 Nano"),
        IntelligenceModelSpec(id: "openai:gpt-5-codex", displayName: "OpenAI GPT-5 Codex"),
        IntelligenceModelSpec(id: "openai:gpt-4o-mini", displayName: "OpenAI GPT-4o Mini"),
        IntelligenceModelSpec(id: "mlx:mlx-community/Qwen3-4B-4bit", displayName: "MLX Qwen3 4B"),
        IntelligenceModelSpec(id: "mlx:mlx-community/Llama-3.2-3B-Instruct-4bit", displayName: "MLX Llama 3.2 3B"),
        IntelligenceModelSpec(id: "mlx:mlx-community/Phi-3.5-mini-instruct-4bit", displayName: "MLX Phi 3.5 Mini"),
        IntelligenceModelSpec(id: "mlx:mlx-community/gemma-2-9b-it-4bit", displayName: "MLX Gemma 2 9B"),
        IntelligenceModelSpec(id: "mlx:mlx-community/Mistral-7B-Instruct-v0.3-4bit", displayName: "MLX Mistral 7B"),
    ]
}
