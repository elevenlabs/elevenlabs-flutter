# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-XX

### Added

- Initial release of ElevenLabs Flutter SDK
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
- Web (experimental)

[0.1.0]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/v0.1.0
