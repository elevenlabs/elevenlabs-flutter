import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Manages LiveKit Room connection and audio tracks
class LiveKitManager {
  static const _roomOptions = RoomOptions(
    defaultAudioPublishOptions: AudioPublishOptions(
      encoding: AudioEncoding.presetSpeech,
    ),
  );

  static const _audioCaptureOptions = AudioCaptureOptions(
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
  );

  Room? _room;
  EventsListener<RoomEvent>? _eventsListener;
  LocalAudioTrack? _unpublishedMicrophone;
  Future<void> _tearingDown = Future.value();
  Timer? _speakingDebounceTimer;
  bool _lastSpeakingState = false;

  /// Whether LiveKit is running a full reconnect. It removes every remote
  /// participant when one starts, so the agent leaving then is not an end.
  bool _reconnecting = false;

  /// Bumped by [connect] and [disconnect], so a connect knows it was cancelled
  int _disconnects = 0;

  /// Stream controller for incoming data messages
  final _dataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming data messages
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  /// Stream controller for connection state changes
  final _stateStreamController = StreamController<ConnectionState>.broadcast();

  /// Stream of connection state changes
  Stream<ConnectionState> get stateStream => _stateStreamController.stream;

  /// Stream controller for disconnect events with reasons
  final _disconnectStreamController = StreamController<String>.broadcast();

  /// Stream of disconnect events with reasons ('agent', 'user', or 'error')
  Stream<String> get disconnectStream => _disconnectStreamController.stream;

  /// Stream controller for room ready event (connected + local participant published)
  final _roomReadyController = StreamController<void>.broadcast();

  /// Stream that emits when the room is fully ready to send messages
  Stream<void> get roomReadyStream => _roomReadyController.stream;

  /// Stream controller for agent speaking state
  final _speakingStateController = StreamController<bool>.broadcast();

  /// Stream that emits when agent starts/stops speaking
  Stream<bool> get speakingStateStream => _speakingStateController.stream;

  /// Current room instance
  Room? get room => _room;

  /// Whether the microphone is muted
  bool get isMuted =>
      !(_room?.localParticipant?.isMicrophoneEnabled() ?? false);

  /// Adds [value] to [controller] only if it is still open.
  ///
  /// LiveKit room events can be delivered via a queued microtask after the
  /// manager has been disposed and the controllers closed. Adding to a closed
  /// broadcast controller throws "Bad state: Cannot add new events after
  /// calling close", so every emission is routed through this guard.
  void _safeAdd<T>(StreamController<T> controller, T value) {
    if (!controller.isClosed) {
      controller.add(value);
    }
  }

  /// Adds [error] to [controller] only if it is still open. See [_safeAdd].
  void _safeAddError<T>(StreamController<T> controller, Object error) {
    if (!controller.isClosed) {
      controller.addError(error);
    }
  }

  /// Connects to a LiveKit server, once the microphone is acquired
  Future<void> connect(String serverUrl, String token) async {
    final disconnects = ++_disconnects;
    void throwIfDisconnected() {
      if (_disconnects != disconnects) {
        throw StateError('Disconnected before connecting to the room');
      }
    }

    LocalAudioTrack? microphone;
    Room? room;
    try {
      await _tearDown();
      throwIfDisconnected();

      // Enable speakerphone on Android
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (e) {
        _safeAddError(
          _dataStreamController,
          Exception('Could not enable speakerphone: $e'),
        );
      }

      throwIfDisconnected();
      microphone = await acquireMicrophone();
      throwIfDisconnected();

      room = createRoom();
      listenToRoom(room);
      _unpublishedMicrophone = microphone;

      await room.connect(serverUrl, token);
      throwIfDisconnected();

      await room.localParticipant!.publishAudioTrack(microphone);
      throwIfDisconnected();
      _unpublishedMicrophone = null;

      // Emit room ready event - connection is fully established and ready for messages
      _safeAdd(_roomReadyController, null);
    } catch (e) {
      await microphone?.stop();
      if (_disconnects == disconnects) {
        _safeAddError(
          _dataStreamController,
          Exception('LiveKit Connection Error: $e'),
        );
        await _tearDown();
      } else if (room != null) {
        // A connect torn down while its socket was opening can still join
        await _release(room: room, eventsListener: null, microphone: null);
      }
      rethrow;
    }
  }

  /// Creates the microphone track, which is where the OS can prompt or stall
  @visibleForTesting
  Future<LocalAudioTrack> acquireMicrophone() =>
      LocalAudioTrack.create(_audioCaptureOptions);

  @visibleForTesting
  Room createRoom() => Room(roomOptions: _roomOptions);

  /// Makes [room] the current room and forwards its events to the streams
  @visibleForTesting
  void listenToRoom(Room room) {
    _room = room;
    _reconnecting = false;

    // Set up specific event listeners
    _eventsListener = room.createListener();

    _eventsListener!
      ..on<RoomConnectedEvent>((event) {
        _safeAdd(_stateStreamController, ConnectionState.connected);
      })
      ..on<RoomDisconnectedEvent>((event) {
        _safeAdd(_stateStreamController, ConnectionState.disconnected);
        _safeAdd(_disconnectStreamController, 'error');
      })
      ..on<RoomReconnectingEvent>((event) {
        _reconnecting = true;
        _safeAdd(_stateStreamController, ConnectionState.reconnecting);
      })
      ..on<RoomReconnectedEvent>((event) {
        _reconnecting = false;
        _safeAdd(_stateStreamController, ConnectionState.connected);
      })
      ..on<DataReceivedEvent>((event) {
        // Handle incoming data messages
        try {
          final data = utf8.decode(event.data);
          final message = jsonDecode(data) as Map<String, dynamic>;
          _safeAdd(_dataStreamController, message);
        } on FormatException catch (e) {
          _safeAddError(
            _dataStreamController,
            Exception('Failed to decode message data: ${e.message}'),
          );
        } catch (e) {
          _safeAddError(
            _dataStreamController,
            Exception('Error processing data message: $e'),
          );
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        // If the agent disconnects, we should end the session. If the room
        // then fails to reconnect, RoomDisconnectedEvent reports the error.
        if (!_reconnecting && event.participant.identity.startsWith('agent-')) {
          _safeAdd(_stateStreamController, ConnectionState.disconnected);
          _safeAdd(_disconnectStreamController, 'agent');
        }
      })
      ..on<AudioPlaybackStatusChanged>((event) async {
        // Handle audio playback issues (especially for iOS)
        if (!room.canPlaybackAudio) {
          try {
            await room.startAudio();
          } catch (e) {
            _safeAddError(
              _dataStreamController,
              Exception('Failed to start audio playback: $e'),
            );
          }
        }
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        // Check if agent is in the active speakers list
        final agentIsSpeaking = event.speakers.any(
          (speaker) => speaker.identity.startsWith('agent-'),
        );
        _handleSpeakingStateChange(agentIsSpeaking);
      });
  }

  /// Sends a data message to the room
  Future<void> sendMessage(Map<String, dynamic> message) async {
    final currentRoom = _room;
    if (currentRoom == null) {
      throw StateError('Not connected to room');
    }

    try {
      final encoded = jsonEncode(message);
      final bytes = utf8.encode(encoded);

      await currentRoom.localParticipant?.publishData(bytes, reliable: true);
    } catch (e) {
      _safeAddError(
        _dataStreamController,
        Exception('Failed to send message: $e'),
      );
      rethrow;
    }
  }

  /// Sets the microphone mute state
  Future<void> setMicMuted(bool muted) async {
    await _room?.localParticipant?.setMicrophoneEnabled(!muted);
  }

  /// Toggles the microphone mute state
  Future<void> toggleMute() async {
    final currentlyEnabled =
        _room?.localParticipant?.isMicrophoneEnabled() ?? false;
    await _room?.localParticipant?.setMicrophoneEnabled(!currentlyEnabled);
  }

  /// Handles speaking state changes with debouncing to prevent flickering
  void _handleSpeakingStateChange(bool isSpeaking) {
    if (isSpeaking) {
      // Agent started speaking - immediately update and cancel any pending timer
      _speakingDebounceTimer?.cancel();
      _speakingDebounceTimer = null;

      if (_lastSpeakingState != isSpeaking) {
        _lastSpeakingState = isSpeaking;
        _safeAdd(_speakingStateController, isSpeaking);
      }
    } else {
      // Agent stopped speaking - debounce to avoid flickering during pauses
      _speakingDebounceTimer?.cancel();
      _speakingDebounceTimer = Timer(const Duration(milliseconds: 800), () {
        if (_lastSpeakingState != isSpeaking) {
          _lastSpeakingState = isSpeaking;
          _safeAdd(_speakingStateController, isSpeaking);
        }
      });
    }
  }

  /// Disconnects from the LiveKit server and cleans up resources
  Future<void> disconnect() async {
    _disconnects++;
    await _tearDown();
  }

  Future<void> _tearDown() {
    // Cancel any pending debounce timer
    _speakingDebounceTimer?.cancel();
    _speakingDebounceTimer = null;
    _lastSpeakingState = false;

    final room = _room;
    final eventsListener = _eventsListener;
    final microphone = _unpublishedMicrophone;
    _room = null;
    _eventsListener = null;
    _unpublishedMicrophone = null;

    return _release(
      room: room,
      eventsListener: eventsListener,
      microphone: microphone,
    );
  }

  Future<void> _release({
    required Room? room,
    required EventsListener<RoomEvent>? eventsListener,
    required LocalAudioTrack? microphone,
  }) {
    return _tearingDown = _tearingDown.then(
      (_) => _releaseNow(
        room: room,
        eventsListener: eventsListener,
        microphone: microphone,
      ),
    );
  }

  Future<void> _releaseNow({
    required Room? room,
    required EventsListener<RoomEvent>? eventsListener,
    required LocalAudioTrack? microphone,
  }) async {
    try {
      // Dispose of event listener first
      await eventsListener?.dispose();
      await microphone?.stop();
    } catch (e) {
      _safeAddError(
        _dataStreamController,
        Exception('Error during disconnect: $e'),
      );
    }

    if (room == null) {
      return;
    }

    // LiveKit's disconnect only returns promptly for a room that connected
    if (room.connectionState == ConnectionState.connected ||
        room.connectionState == ConnectionState.reconnecting) {
      try {
        // Add timeout to prevent hanging
        await room.disconnect().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            _safeAddError(
              _dataStreamController,
              Exception('Disconnect timeout - forcing cleanup'),
            );
          },
        );
      } catch (e) {
        _safeAddError(
          _dataStreamController,
          Exception('Error during disconnect: $e'),
        );
      }
    }

    try {
      await room.dispose();
    } catch (e) {
      _safeAddError(
        _dataStreamController,
        Exception('Error disposing room: $e'),
      );
    }
  }

  /// Disposes of all resources
  Future<void> dispose() async {
    // Tear down the room/listener BEFORE closing the controllers. Disconnecting
    // can emit a final RoomDisconnectedEvent and the disconnect path itself
    // reports errors on _dataStreamController; doing it first (combined with the
    // _safeAdd guards) prevents "Cannot add new events after calling close".
    await disconnect();

    await _dataStreamController.close();
    await _stateStreamController.close();
    await _disconnectStreamController.close();
    await _roomReadyController.close();
    await _speakingStateController.close();
  }
}
