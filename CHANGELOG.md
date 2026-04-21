# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-04-21

### Changed

- Bumped `livekit_client` dependency to `^2.7.0` (fixes build failures on Android and iOS)
- Requires Flutter `>=3.38.0` due to transitive `meta ^1.17.0` requirement

## [0.5.1] - 2026-04-13

Re-release of 0.5.0 with the version correctly bumped in package source files.

### Fixed

- Fixed override serialization to use `toJson()` instead of hand-built maps, ensuring all fields (e.g. `modelId`, `stability`, `similarityBoost`, `maxTokens`) are included.

## [0.5.0] - 2026-04-09 [YANKED]

> **Note:** This version was never published to pub.dev because the version in `pubspec.yaml` and `lib/version.dart` was not updated before tagging.

### Added

- Optional `environment` parameter for `startSession()` to specify the target environment (e.g. `"staging"`). Defaults to `"production"` server-side when not specified.

### Fixed

- Fixed client tool result message format to match backend expectations (`type`, `tool_call_id`, `result`, `is_error` fields).

## [0.4.0] - 2026-03-10

### Added

- `onAgentToolRequest` callback on `ConversationCallbacks`, fired whenever the agent initiates a tool call. Receives `toolName` and `toolCallId` as named parameters, enabling apps to display a loading/thinking indicator during tool execution.
- `AgentToolRequest` event model with fields `toolName`, `toolCallId`, `toolType`, and `parameters`.
- Handling for the `agent_tool_request` protocol event (previously silently dropped). For `tool_type: "client"` the SDK now executes the registered `ClientTool` and returns the result automatically, matching the behaviour introduced in Android SDK v0.7.1.

## [0.3.1] - 2026-02-19

### Changed

- Updated `livekit_client` dependency to ^2.6.0

## [0.3.0] - 2025-11-27

### Changed

- Enhanced disconnect reason tracking in `onDisconnect` callback. The callback now receives specific disconnect reasons: `"agent"` (when agent disconnects), `"user"` (when user ends session), or `"error"` (for network/connection errors).
- Added `disconnectStream` to `LiveKitManager` for better disconnect event handling with reason tracking.

## [0.2.0] - 2025-11-20

### Changed

- Relaxed Dart version requirements for the SDK. Now supports Dart versions 3 and up instead of being pinned to 3.9.2.


## [0.1.0] - 2025-11-10

### Added

- Initial release of ElevenLabs Agents Flutter SDK
- Real-time bidirectional audio communication with AI agents via LiveKit
- Text messaging support (user messages, contextual updates, user activity)
- Client tools support for agent-invoked device capabilities
- Feedback system for agent responses
- Microphone control (mute/unmute)
- Reactive state management with `ChangeNotifier`
- Comprehensive callback system for all events
- Configuration overrides for agent, TTS, and conversation settings
- Support for custom endpoints and data residency
- Public and private agent support
- Complete example application
- iOS and Android platform support
- Comprehensive documentation and API reference

### Features

- `ConversationClient` - Main client class for managing conversations
- `ConversationStatus` - Connection status tracking
- `ConversationMode` - Speaking/listening mode detection
- `ClientTool` - Interface for implementing client-side tools
- `ConversationCallbacks` - Comprehensive callback system
- Configuration models for all override options
- Event types matching the ElevenLabs AsyncAPI protocol

### Platform Support

- iOS 13.0+
- Android API 21+

[0.6.0]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.6.0
[0.5.1]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.5.1
[0.5.0]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.5.0
[0.4.0]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.4.0
[0.3.1]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.3.1
[0.3.0]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.3.0
[0.2.0]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.2.0
[0.1.0]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.1.0
