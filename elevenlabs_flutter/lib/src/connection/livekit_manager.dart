import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Manages LiveKit Room connection and audio tracks
class LiveKitManager {
  Room? _room;
  LocalAudioTrack? _localAudioTrack;

  /// Stream controller for incoming data messages
  final _dataStreamController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming data messages
  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  /// Stream controller for connection state changes
  final _stateStreamController = StreamController<ConnectionState>.broadcast();

  /// Stream of connection state changes
  Stream<ConnectionState> get stateStream => _stateStreamController.stream;

  /// Current room instance
  Room? get room => _room;

  /// Whether the microphone is muted
  bool get isMuted => _localAudioTrack?.muted ?? false;

  /// Connects to a LiveKit server
  Future<void> connect(String serverUrl, String token) async {
    try {
      debugPrint('🔌 Connecting to LiveKit: $serverUrl');

      // Clean up any existing connection
      await disconnect();

      // Create room
      _room = Room();

      // Set up event listeners
      _room!.addListener(_onRoomEvent);

      // Listen for data messages
      _room!.addListener(() {
        for (final participant in _room!.remoteParticipants.values) {
          // Set up data listener for each participant
          participant.addListener(() {
            // This will be triggered when data is received
          });
        }
      });

      // Connect to LiveKit server
      await _room!.connect(serverUrl, token);
      debugPrint('✅ Connected to LiveKit successfully');

      // Create and publish local audio track
      _localAudioTrack = await LocalAudioTrack.create(
        AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );

      await _room!.localParticipant?.setMicrophoneEnabled(true);

      await _room!.localParticipant?.publishAudioTrack(_localAudioTrack!);
      debugPrint('🎤 Local audio track published');


    } catch (e) {
      debugPrint('❌ LiveKit Connection Error: $e');
      rethrow;
    }
  }

  /// Handles room events
  void _onRoomEvent() {
    final currentRoom = _room;
    if (currentRoom == null) return;

    // Emit connection state changes
    _stateStreamController.add(currentRoom.connectionState);

    // Handle remote tracks (agent audio) - LiveKit handles playback automatically
    // Data messages are handled via EventsListener in setupDataListener
  }

  /// Sets up data message listener
  void setupDataListener() {
    final currentRoom = _room;
    if (currentRoom == null) return;

    // Listen for data messages from the room
    currentRoom.addListener(() {
      _handleDataEvents();
    });

    // Set up initial listeners for existing participants
    _handleDataEvents();
  }

  void _handleDataEvents() {
    final currentRoom = _room;
    if (currentRoom == null) return;

    // Note: Data events will come through LiveKit's event system
    // The actual implementation would use LiveKit's onDataReceived stream
    // This is a simplified placeholder - LiveKit handles data channel events
  }

  /// Sends a data message to the room
  Future<void> sendMessage(Map<String, dynamic> message) async {
    final currentRoom = _room;
    if (currentRoom == null) {
      debugPrint('❌ Cannot send message: Not connected to room');
      throw StateError('Not connected to room');
    }

    try {
      final encoded = jsonEncode(message);
      final bytes = utf8.encode(encoded);

      await currentRoom.localParticipant?.publishData(
        bytes,
        reliable: true,
      );
      debugPrint('📤 Message sent: ${message['type']}');
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      rethrow;
    }
  }

  /// Sets the microphone mute state
  Future<void> setMicMuted(bool muted) async {
    await _localAudioTrack?.mute();
    if (!muted) {
      await _localAudioTrack?.unmute();
    }
  }

  /// Toggles the microphone mute state
  Future<void> toggleMute() async {
    final track = _localAudioTrack;
    if (track != null) {
      if (track.muted) {
        await track.unmute();
      } else {
        await track.mute();
      }
    }
  }

  /// Disconnects from the LiveKit server and cleans up resources
  Future<void> disconnect() async {
    final currentRoom = _room;
    if (currentRoom != null) {
      await currentRoom.disconnect();
      await currentRoom.dispose();
      _room = null;
    }

    _localAudioTrack = null;
  }

  /// Disposes of all resources
  void dispose() {
    _dataStreamController.close();
    _stateStreamController.close();
    disconnect();
  }
}

