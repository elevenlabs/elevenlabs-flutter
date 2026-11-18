import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:elevenlabs_agents/src/connection/livekit_manager.dart';

/// LiveKitManager that connects without a server, so tests can inject data
/// messages.
class _FakeLiveKitManager extends LiveKitManager {
  final _data = StreamController<Map<String, dynamic>>.broadcast();
  final _disconnects = StreamController<String>.broadcast();
  final _roomReady = StreamController<void>.broadcast();
  final _speaking = StreamController<bool>.broadcast();

  @override
  Stream<Map<String, dynamic>> get dataStream => _data.stream;

  @override
  Stream<String> get disconnectStream => _disconnects.stream;

  @override
  Stream<void> get roomReadyStream => _roomReady.stream;

  @override
  Stream<bool> get speakingStateStream => _speaking.stream;

  @override
  Future<void> connect(String serverUrl, String token) async {
    _roomReady.add(null);
  }

  @override
  Future<void> sendMessage(Map<String, dynamic> message) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _data.close();
    await _disconnects.close();
    await _roomReady.close();
    await _speaking.close();
  }

  void injectMessage(Map<String, dynamic> message) => _data.add(message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ConversationClient delivers events without a dedicated callback',
      () async {
    final liveKit = _FakeLiveKitManager();
    final received = <Map<String, dynamic>>[];
    final client = ConversationClient.withLiveKitManager(
      liveKitManager: liveKit,
      callbacks: ConversationCallbacks(onIncomingEvent: received.add),
    );
    await client.startSession(conversationToken: 'token');

    final metadata = {
      'type': 'agent_response_metadata',
      'agent_response_metadata_event': {
        'metadata': {'source': 'test'},
        'event_id': 3,
      },
    };
    final clientError = {
      'type': 'client_error',
      'error_event': {
        'code': 1008,
        'error_name': 'policy_violation',
        'message': 'bad input',
      },
    };
    liveKit.injectMessage(metadata);
    liveKit.injectMessage(clientError);
    await Future<void>.delayed(Duration.zero);

    expect(received, [metadata, clientError]);

    await client.endSession();
    await liveKit.dispose();
  });
}
