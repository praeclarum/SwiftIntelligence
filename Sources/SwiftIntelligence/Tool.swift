//
//  Tool.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
public extension Tool {
    func getParametersJSONSchema(outputFormatting: JSONEncoder.OutputFormatting = []) throws -> String {
        try parameters.getJSONSchema(outputFormatting: outputFormatting)
    }

    func getOutputJSONSchema(outputFormatting: JSONEncoder.OutputFormatting = []) throws -> String where Output: Generable {
        try Output.getJSONSchema(outputFormatting: outputFormatting)
    }
}
