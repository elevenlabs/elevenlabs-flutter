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

/// Fake whose first connect stalls until [releaseFirstConnect], then fails as
/// a connect cancelled by a disconnect does.
class _StallingLiveKitManager extends _FakeLiveKitManager {
  final _firstConnect = Completer<void>();
  int connectCalls = 0;

  void releaseFirstConnect() => _firstConnect.complete();

  @override
  Future<void> connect(String serverUrl, String token) async {
    if (++connectCalls == 1) {
      await _firstConnect.future;
      throw StateError('Disconnected before connecting to the room');
    }
    await super.connect(serverUrl, token);
  }
}

class _FakeRemoteParticipant extends Fake implements livekit.RemoteParticipant {
  _FakeRemoteParticipant(this.identity);

  @override
  final String identity;
}

class _FakeMicrophone extends Fake implements livekit.LocalAudioTrack {
  bool stopped = false;

  @override
  Future<bool> stop() async {
    stopped = true;
    return true;
  }
}

class _FakePublication extends Fake
    implements livekit.LocalTrackPublication<livekit.LocalAudioTrack> {}

class _FakeLocalParticipant extends Fake implements livekit.LocalParticipant {
  _FakeLocalParticipant(this._room);

  final _FakeRoom _room;

  @override
  Future<livekit.LocalTrackPublication<livekit.LocalAudioTrack>>
      publishAudioTrack(
    livekit.LocalAudioTrack track, {
    livekit.AudioPublishOptions? publishOptions,
  }) async {
    _room.calls.add('publish');
    await _room.onPublish?.call();
    return _FakePublication();
  }
}

class _FakeRoom extends Fake implements livekit.Room {
  _FakeRoom({
    this.connectionState = livekit.ConnectionState.disconnected,
    this.onConnect,
    this.onPublish,
    this.onDisconnect,
  });

  final Future<void> Function()? onConnect;
  final Future<void> Function()? onPublish;
  final Future<void> Function()? onDisconnect;
  final calls = <String>[];
  final _events = livekit.Room();

  @override
  livekit.ConnectionState connectionState;

  @override
  late final livekit.LocalParticipant localParticipant =
      _FakeLocalParticipant(this);

  @override
  livekit.EventsListener<livekit.RoomEvent> createListener({
    bool synchronized = false,
  }) =>
      _events.createListener(synchronized: synchronized);

  @override
  Future<void> connect(
    String url,
    String token, {
    livekit.ConnectOptions? connectOptions,
    livekit.RoomOptions? roomOptions,
    livekit.FastConnectOptions? fastConnectOptions,
  }) async {
    calls.add('connect');
    connectionState = livekit.ConnectionState.connecting;
    await onConnect?.call();
    connectionState = livekit.ConnectionState.connected;
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    await onDisconnect?.call();
    connectionState = livekit.ConnectionState.disconnected;
  }

  @override
  Future<bool> dispose() async {
    calls.add('dispose');
    return true;
  }
}

/// LiveKitManager whose microphone is acquired by [onAcquireMicrophone]
class _MicrophoneLiveKitManager extends LiveKitManager {
  _MicrophoneLiveKitManager(this.onAcquireMicrophone, {this.onCreateRoom});

  final Future<livekit.LocalAudioTrack> Function(_MicrophoneLiveKitManager)
      onAcquireMicrophone;
  final livekit.Room Function()? onCreateRoom;

  @override
  Future<livekit.LocalAudioTrack> acquireMicrophone() =>
      onAcquireMicrophone(this);

  @override
  livekit.Room createRoom() => onCreateRoom?.call() ?? super.createRoom();
}

List<Object> _dataErrors(LiveKitManager manager) {
  final errors = <Object>[];
  manager.dataStream.listen((_) {}, onError: errors.add);
  return errors;
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
    late bool endCallRequested;
    late ConversationClient client;

    setUp(() async {
      liveKit = _FakeLiveKitManager();
      reasons = [];
      endCallRequested = false;
      client = ConversationClient.withLiveKitManager(
        liveKitManager: liveKit,
        callbacks: ConversationCallbacks(
          onDisconnect: (details) => reasons.add(details.reason),
          onEndCallRequested: () => endCallRequested = true,
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

    test('reports an agent end_call as ended by the agent', () async {
      liveKit.injectMessage(_agentToolResponse('end_call'));
      await _settle();

      expect(reasons, ['agent']);
      expect(endCallRequested, isTrue);
      expect(client.status, ConversationStatus.disconnected);
    });

    test('does not end the session for other agent tools', () async {
      liveKit.injectMessage(_agentToolResponse('transfer_to_agent'));
      await _settle();

      expect(reasons, isEmpty);
      expect(client.status, ConversationStatus.connected);
    });

    test('notifies once when the agent leaves and the room then closes',
        () async {
      liveKit.emitDisconnect('agent');
      liveKit.emitDisconnect('error');
      await _settle();

      expect(reasons, ['agent']);
      expect(client.status, ConversationStatus.disconnected);
    });

    test('notifies once when the room fails and the agent then leaves',
        () async {
      liveKit.emitDisconnect('error');
      liveKit.emitDisconnect('agent');
      await _settle();

      expect(reasons, ['error']);
      expect(client.status, ConversationStatus.disconnected);
    });

    test('notifies once when an end_call is followed by the room closing',
        () async {
      liveKit.injectMessage(_agentToolResponse('end_call'));
      liveKit.emitDisconnect('error');
      await _settle();

      expect(reasons, ['agent']);
    });

    test('tears the room down when the agent leaves', () async {
      final callsBefore = liveKit.disconnectCalls;

      liveKit.emitDisconnect('agent');
      await _settle();

      expect(liveKit.disconnectCalls, callsBefore + 1);
    });

    test('does not notify again when endSession follows a server end',
        () async {
      liveKit.emitDisconnect('agent');
      await _settle();
      await client.endSession();

      expect(reasons, ['agent']);
    });
  });

  group('ConversationClient - session start', () {
    test('an ended start that fails later leaves the newer session connected',
        () async {
      final liveKit = _StallingLiveKitManager();
      addTearDown(liveKit.dispose);
      final client = ConversationClient.withLiveKitManager(
        liveKitManager: liveKit,
      );

      final first = expectLater(
        client.startSession(conversationToken: 'first'),
        throwsA(isA<StateError>()),
      );
      await client.endSession();
      await client.startSession(conversationToken: 'second');
      liveKit.releaseFirstConnect();
      await first;

      expect(client.status, ConversationStatus.connected);

      final callsBefore = liveKit.disconnectCalls;
      await client.endSession();

      expect(liveKit.disconnectCalls, callsBefore + 1);
      expect(client.status, ConversationStatus.disconnected);
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

    test('reports a room that fails to reconnect as an error, not the agent',
        () async {
      // A full reconnect removes every remote participant, the agent included,
      // before LiveKit knows whether the room comes back.
      _emit(room, const livekit.RoomReconnectingEvent());
      _emit(
        room,
        livekit.ParticipantDisconnectedEvent(
          participant: _FakeRemoteParticipant('agent-1'),
        ),
      );
      _emit(
        room,
        livekit.RoomDisconnectedEvent(
          reason: livekit.DisconnectReason.reconnectAttemptsExceeded,
        ),
      );
      await _settle();

      expect(reasons, ['error']);
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

  group('LiveKitManager - connect', () {
    // Nothing listens on this port, so a connect attempt fails fast.
    const unreachableUrl = 'ws://127.0.0.1:9';

    test('acquires the microphone before creating and connecting the room',
        () async {
      livekit.Room? roomWhenAcquiring;
      final room = _FakeRoom();
      final microphone = _FakeMicrophone();
      final manager = _MicrophoneLiveKitManager(
        (manager) async {
          roomWhenAcquiring = manager.room;
          room.calls.add('microphone');
          return microphone;
        },
        onCreateRoom: () => room,
      );
      addTearDown(manager.dispose);
      var ready = 0;
      manager.roomReadyStream.listen((_) => ready++);

      await manager.connect(unreachableUrl, 'token');
      await _settle();

      expect(roomWhenAcquiring, isNull);
      expect(room.calls, ['microphone', 'connect', 'publish']);
      expect(microphone.stopped, isFalse);
      expect(ready, 1);
    });

    test('disconnects a room that never connected without waiting for it',
        () async {
      final manager = LiveKitManager();
      addTearDown(manager.dispose);
      final errors = _dataErrors(manager);
      manager.listenToRoom(livekit.Room());

      await manager.disconnect();
      await _settle();

      expect(errors, isEmpty);
      expect(manager.room, isNull);
    });

    test('a disconnect in progress leaves a newer room in place', () async {
      final disconnected = Completer<void>();
      final oldRoom = _FakeRoom(
        connectionState: livekit.ConnectionState.connected,
        onDisconnect: () => disconnected.future,
      );
      final newRoom = _FakeRoom();
      final manager = LiveKitManager();
      addTearDown(manager.dispose);
      manager.listenToRoom(oldRoom);

      final disconnecting = manager.disconnect();
      await _settle();
      manager.listenToRoom(newRoom);
      disconnected.complete();
      await disconnecting;

      expect(oldRoom.calls, ['disconnect', 'dispose']);
      expect(manager.room, same(newRoom));
    });

    test('waits for a disconnect in progress before acquiring the microphone',
        () async {
      final disconnected = Completer<void>();
      final oldRoom = _FakeRoom(
        connectionState: livekit.ConnectionState.connected,
        onDisconnect: () => disconnected.future,
      );
      var acquired = false;
      final manager = _MicrophoneLiveKitManager(
        (_) async {
          acquired = true;
          return _FakeMicrophone();
        },
        onCreateRoom: _FakeRoom.new,
      );
      addTearDown(manager.dispose);
      manager.listenToRoom(oldRoom);

      final disconnecting = manager.disconnect();
      await _settle();
      final connecting = expectLater(
        manager.connect(unreachableUrl, 'token'),
        throwsA(isA<StateError>()),
      );
      await _settle();
      expect(acquired, isFalse);

      disconnected.complete();
      await disconnecting;
      await manager.disconnect();
      await connecting;
    });

    test('stops the microphone when disconnected while the room connects',
        () async {
      final connecting = Completer<void>();
      final connected = Completer<void>();
      final room = _FakeRoom(
        onConnect: () {
          connecting.complete();
          return connected.future;
        },
      );
      final microphone = _FakeMicrophone();
      final manager = _MicrophoneLiveKitManager(
        (_) async => microphone,
        onCreateRoom: () => room,
      );
      addTearDown(manager.dispose);
      var ready = 0;
      manager.roomReadyStream.listen((_) => ready++);

      final connect = expectLater(
        manager.connect(unreachableUrl, 'token'),
        throwsA(isA<StateError>()),
      );
      await connecting.future;
      await manager.disconnect();

      expect(microphone.stopped, isTrue);
      expect(room.calls, ['connect', 'dispose']);

      connected.complete();
      await connect;
      await _settle();

      expect(room.calls, ['connect', 'dispose', 'disconnect', 'dispose']);
      expect(ready, 0);
    });

    test('tears the room down when publishing the microphone fails', () async {
      final room = _FakeRoom(
        onPublish: () async => throw Exception('Publish timed out'),
      );
      final microphone = _FakeMicrophone();
      final manager = _MicrophoneLiveKitManager(
        (_) async => microphone,
        onCreateRoom: () => room,
      );
      addTearDown(manager.dispose);

      await expectLater(
        manager.connect(unreachableUrl, 'token'),
        throwsA(isA<Exception>()),
      );

      expect(microphone.stopped, isTrue);
      expect(room.calls, ['connect', 'publish', 'disconnect', 'dispose']);
      expect(manager.room, isNull);
    });

    test('does not connect when disconnected while acquiring the microphone',
        () async {
      final acquiring = Completer<void>();
      final acquired = Completer<livekit.LocalAudioTrack>();
      final microphone = _FakeMicrophone();
      final manager = _MicrophoneLiveKitManager((_) {
        acquiring.complete();
        return acquired.future;
      });
      addTearDown(manager.dispose);

      final errors = _dataErrors(manager);

      final connecting = manager.connect(unreachableUrl, 'token');
      await acquiring.future;
      await manager.disconnect();
      acquired.complete(microphone);

      await expectLater(connecting, throwsA(isA<StateError>()));
      await _settle();
      expect(microphone.stopped, isTrue);
      expect(manager.room, isNull);
      expect(errors, isEmpty);
    });

    test(
        'does not acquire the microphone when disconnected while cleaning up '
        'the last room', () async {
      var acquired = false;
      final manager = _MicrophoneLiveKitManager((_) async {
        acquired = true;
        return _FakeMicrophone();
      });
      addTearDown(manager.dispose);
      manager.listenToRoom(livekit.Room());

      final connecting = expectLater(
        manager.connect(unreachableUrl, 'token'),
        throwsA(isA<StateError>()),
      );
      await manager.disconnect();

      await connecting;
      expect(acquired, isFalse);
      expect(manager.room, isNull);
    });

    test('stops the microphone when connecting to the room fails', () async {
      final microphone = _FakeMicrophone();
      final manager = _MicrophoneLiveKitManager((_) async => microphone);
      addTearDown(manager.dispose);

      await expectLater(
        manager.connect(unreachableUrl, 'token'),
        throwsA(anything),
      );
      expect(microphone.stopped, isTrue);
    });
  });
}
