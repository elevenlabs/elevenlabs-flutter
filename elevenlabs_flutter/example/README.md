# ElevenLabs Flutter Example

A comprehensive example application demonstrating the ElevenLabs Flutter SDK features.

## Features Demonstrated

- **Connection Management**: Starting and ending conversation sessions
- **Real-time Audio**: Bidirectional voice communication with AI agents
- **Text Messaging**: Sending text messages to the agent
- **Contextual Updates**: Sending contextual information to the agent
- **User Activity**: Signaling user typing activity
- **Feedback**: Thumbs up/down feedback on agent responses
- **Microphone Control**: Mute/unmute functionality
- **Client Tools**: Example implementation of client-side tools
- **State Management**: Reactive UI updates using ChangeNotifier
- **Message History**: Display of conversation transcript

## Setup

### 1. Get an Agent ID

1. Visit [ElevenLabs](https://elevenlabs.io) and create an account
2. Create a conversational AI agent in the dashboard
3. Copy your agent ID

### 2. Configure Permissions

#### iOS

Add microphone permission to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for voice conversations</string>
```

Update `ios/Podfile` minimum version:

```ruby
platform :ios, '13.0'
```

#### Android

Permissions are already configured in the example's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

Set `minSdkVersion` to 21 in `android/app/build.gradle`.

### 3. Run the Example

```bash
cd example
flutter pub get
flutter run
```

## Usage

1. **Enter Agent ID**: Input your ElevenLabs agent ID
2. **Start Session**: Tap the "Start" button to connect
3. **Voice Chat**: Speak naturally with the AI agent
4. **Text Messages**: Type and send text messages
5. **Contextual Updates**: Use the note icon to send background context
6. **Feedback**: Give thumbs up/down on agent responses
7. **Mute Control**: Toggle microphone with the mic button
8. **End Session**: Tap "End" to disconnect

## Client Tools Example

The example includes a simple client tool implementation:

```dart
class LogMessageTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    final message = parameters['message'] as String?;
    if (message == null) {
      return ClientToolResult.failure('Missing message parameter');
    }

    debugPrint('📝 Client Tool Log: $message');

    // Return null for fire-and-forget tools
    return null;
  }
}
```

Register tools when creating the client:

```dart
ConversationClient(
  clientTools: {
    'logMessage': LogMessageTool(),
  },
)
```

## Callbacks

The example demonstrates all available callbacks:

- `onConnect`: Connection established
- `onDisconnect`: Connection closed
- `onMessage`: Transcription or agent response received
- `onModeChange`: Agent switches between listening/speaking
- `onStatusChange`: Connection status changes
- `onError`: Error occurred
- `onCanSendFeedbackChange`: Feedback availability changed
- `onDebug`: Debug information (useful for development)

## Customization

### Custom Endpoints

For data residency or self-hosted deployments:

```dart
ConversationClient(
  apiEndpoint: 'https://api.eu.residency.elevenlabs.io',
  websocketUrl: 'wss://livekit.rtc.eu.residency.elevenlabs.io',
)
```

### Configuration Overrides

Customize agent behavior:

```dart
await client.startSession(
  agentId: 'your-agent-id',
  overrides: ConversationOverrides(
    agent: AgentOverrides(
      firstMessage: 'Custom greeting!',
      temperature: 0.7,
    ),
    tts: TtsOverrides(
      stability: 0.5,
      similarityBoost: 0.8,
    ),
  ),
)
```

## Troubleshooting

### Permission Issues

If microphone permissions are denied, the app will show an error. Grant permissions in system settings.

### Connection Failures

- Verify your agent ID is correct
- Check internet connectivity
- Ensure firewall allows WebRTC connections

### Audio Issues

- Test microphone with another app
- Check that LiveKit has audio permissions
- Try toggling mute/unmute

## Learn More

- [ElevenLabs Documentation](https://elevenlabs.io/docs)
- [Flutter Documentation](https://flutter.dev/docs)
- [LiveKit Documentation](https://docs.livekit.io)

