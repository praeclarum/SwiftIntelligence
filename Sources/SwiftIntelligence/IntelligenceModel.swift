//
//  IntelligenceModel.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
public enum IntelligenceModel {
    case openAI(model: String, apiKey: String)
    case appleIntelligence(model: SystemLanguageModel = SystemLanguageModel.default)
    
    func createSessionImplementation(tools: [any Tool], instructions: Instructions?) -> IntelligenceSessionImplementation {
        switch self {
        case .openAI(let model, let apiKey):
            OpenAISessionImplementation(model: model, apiKey: apiKey, tools: tools, instructions: instructions)
        case .appleIntelligence(let model):
            AppleIntelligenceSessionImplementation(model: model, tools: tools, instructions: instructions)
        }
    }
}
