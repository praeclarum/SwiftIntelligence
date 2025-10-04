//
//  Transcript.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

public extension Transcript {
    func getJSON(outputFormatting: JSONEncoder.OutputFormatting = []) throws -> String {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = outputFormatting
        let transcriptJsonData = try jsonEncoder.encode(self)
        if let transcriptJson = String(data: transcriptJsonData, encoding: .utf8) {
            return transcriptJson
        } else {
            throw NSError(domain: "SwiftIntelligence", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode transcript to JSON"])
        }
    }
    
    var json: String {
        do {
            return try getJSON(outputFormatting: .prettyPrinted)
        } catch {
            return "{}"
        }
    }
}

