//
//  IntelligenceModel.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
public enum IntelligenceModel: Identifiable {
    case openAI(model: String)
    case appleIntelligence(model: SystemLanguageModel = SystemLanguageModel.default)
    
    public var id: String {
        switch self {
        case .openAI(let model):
            "openai:\(model)"
        case .appleIntelligence:
            "appleIntelligence"
        }
    }
    
    func createSessionImplementation(tools: [any Tool], instructions: Instructions?) -> IntelligenceSessionImplementation {
        switch self {
        case .openAI(let model):
            OpenAISessionImplementation(model: model, apiKey: IntelligenceModel.openAIApiKey, tools: tools, instructions: instructions)
        case .appleIntelligence(let model):
            AppleIntelligenceSessionImplementation(model: model, tools: tools, instructions: instructions)
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
        return .appleIntelligence()
    }
}

public struct IntelligenceModelSpec: Identifiable {
    public let id: String
    public let displayName: String
    
    @available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
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
    ]
}
