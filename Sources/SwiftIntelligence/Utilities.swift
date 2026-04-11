//
//  Utilities.swift
//  SwiftIntelligence
//

import Foundation

/// Strips markdown code fences (e.g. ```json … ```) from a string.
/// Used by providers whose models sometimes wrap JSON output in fences.
func stripCodeFences(_ text: String) -> String {
    var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("```json") {
        s = String(s.dropFirst("```json".count))
    } else if s.hasPrefix("```") {
        s = String(s.dropFirst("```".count))
    }
    if s.hasSuffix("```") {
        s = String(s.dropLast("```".count))
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}
