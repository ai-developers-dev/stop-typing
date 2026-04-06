# Stop Typing - macOS Menu Bar App (Swift)

## MCP Servers — ALWAYS USE FOR SWIFT WORK

When writing, modifying, or debugging Swift code, you MUST use the following MCP tools. Do not skip these steps.

### sosumi (Apple Documentation)
Use **before** writing or modifying any Swift/SwiftUI/AppKit code when you are not 100% certain about an API.
- `searchAppleDocumentation` — search Apple docs by query
- `fetchAppleDocumentation` — fetch a specific doc page (e.g. `/documentation/swiftui/view`)
- `fetchAppleVideoTranscript` — fetch WWDC session transcripts
- `fetchExternalDocumentation` — fetch external Swift-DocC pages
- Do NOT fabricate API signatures — always verify with a fetch when uncertain

### swiftlens (Code Analysis)
Use to understand existing code structure before making changes.
- Find symbol references and definitions
- Analyze type hierarchies and code structure
- Navigate the codebase to understand patterns

### XcodeBuildMCP (Build & Run)
Use for ALL build and run operations. Do NOT use raw `xcodebuild` commands.
- Build the project and check for errors
- Run the app
- Resolve build configuration issues

### xcode (MCP Bridge)
Use for Xcode IDE integration when the user has Xcode open.
- Get diagnostics from Xcode
- Interact with the Xcode project structure

## Required Workflow for Swift Changes

1. **Look up docs** — Use `sosumi` to verify any APIs you're not certain about
2. **Analyze first** — Use `swiftlens` to understand the existing code before modifying it
3. **Write code** — Make the Swift changes
4. **Build & verify** — Use `XcodeBuildMCP` to build and confirm no errors
5. **Fix errors** — If the build fails, use diagnostics to understand and fix failures

## Project Structure
- Xcode project: `wispr/wispr.xcodeproj`
- Swift sources: `wispr/wispr/`
- SPM dependencies: WhisperKit, FluidAudio, ArgumentParser
- Includes CLI tool (`wispr-cli`) and UI tests
