//
//  Prompt.swift
//  Flashcards
//
//  Created by Frank A. Krueger on 7/31/25.
//

import Foundation
import FoundationModels

enum PromptComponent {
    case text(String)
    
    @available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
    nonisolated var transcriptSegment: Transcript.Segment {
        switch self {
        case .text(let text):
            Transcript.Segment.text(Transcript.TextSegment(content: text))
        }
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
extension Prompt {
    public nonisolated var transcriptSegments: [Transcript.Segment] {
        components.map { $0.transcriptSegment }
    }

    nonisolated var components: [PromptComponent] {
        var resultComponents: [PromptComponent] = []
        let instructionsMirror = Mirror(reflecting: self)
        for child in instructionsMirror.children {
            if child.label == "components", let components = child.value as? [Any] {
                for component in components {
                    let componentMirror = Mirror(reflecting: component)
                    for componentChild in componentMirror.children {
                        if componentChild.label == "text", let textComponent = getTextComponent(from: componentChild.value) {
                            resultComponents.append(textComponent)
                        }
                        else {
                            print("Unsupported Instructions Component:")
                            print("    label: \(componentChild.label ?? "???")")
                            print("    value: \(componentChild.value)")
                        }
                    }
                }
            }
        }
        return resultComponents
    }
    
    private nonisolated func getTextComponent(from componentValue: Any) -> PromptComponent? {
        let textComponentMirror = Mirror(reflecting: componentValue)
        for child in textComponentMirror.children {
            if child.label == "value", let text = child.value as? String {
                return .text(text)
            }
        }
        return nil
    }
}
