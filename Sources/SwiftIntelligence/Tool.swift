//
//  Tool.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

public extension Tool {
    func getParametersJSONSchema(outputFormatting: JSONEncoder.OutputFormatting = []) throws -> String {
        try parameters.getJSONSchema(outputFormatting: outputFormatting)
    }

    func getOutputJSONSchema(outputFormatting: JSONEncoder.OutputFormatting = []) throws -> String where Output: Generable {
        try Output.getJSONSchema(outputFormatting: outputFormatting)
    }
}

public protocol IntelligenceTool: Tool {
    func icall(arguments: GeneratedContent) async throws -> GeneratedContent
}
