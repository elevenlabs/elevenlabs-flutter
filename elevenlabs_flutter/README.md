# ElevenLabs Flutter SDK

[![pub package](https://img.shields.io/pub/v/elevenlabs_flutter.svg)](https://pub.dev/packages/elevenlabs_flutter)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Flutter SDK for the [ElevenLabs Agent Platform](https://elevenlabs.io). Build conversational AI applications with real-time audio communication powered by WebRTC via [LiveKit](https://livekit.io).

## Features

- 🎙️ **Real-time Audio**: Bidirectional voice communication with AI agents
- 💬 **Text Messaging**: Send text messages and contextual updates
- 🔧 **Client Tools**: Register local device capabilities the agent can invoke
- 📊 **Reactive State**: Built on `ChangeNotifier` for Flutter-idiomatic reactive updates
- 🌍 **Data Residency**: Support for custom endpoints and self-hosted deployments
- 🎯 **Type Safe**: Comprehensive Dart type definitions
- ⚡ **LiveKit Powered**: Production-ready WebRTC infrastructure

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  elevenlabs_flutter: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### iOS

Update `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for voice conversations</string>
```

Update `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

### Android

Update `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

Set `minSdkVersion` to 21 in `android/app/build.gradle`.

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';

class MyConversation extends StatefulWidget {
  @override
  State<MyConversation> createState() => _MyConversationState();
}

class _MyConversationState extends State<MyConversation> {
  late ConversationClient _client;

  @override
  void initState() {
    super.initState();

    _client = ConversationClient(
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) {
          print('Connected: $conversationId');
        },
        onMessage: ({required message, required source}) {
          print('[$source] $message');
        },
        onError: (message, [context]) {
          print('Error: $message');
        },
      ),
    );

    // Listen to state changes
    _client.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _startConversation() async {
    await _client.startSession(
      agentId: 'your-agent-id',
      userId: 'user-123',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Status: ${_client.status.name}'),
        ElevatedButton(
          onPressed: _client.status == ConversationStatus.disconnected
              ? _startConversation
              : null,
          child: Text('Start'),
        ),
      ],
    );
  }
}
```

## Usage

### Starting a Session

#### Public Agent

For public agents, provide the agent ID:

```dart
await client.startSession(
  agentId: 'your-public-agent-id',
  userId: 'user-123',
);
```

#### Private Agent

For private agents, provide a conversation token from your backend:

```dart
await client.startSession(
  conversationToken: 'token-from-your-backend',
  userId: 'user-123',
);
```

### Configuration Overrides

Customize agent behavior per session:

```dart
await client.startSession(
  agentId: 'your-agent-id',
  overrides: ConversationOverrides(
    agent: AgentOverrides(
      firstMessage: 'Hello! How can I help you today?',
      prompt: 'You are a helpful assistant...',
      temperature: 0.7,
    ),
    tts: TtsOverrides(
      voiceId: 'custom-voice-id',
      stability: 0.5,
      similarityBoost: 0.8,
    ),
  ),
);
```

### Sending Messages

```dart
// Text message
client.sendUserMessage('Hello, agent!');

// Contextual update (background information)
client.sendContextualUpdate('User is viewing the checkout page');

// User activity signal (e.g., typing indicator)
client.sendUserActivity();
```

### Microphone Control

```dart
// Mute
await client.setMicMuted(true);

// Unmute
await client.setMicMuted(false);

// Toggle
await client.toggleMute();

// Check state
bool isMuted = client.isMuted;
```

### Feedback

```dart
// Check if feedback can be sent
if (client.canSendFeedback) {
  // Thumbs up
  client.sendFeedback(isPositive: true);

  // Thumbs down
  client.sendFeedback(isPositive: false);
}
```

### Client Tools

Register client-side tools that the agent can invoke:

```dart
class GetLocationTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    try {
      // Get device location
      final location = await _getCurrentLocation();

      return ClientToolResult.success({
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
    } catch (e) {
      return ClientToolResult.failure('Failed to get location: $e');
    }
  }
}

// Register the tool
final client = ConversationClient(
  clientTools: {
    'getUserLocation': GetLocationTool(),
    'logMessage': LogMessageTool(),
  },
  callbacks: ConversationCallbacks(
    onUnhandledClientToolCall: (call) {
      print('Unhandled tool: ${call.toolName}');
    },
  ),
);
```

### Callbacks

All available callbacks:

```dart
ConversationClient(
  callbacks: ConversationCallbacks(
    // Connection
    onConnect: ({required conversationId}) {},
    onDisconnect: (details) {},
    onStatusChange: ({required status}) {},
    onError: (message, [context]) {},

    // Messages
    onMessage: ({required message, required source}) {},
    onModeChange: ({required mode}) {},

    // Audio & VAD
    onAudio: (base64Audio) {},
    onVadScore: ({required vadScore}) {},

    // Events
    onInterruption: (event) {},
    onAgentChatResponsePart: (part) {},
    onConversationMetadata: (metadata) {},

    // Feedback
    onCanSendFeedbackChange: ({required canSendFeedback}) {},

    // Tools & MCP
    onUnhandledClientToolCall: (toolCall) {},
    onMcpToolCall: (toolCall) {},
    onAgentToolResponse: (response) {},

    // Debug
    onDebug: (data) {},
  ),
)
```

### Reactive State

The client extends `ChangeNotifier` for reactive updates:

```dart
_client.addListener(() {
  setState(() {
    // UI will rebuild when client state changes
  });
});

// Access state properties
ConversationStatus status = _client.status;
bool isSpeaking = _client.isSpeaking;
bool isMuted = _client.isMuted;
String? conversationId = _client.conversationId;
bool canSendFeedback = _client.canSendFeedback;
ConversationMode mode = _client.mode;
```

## Custom Endpoints & Data Residency

For self-hosted or region-specific deployments:

```dart
final client = ConversationClient(
  apiEndpoint: 'https://api.eu.residency.elevenlabs.io',
  websocketUrl: 'wss://livekit.rtc.eu.residency.elevenlabs.io',
);
```

**Important**: Both endpoints must point to the same geographic region to avoid authentication errors.

## API Reference

### ConversationClient

#### Properties

- `status` - Current connection status
- `isSpeaking` - Whether the agent is speaking
- `mode` - Current mode (listening/speaking)
- `conversationId` - Active conversation ID
- `isMuted` - Microphone mute state
- `canSendFeedback` - Whether feedback can be sent

#### Methods

- `startSession()` - Start a conversation
- `endSession()` - End the conversation
- `sendUserMessage()` - Send text message
- `sendContextualUpdate()` - Send background context
- `sendUserActivity()` - Signal user activity
- `sendFeedback()` - Send thumbs up/down
- `setMicMuted()` - Set mute state
- `toggleMute()` - Toggle mute
- `getId()` - Get conversation ID

### Enums

#### ConversationStatus

- `disconnected` - Not connected
- `connecting` - Connecting to agent
- `connected` - Active conversation
- `disconnecting` - Closing connection

#### ConversationMode

- `listening` - Agent is listening
- `speaking` - Agent is speaking

#### Role

- `user` - User message
- `ai` - Agent message

## Examples

Check out the [example app](example/) for a comprehensive demonstration of all features.

## Compatibility

This SDK maintains API compatibility with the ElevenLabs [Android SDK](https://github.com/elevenlabs/elevenlabs-android) and [React Native SDK](https://github.com/elevenlabs/elevenlabs-react-native):

- Similar method names and signatures
- Equivalent configuration models
- Compatible event types
- Shared protocol schema

## Architecture

```
┌─────────────────────────────────────────┐
│      ConversationClient                 │
│  (ChangeNotifier for reactive state)    │
└─────────────────┬───────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
┌───▼────┐  ┌────▼────┐  ┌────▼────┐
│LiveKit │  │ Message │  │ Message │
│Manager │  │ Handler │  │ Sender  │
└───┬────┘  └────┬────┘  └────┬────┘
    │            │            │
    └────────────┼────────────┘
                 │
        ┌────────▼────────┐
        │   LiveKit Room  │
        │  (WebRTC + Data)│
        └─────────────────┘
```

## Troubleshooting

### Permission Denied

Ensure microphone permissions are granted in system settings.

### Connection Failures

- Verify agent ID is correct
- Check network connectivity
- Ensure firewall allows WebRTC

### Audio Issues

- Test microphone with other apps
- Check LiveKit has audio permissions
- Try toggling mute/unmute

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📚 [Documentation](https://elevenlabs.io/docs)
- 💬 [Discord Community](https://discord.gg/elevenlabs)
- 📧 [Email Support](mailto:support@elevenlabs.io)
- 🐛 [Issue Tracker](https://github.com/elevenlabs/elevenlabs-flutter/issues)

## Related

- [ElevenLabs Android SDK](https://github.com/elevenlabs/elevenlabs-android)
- [ElevenLabs React Native SDK](https://github.com/elevenlabs/elevenlabs-react-native)
- [LiveKit Flutter SDK](https://github.com/livekit/client-sdk-flutter)
