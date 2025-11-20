![hero](assets/hero.png)

# ElevenLabs Agents Flutter SDK

[![pub package](https://img.shields.io/pub/v/elevenlabs_agents.svg)](https://pub.dev/packages/elevenlabs_agents)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Official Flutter SDK for the [ElevenLabs Agents Platform](https://elevenlabs.io). Build voice-enabled applications with real-time bidirectional audio communication powered by WebRTC via LiveKit.

## SDK status

This SDK is in beta - core functionality should work as expected but some edge cases might not be supported. If something is missing for your integration please open up an issue in this repo.

## Features

- **Real-time Voice Communication** - Full-duplex audio streaming with low latency
- **Text Messaging** - Send text messages and contextual updates during conversations
- **Client Tools** - Register device-side functions that agents can invoke
- **Reactive State Management** - Built on ChangeNotifier for Flutter-idiomatic patterns
- **Comprehensive Callbacks** - Fine-grained event handlers for all conversation events
- **Feedback System** - Built-in support for rating agent responses
- **Type Safety** - Complete Dart type definitions for all APIs
- **Data Residency** - Support for custom endpoints and regional deployments
- **Production Ready** - Built on LiveKit's proven WebRTC infrastructure

## Examples

The [example directory](example/) contains a full-featured demo application showing:

- Voice conversation with real-time audio
- Text messaging
- Mute/unmute controls
- Connection state management
- Feedback buttons
- Client tool implementation
- Conversation history display

Run the example:

```bash
cd example
flutter run
```

## Installation

Add to your `pubspec.yaml` (see version badge above):

```yaml
dependencies:
  elevenlabs_agents: ^[latest]
```

Install dependencies:

```bash
flutter pub get
```

## Platform Configuration

### iOS

Add microphone permission to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice conversations</string>
```

Set minimum iOS version in `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

Set minimum SDK version in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

## Quick Start

Here's a minimal example showing basic voice conversation functionality:

```dart
import 'package:flutter/material.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceAssistant extends StatefulWidget {
  const VoiceAssistant({super.key});

  @override
  State<VoiceAssistant> createState() => _VoiceAssistantState();
}

class _VoiceAssistantState extends State<VoiceAssistant> {
  late ConversationClient _client;
  final _messages = <String>[];

  @override
  void initState() {
    super.initState();
    _requestMicrophonePermission();
    _initializeClient();
  }

  Future<void> _requestMicrophonePermission() async {
    await Permission.microphone.request();
  }

  void _initializeClient() {
    _client = ConversationClient(
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) {
          print('Connected with ID: $conversationId');
        },
        onMessage: ({required message, required source}) {
          setState(() {
            _messages.add('${source.name}: $message');
          });
        },
        onModeChange: ({required mode}) {
          print('Mode changed: ${mode.name}');
        },
        onError: (message, [context]) {
          print('Error: $message');
        },
      ),
    );

    _client.addListener(() {
      setState(() {}); // Rebuild on state changes
    });
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  Future<void> _startConversation() async {
    try {
      await _client.startSession(
        agentId: 'your-agent-id-here',
        userId: 'user-123',
      );
    } catch (e) {
      print('Failed to start conversation: $e');
    }
  }

  Future<void> _endConversation() async {
    await _client.endSession();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _client.status == ConversationStatus.connected;
    final isDisconnected = _client.status == ConversationStatus.disconnected;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Assistant')),
      body: Column(
        children: [
          // Status indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: isConnected ? Colors.green : Colors.grey,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Status: ${_client.status.name}',
                  style: const TextStyle(color: Colors.white),
                ),
                if (_client.isSpeaking) ...[
                  const SizedBox(width: 16),
                  const Text(
                    'Agent Speaking',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isDisconnected ? _startConversation : null,
                        child: const Text('Start Conversation'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isConnected ? _endConversation : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('End Conversation'),
                      ),
                    ),
                  ],
                ),
                if (isConnected) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _client.toggleMute(),
                    icon: Icon(_client.isMuted ? Icons.mic_off : Icons.mic),
                    label: Text(_client.isMuted ? 'Unmute' : 'Mute'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## Core Concepts

### Starting a Conversation

#### Public Agent

For publicly available agents, provide just the agent ID:

```dart
await client.startSession(
  agentId: 'your-public-agent-id',
  userId: 'user-123',
);
```

#### Private Agent

For private agents, [generate a conversation token](https://elevenlabs.io/docs/api-reference/conversations/get-webrtc-token) from your backend and pass it to the SDK:

```dart
// Get token from your backend
final token = await yourBackend.getConversationToken();

await client.startSession(
  conversationToken: token,
  userId: 'user-123',
);
```

**Note:** Generating a token requires an ElevenLabs API key. Never expose this key on the client, instead fetch it from a backend service.

### Configuration Overrides

Customize agent behavior on a per-session basis:

```dart
await client.startSession(
  agentId: 'your-agent-id',
  overrides: ConversationOverrides(
    agent: AgentOverrides(
      firstMessage: 'Hello! How can I help you today?',
      prompt: 'You are a helpful customer service assistant...',
      language: 'en',
      temperature: 0.7,
      maxTokens: 1000,
    ),
    tts: TtsOverrides(
      voiceId: 'custom-voice-id',
      stability: 0.5,
      similarityBoost: 0.8,
      style: 0.0,
      useSpeakerBoost: true,
    ),
    conversation: ConversationSettingsOverrides(
      maxDurationSeconds: 600,
      turnTimeoutSeconds: 10,
      textOnly: false,
    ),
  ),
  dynamicVariables: {
    'user_name': 'Alice',
    'account_tier': 'premium',
  },
);
```

### Sending Messages

Send text messages and contextual updates during a conversation:

```dart
// Send a text message to the agent
client.sendUserMessage('I need help with my order');

// Send contextual information (invisible to user, visible to agent)
client.sendContextualUpdate('User is on order #12345 page');

// Send user activity signal, which will prevent the agent from speaking for ~2 seconds
// Useful for when a user is e.g. typing a message
client.sendUserActivity();
```

### Microphone Control

```dart
// Mute the microphone
await client.setMicMuted(true);

// Unmute the microphone
await client.setMicMuted(false);

// Toggle mute state
await client.toggleMute();

// Check current mute state
if (client.isMuted) {
  print('Microphone is muted');
}
```

### Feedback System

Allow users to rate agent responses:

```dart
// In your UI, show feedback buttons when available
if (client.canSendFeedback) {
  // User taps thumbs up
  client.sendFeedback(isPositive: true);

  // Or thumbs down
  client.sendFeedback(isPositive: false);
}

// Listen for feedback state changes
ConversationClient(
  callbacks: ConversationCallbacks(
    onCanSendFeedbackChange: ({required canSendFeedback}) {
      setState(() {
        // Update UI to show/hide feedback buttons
      });
    },
  ),
);
```

## Client Tools

Register client-side tools that the agent can invoke to access device capabilities:

```dart
// Define a tool
class GetLocationTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    try {
      final location = await Geolocator.getCurrentPosition();

      return ClientToolResult.success({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'accuracy': location.accuracy,
      });
    } catch (e) {
      return ClientToolResult.failure('Failed to get location: $e');
    }
  }
}

class LogMessageTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    final message = parameters['message'] as String?;

    if (message == null || message.isEmpty) {
      return ClientToolResult.failure('Missing message parameter');
    }

    print('Agent logged: $message');

    // For tools where no response is needed, don't return anything
  }
}

// Register tools with the client
final client = ConversationClient(
  clientTools: {
    'getUserLocation': GetLocationTool(),
    'logMessage': LogMessageTool(),
  },
  callbacks: ConversationCallbacks(
    onUnhandledClientToolCall: (toolCall) {
      print('Agent called unimplemented tool: ${toolCall.toolName}');
      print('Parameters: ${toolCall.parameters}');
    },
  ),
);
```

Tool execution flow:
1. Agent decides to invoke a tool
2. SDK receives tool call request
3. SDK looks up and executes the registered tool
4. Tool returns success or failure result
5. SDK sends result back to agent
6. Agent continues conversation with the result

## Callbacks

The SDK provides comprehensive callbacks for all conversation events:

```dart
ConversationClient(
  callbacks: ConversationCallbacks(
    // Connection lifecycle
    onConnect: ({required conversationId}) {
      print('Connected: $conversationId');
    },
    onDisconnect: (details) {
      print('Disconnected: ${details.reason}');
    },
    onStatusChange: ({required status}) {
      print('Status: ${status.name}');
    },
    onError: (message, [context]) {
      print('Error: $message');
    },

    // Messages and transcripts
    onMessage: ({required message, required source}) {
      print('[${source.name}] $message');
    },
    onModeChange: ({required mode}) {
      // Called when conversation mode changes
      if (mode == ConversationMode.speaking) {
        print('Agent started speaking');
      } else {
        print('Agent is listening');
      }
    },
    onTentativeUserTranscript: ({required transcript, required eventId}) {
      // Real-time transcription as user speaks
      print('User speaking: $transcript');
    },
    onUserTranscript: ({required transcript, required eventId}) {
      // Finalized user transcription
      print('User said: $transcript');
    },
    onTentativeAgentResponse: ({required response}) {
      // Agent's streaming text response
      print('Agent composing: $response');
    },
    onAgentResponseCorrection: (correction) {
      // When agent corrects its response
      print('Agent corrected: $correction');
    },

    // Conversation state
    onConversationMetadata: (metadata) {
      print('Conversation ID: ${metadata.conversationId}');
      print('Audio formats: ${metadata.agentOutputAudioFormat}');
    },

    // Audio and voice activity
    onVadScore: ({required vadScore}) {
      // Voice activity detection score (0.0 to 1.0)
      print('VAD score: $vadScore');
    },
    onInterruption: (event) {
      print('User interrupted agent');
    },

    // Feedback
    onCanSendFeedbackChange: ({required canSendFeedback}) {
      // Show/hide feedback buttons
      setState(() {});
    },

    // Tools
    onUnhandledClientToolCall: (toolCall) {
      print('Unhandled tool: ${toolCall.toolName}');
    },
    onAgentToolResponse: (response) {
      print('Tool ${response.toolName} executed');
    },

    // MCP (Model Context Protocol)
    onMcpToolCall: (toolCall) {
      print('MCP tool: ${toolCall.toolName}');
    },
    onMcpConnectionStatus: (status) {
      print('MCP integrations: ${status.integrations.length}');
    },

    // ASR (Automatic Speech Recognition)
    onAsrInitiationMetadata: (metadata) {
      print('ASR metadata: ${metadata}');
    },

    // Streaming response parts
    onAgentChatResponsePart: (part) {
      // Streaming text chunks: start, delta, or stop
      print('Agent text [${part.type}]: ${part.text}');
    },

    // Debug (all raw events), very noisy
    onDebug: (data) {
      print('Debug: $data');
    },
  ),
);
```

## Reactive State Management

The `ConversationClient` extends `ChangeNotifier`, making it easy to integrate with Flutter's reactive patterns:

```dart
class _MyWidgetState extends State<MyWidget> {
  late ConversationClient _client;

  @override
  void initState() {
    super.initState();
    _client = ConversationClient();

    // Listen to all state changes
    _client.addListener(_onClientStateChanged);
  }

  void _onClientStateChanged() {
    setState(() {
      // Widget rebuilds when client state changes
    });
  }

  @override
  void dispose() {
    _client.removeListener(_onClientStateChanged);
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access reactive state properties
    return Column(
      children: [
        Text('Status: ${_client.status.name}'),
        Text('Speaking: ${_client.isSpeaking}'),
        Text('Muted: ${_client.isMuted}'),
        if (_client.conversationId != null)
          Text('ID: ${_client.conversationId}'),
        if (_client.canSendFeedback)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.thumb_up),
                onPressed: () => _client.sendFeedback(isPositive: true),
              ),
              IconButton(
                icon: const Icon(Icons.thumb_down),
                onPressed: () => _client.sendFeedback(isPositive: false),
              ),
            ],
          ),
      ],
    );
  }
}
```

## Regional Deployments and Data Residency

For self-hosted deployments or region-specific requirements:

```dart
final client = ConversationClient(
  apiEndpoint: 'https://api.eu.elevenlabs.io',
  websocketUrl: 'wss://livekit.rtc.eu.elevenlabs.io',
);
```

**Important**: Both the API endpoint and WebSocket URL must point to the same geographic region to avoid authentication errors.

## API Reference

### ConversationClient

#### Constructor

```dart
ConversationClient({
  String? apiEndpoint,  // Default: 'https://api.elevenlabs.io'
  String? websocketUrl, // Default: 'wss://livekit.rtc.elevenlabs.io'
  ConversationCallbacks? callbacks,
  Map<String, ClientTool>? clientTools,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `status` | `ConversationStatus` | Current connection status |
| `isSpeaking` | `bool` | Whether the agent is currently speaking |
| `isMuted` | `bool` | Whether the microphone is muted |
| `conversationId` | `String?` | Unique identifier for the active conversation |
| `canSendFeedback` | `bool` | Whether feedback can be sent for the last response |

#### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `startSession({...})` | `Future<void>` | Start a conversation session |
| `endSession()` | `Future<void>` | End the current conversation |
| `sendUserMessage(String)` | `void` | Send a text message |
| `sendContextualUpdate(String)` | `void` | Send background context |
| `sendUserActivity()` | `void` | Signal user activity |
| `sendFeedback({required bool})` | `void` | Send feedback (like/dislike) |
| `setMicMuted(bool)` | `Future<void>` | Set microphone mute state |
| `toggleMute()` | `Future<void>` | Toggle microphone mute state |
| `dispose()` | `void` | Clean up resources |

#### startSession Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `agentId` | `String?` | * | Public agent ID |
| `conversationToken` | `String?` | * | Signed token from your backend |
| `userId` | `String?` | No | User identifier for analytics |
| `overrides` | `ConversationOverrides?` | No | Session-specific configuration |
| `customLlmExtraBody` | `Map<String, dynamic>?` | No | Custom LLM parameters |
| `dynamicVariables` | `Map<String, dynamic>?` | No | Runtime variables for prompts |

\* Either `agentId` or `conversationToken` must be provided

### Enums

#### ConversationStatus

- `disconnected` - Not connected to any agent
- `connecting` - Connection in progress
- `connected` - Active conversation
- `disconnecting` - Disconnect in progress

#### ConversationMode

- `listening` - Agent is listening to user
- `speaking` - Agent is speaking

#### Role

- `user` - Message from the user
- `ai` - Message from the agent

## Troubleshooting

### Microphone Permission Denied

Ensure permissions are properly configured in platform files and granted by the user.

**iOS**: Check Info.plist has NSMicrophoneUsageDescription
**Android**: Check AndroidManifest.xml has RECORD_AUDIO permission

### Connection Failures

- Verify your agent ID or conversation token is correct
- Check network connectivity and firewall settings
- Ensure WebRTC ports are not blocked (UDP 3478-3479, TCP 443)
- For private agents, verify your backend token generation is correct

### Poor Audio Quality

- Check microphone permissions
- Verify device microphone is working in other apps
- Check network bandwidth (voice requires steady connection)
- Try on a different network to rule out firewall issues

### Agent Not Responding

- Verify the agent is properly configured in your ElevenLabs dashboard
- Check that the agent has appropriate tools and knowledge base
- Monitor the `onDebug` callback for detailed event logs
- Check `onError` callback for specific error messages

### Tool Calls Not Working

- Ensure tool names match exactly between agent config and client registration
- Verify ClientTool implementations return proper ClientToolResult
- Check `onUnhandledClientToolCall` for tools the agent tried to call
- Use `onDebug` to see the raw tool call messages

## Testing

```bash
# Run tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

## Platform Support

| Platform | Supported | Min Version |
|----------|-----------|-------------|
| Android  | Yes       | API 21 (Android 5.0) |
| iOS      | Yes       | iOS 13.0 |

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

- Documentation: [https://elevenlabs.io/docs](https://elevenlabs.io/docs)
- Discord Community: [https://discord.gg/elevenlabs](https://discord.gg/elevenlabs)
- Email Support: support@elevenlabs.io
- Issue Tracker: [GitHub Issues](https://github.com/elevenlabs/elevenlabs-flutter/issues)

## Related Projects

- [ElevenLabs Android SDK](https://github.com/elevenlabs/elevenlabs-android)
- [ElevenLabs React Native SDK](https://github.com/elevenlabs/elevenlabs-react-native)
- [LiveKit Flutter SDK](https://github.com/livekit/client-sdk-flutter)
- [ElevenLabs API Documentation](https://elevenlabs.io/docs)
