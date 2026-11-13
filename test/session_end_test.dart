import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:elevenlabs_agents/src/connection/livekit_manager.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;

/// LiveKitManager that connects without a server, so tests can inject data
/// messages and disconnect events.
class _FakeLiveKitManager extends LiveKitManager {
  final _data = StreamController<Map<String, dynamic>>.broadcast();
  final _disconnects = StreamController<String>.broadcast();
  final _roomReady = StreamController<void>.broadcast();
  final _speaking = StreamController<bool>.broadcast();
  int disconnectCalls = 0;

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
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  Future<void> dispose() async {
    await _data.close();
    await _disconnects.close();
    await _roomReady.close();
    await _speaking.close();
  }

  void injectMessage(Map<String, dynamic> message) => _data.add(message);

  void emitDisconnect(String reason) => _disconnects.add(reason);
}

class _FakeRemoteParticipant extends Fake implements livekit.RemoteParticipant {
  _FakeRemoteParticipant(this.identity);

  @override
  final String identity;
}

Map<String, dynamic> _agentToolResponse(String toolName) => {
      'type': 'agent_tool_response',
      'agent_tool_response': {
        'tool_name': toolName,
        'tool_call_id': 'call-1',
        'tool_type': 'system',
        'is_error': false,
        'event_id': 1,
      },
    };

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void _emit(livekit.Room room, livekit.RoomEvent event) {
  // LiveKit only emits room events itself; tests stand in for its engine.
  // ignore: invalid_use_of_internal_member
  room.events.emit(event);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationClient - session end', () {
    late _FakeLiveKitManager liveKit;
    late List<String> reasons;
    late ConversationClient client;

    setUp(() async {
      liveKit = _FakeLiveKitManager();
      reasons = [];
      client = ConversationClient.withLiveKitManager(
        liveKitManager: liveKit,
        callbacks: ConversationCallbacks(
          onDisconnect: (details) => reasons.add(details.reason),
        ),
      );
      await client.startSession(conversationToken: 'token');
      expect(client.status, ConversationStatus.connected);
    });

    tearDown(() => liveKit.dispose());

    test('reports endSession as ended by the user', () async {
      await client.endSession();

      expect(reasons, ['user']);
      expect(client.status, ConversationStatus.disconnected);
    });

    test('does not end the session for other agent tools', () async {
      liveKit.injectMessage(_agentToolResponse('transfer_to_agent'));
      await _settle();

      expect(reasons, isEmpty);
      expect(client.status, ConversationStatus.connected);
    });

    test('does not notify again when endSession follows a server end',
        () async {
      liveKit.emitDisconnect('agent');
      await _settle();
      await client.endSession();

      expect(reasons, ['agent']);
    });
  });

  group('LiveKitManager - disconnect events', () {
    late LiveKitManager manager;
    late livekit.Room room;
    late List<String> reasons;

    setUp(() {
      manager = LiveKitManager();
      room = livekit.Room();
      reasons = [];
      manager.disconnectStream.listen(reasons.add);
      manager.listenToRoom(room);
    });

    test('reports the agent leaving the room as an agent end', () async {
      _emit(
        room,
        livekit.ParticipantDisconnectedEvent(
          participant: _FakeRemoteParticipant('agent-1'),
        ),
      );
      await _settle();

      expect(reasons, ['agent']);
    });

    test('ignores other participants leaving the room', () async {
      _emit(
        room,
        livekit.ParticipantDisconnectedEvent(
          participant: _FakeRemoteParticipant('someone-else'),
        ),
      );
      await _settle();

      expect(reasons, isEmpty);
    });

    test('reports the agent leaving after the room has reconnected', () async {
      _emit(room, const livekit.RoomReconnectingEvent());
      _emit(room, const livekit.RoomReconnectedEvent());
      _emit(
        room,
        livekit.ParticipantDisconnectedEvent(
          participant: _FakeRemoteParticipant('agent-1'),
        ),
      );
      await _settle();

      expect(reasons, ['agent']);
    });
  });
}
