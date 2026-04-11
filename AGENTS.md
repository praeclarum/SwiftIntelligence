# SwiftIntelligence

Unify Apple Intelligence foundation models with external LLMs using one small, consistent Swift API.

## Architecture

SwiftIntelligence provides a single `IntelligenceSession` API that abstracts over multiple model providers. The FoundationModels framework's simple types such as `Transcript` and its more advanced `GeneratedContent` types are used throughout the API, and the library handles mapping these to and from the various provider-specific types.

## Concurrency

The `IntelligenceSessionImplementation` protocol methods are `nonisolated(nonsending)`. This is intentional and load-bearing for thread safety — do not change it. `nonisolated(nonsending)` inherits the caller's isolation, so calls from the same isolation domain (e.g. `@MainActor`) are serialized. Switching to plain `nonisolated async` would hop to the global concurrent executor and allow concurrent access, breaking safety.

When a provider's session type (e.g. MLXLMCommon's `ChatSession`) is not `Sendable` but is safe under serial access, declare it `@retroactive @unchecked Sendable` rather than removing `nonisolated(nonsending)` from the protocol or introducing actors.

## Swift Coding Standards

- Never use force unwrapping `!` or force try `try!` in library code. Instead, use `try` and propagate errors, or handle them gracefully.
- Avoid `fatalError()` in library code. Instead, throw errors or use optional returns to indicate failure.
- Use good, custom, descriptive error types that conform to `LocalizedError` for any errors that can occur in the library. This provides better error messages and allows users to handle specific error cases.

## Building

Whenever a change is made make sure the library builds using:

```bash
swift build
```

Eliminate warnings and errors until the build is clean. This ensures that the library is always in a good state and prevents issues for users of the library.
