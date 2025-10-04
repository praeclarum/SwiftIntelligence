//
//  Schema.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

public extension GenerationSchema {
    func getJSONSchema(outputFormatting: JSONEncoder.OutputFormatting = []) throws -> String {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = outputFormatting
        let schemaJsonData = try jsonEncoder.encode(self)
        if let schemaJson = String(data: schemaJsonData, encoding: .utf8) {
            return schemaJson
        } else {
            throw NSError(domain: "SwiftIntelligence", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode schema to JSON"])
        }
    }
    
    var jsonSchema: String {
        do {
            return try getJSONSchema(outputFormatting: .prettyPrinted)
        } catch {
            return "{}"
        }
    }
}

public extension Generable {
    static func getJSONSchema(outputFormatting: JSONEncoder.OutputFormatting = []) throws -> String {
        try Self.generationSchema.getJSONSchema(outputFormatting: outputFormatting)
    }
}
