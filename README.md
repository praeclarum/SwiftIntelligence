# SwiftIntelligence

Unify Apple Intelligence foundation models with external LLMs using one small, consistent Swift API.

SwiftIntelligence gives app developers a smooth upgrade path: start on-device with Apple Intelligence for privacy and low latency, then swap to cloud models like OpenAI for more power—without rewriting your app. The API stays the same across providers and supports tools/function-calling and structured (typed) generative output.

• One session type for all models: `IntelligenceSession`
• One model enum to choose providers: `IntelligenceModel`
• Built-in support today: Apple Intelligence + OpenAI (Responses API)
• Structured output via JSON Schema and Generable Swift types
• Tool calls (aka function calling) with a clean Swift protocol
• Full transcript export for debugging and analytics


## Why this exists

Apple’s FoundationModels framework is delightful for on-device AI. But production apps usually need to mix in cloud models for quality, cost, or capability. SwiftIntelligence bridges that gap:

- Consistent API surface across providers
- Easy switch from local to cloud models
- Tooling and typed output that map cleanly to both worlds
- Minimal code in your app—focus on features, not providers


## Installation

Swift Package Manager

1) In Xcode: File > Add Package Dependencies… and use:
   https://github.com/praeclarum/SwiftIntelligence

2) Or add to your `Package.swift`:

```swift
dependencies: [
	.package(url: "https://github.com/praeclarum/SwiftIntelligence", from: "0.1.0")
]
```

Make sure you’re targeting the Apple SDKs that include the FoundationModels framework (see Requirements below).


## Quick start

The single entry point is `IntelligenceSession`. Create a session with Apple Intelligence and a short instruction.

```swift
import SwiftIntelligence

let session = IntelligenceSession(model: .appleIntelligence()) {
	"You are a helpful, concise assistant for a Swift app. Keep answers under 100 words."
}

let reply = try await session.respond(to: "Write a cheerful haiku about Swift.")
print(reply)
```

Switch to OpenAI—same API, different model:

```swift
import SwiftIntelligence

IntelligenceModel.openAIApiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

let session = IntelligenceSession(model: .openAI(model: "gpt-4o-mini")) {
	"You are a helpful, concise assistant for a Swift app. Keep answers under 100 words."
}

let reply = try await session.respond(to: "Write a cheerful haiku about Swift.")
print(reply)
```


## Structured output (typed results)

Generate JSON shaped to a schema or directly into a Swift type that conforms to FoundationModels’ `Generable`.

Option A: Generate directly into a Swift type:

```swift
import FoundationModels

struct Recipe: Generable {
	let title: String
	let ingredients: [String]
	let steps: [String]
}

let recipe: Recipe = try await session.respond(
	to: "Create a simple pasta recipe",
	generating: Recipe.self
)
```

Option B: Pass a schema explicitly (useful for dynamic schemas):

```swift
import FoundationModels

let schema = GenerationSchema.object(
	properties: [
		"title": .string(),
		"ingredients": .array(items: .string()),
		"steps": .array(items: .string())
	],
	required: ["title", "ingredients", "steps"]
)

let content = try await session.respond(
	to: "Create a simple pasta recipe",
	schema: schema
)

let json = content.jsonString // or decode via GeneratedContent APIs
```

Under the hood, SwiftIntelligence maps your schema or `Generable` type to Apple Intelligence or to OpenAI’s Responses API with `json_schema` output.


## Tools (function calling)

Expose app capabilities to the model using tools. Define a tool by conforming to FoundationModels’ `Tool` plus SwiftIntelligence’s `IntelligenceTool` to provide an async Swift implementation.

```swift
import SwiftIntelligence
import FoundationModels

struct GetWeather: IntelligenceTool {
	var name: String { "getWeather" }
	var description: String { "Get the current weather for a city" }

    @Generable
	struct Arguments: Generable {
		let city: String
	}

	@Generable
	struct Output {
        let city: String
		let temperatureC: Double
		let conditions: String
	}

	func call(arguments: Arguments) async throws -> Output {
		// …call your weather API…
		return Output(city: arguments.city, temperatureC: 21.5, conditions: "Sunny")
	}

    // A little thunk to make this tool compatible with both Apple Intelligence and OpenAI
    func icall(arguments: GeneratedContent) async throws -> GeneratedContent {
        GeneratedContent(try await call(arguments: Arguments(arguments)))
    }
}

let session = IntelligenceSession(
	model: .openAI(model: "gpt-4o-mini"),
	tools: [GetWeather()]
)

let reply = try await session.respond(to: "Is it T-shirt weather in Paris today?")
print(reply)
```

Notes

- On OpenAI, SwiftIntelligence bridges your tool to the Responses API function-calling flow. The model can ask to call a function; the library runs your Swift implementation and feeds the result back to the model automatically. This is done through the `icall(arguments:)` method.
- On Apple Intelligence, tools use the native FoundationModels tool interfaces. This is done through the `call(arguments:)` method.


## Transcripts and debugging

Every session keeps a transcript you can export as JSON—great for debugging, analytics, or conversation logging.

```swift
print(session.transcript.json)
```


## API at a glance

- `IntelligenceSession` – create once per conversation; call `respond(…)` for strings or typed content
- `IntelligenceModel` – select `.appleIntelligence()` or `.openAI(model: String)`
- `IntelligenceModel.openAIApiKey` – set once; stored in `UserDefaults`
- `Instructions` – provide system/developer guidance at session start
- `Prompt` – the structured prompt type in FoundationModels (you can pass strings directly)
- `GenerationSchema` and `Generable` – define structured output
- `Tool` and `IntelligenceTool` – declare metadata and implement Swift-side function calls
- `Transcript` – inspect/export the conversation


## Configuration

OpenAI API key

```swift
IntelligenceModel.openAIApiKey = "sk-…" // stored in UserDefaults under SwiftIntelligence.OpenAIAPIKey
```

You can also load from an environment variable during development:

```swift
IntelligenceModel.openAIApiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
```


## Requirements

- Xcode with SDKs that include the FoundationModels framework (iOS 26, macOS 26, etc. or later)
- Apple platforms that support Apple Intelligence (for on-device usage)
- For OpenAI, network access and a valid API key

The package itself is pure Swift; platform availability follows FoundationModels.


## Schema utilities

You can inspect the automatically constructed JSON Schema for any `GenerationSchema` or `Generable` type:

```swift
print(try schema.getJSONSchema(outputFormatting: [.prettyPrinted]))
print(try Recipe.getJSONSchema(outputFormatting: [.prettyPrinted]))
```


## Roadmap

- Additional providers: Claude, Gemini, and others via OpenRouter
- Streaming responses and partial structured decoding
- Richer multimodal prompts (images, etc.) across providers
- More complete transcript capture of responses

If a provider you need isn’t listed, please open an issue.


## Contributing

Issues and PRs are welcome. If you’re adding a provider, keep the `IntelligenceSession` surface stable and map the provider’s features into:

- prompts/instructions
- structured output (JSON Schema)
- tools/function-calling
- transcript handling


## License

Copyright (c) 2025 Frank A. Krueger.

Intended to be MIT licensed. If you need a different license or clarity here, please open an issue.

