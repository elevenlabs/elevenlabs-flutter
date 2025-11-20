import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import '../models/conversation_status.dart';
import '../models/conversation_config.dart';
import '../models/callbacks.dart';
import '../tools/client_tools.dart';
import '../connection/livekit_manager.dart';
import '../connection/token_service.dart';
import '../messaging/message_handler.dart';
import '../messaging/message_sender.dart';
import '../utils/overrides.dart';

/// Main client for managing conversations with ElevenLabs agents
class ConversationClient extends ChangeNotifier {
  // Services
  late final TokenService _tokenService;
  late final LiveKitManager _liveKitManager;
  late final MessageHandler _messageHandler;
  late final MessageSender _messageSender;

  // Configuration
  final String? _apiEndpoint;
  final String? _websocketUrl;
  final ConversationCallbacks? _callbacks;
  final Map<String, ClientTool>? _clientTools;

  // State
  ConversationStatus _status = ConversationStatus.disconnected;
  ConversationMode _mode = ConversationMode.listening;
  bool _isSpeaking = false;
  String? _conversationId;
  int _lastFeedbackEventId = 0;
  bool _overridesSent = false;

  StreamSubscription<livekit.ConnectionState>? _stateSubscription;
  StreamSubscription<bool>? _speakingSubscription;

  /// Current connection status
  ConversationStatus get status => _status;

  /// Whether the agent is currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Current conversation ID
  String? get conversationId => _conversationId;

  /// Whether the microphone is muted
  bool get isMuted => _liveKitManager.isMuted;

  /// Whether feedback can be sent for the last agent response
  bool get canSendFeedback =>
      _messageHandler.currentEventId != _lastFeedbackEventId &&
      _status == ConversationStatus.connected;

  /// Creates a new conversation client
  ConversationClient({
    String? apiEndpoint,
    String? websocketUrl,
    ConversationCallbacks? callbacks,
    Map<String, ClientTool>? clientTools,
  })  : _apiEndpoint = apiEndpoint,
        _websocketUrl = websocketUrl,
        _callbacks = callbacks,
        _clientTools = clientTools {
    _initializeServices();
  }

  void _initializeServices() {
    _tokenService = TokenService(apiEndpoint: _apiEndpoint);
    _liveKitManager = LiveKitManager();
    _messageHandler = MessageHandler(
      callbacks: _enhancedCallbacks,
      liveKit: _liveKitManager,
      clientTools: _clientTools,
    );
    _messageSender = MessageSender(_liveKitManager);
  }

  /// Enhanced callbacks that include internal state management
  ConversationCallbacks get _enhancedCallbacks {
    final callbacks = _callbacks;
    return ConversationCallbacks(
      onDisconnect: callbacks?.onDisconnect,
      onStatusChange: callbacks?.onStatusChange,
      onError: callbacks?.onError,
      onMessage: callbacks?.onMessage,
      onModeChange: callbacks?.onModeChange,
      onAudio: callbacks?.onAudio,
      onVadScore: callbacks?.onVadScore,
      onInterruption: callbacks?.onInterruption,
      onAgentChatResponsePart: callbacks?.onAgentChatResponsePart,
      onConversationMetadata: (metadata) {
        _conversationId = metadata.conversationId;
        notifyListeners();
        callbacks?.onConnect?.call(conversationId: metadata.conversationId);
        callbacks?.onConversationMetadata?.call(metadata);
      },
      onAsrInitiationMetadata: callbacks?.onAsrInitiationMetadata,
      onCanSendFeedbackChange: ({required bool canSendFeedback}) {
        notifyListeners(); // Notify UI that feedback state changed
        callbacks?.onCanSendFeedbackChange?.call(
          canSendFeedback: canSendFeedback,
        );
      },
      onUnhandledClientToolCall: callbacks?.onUnhandledClientToolCall,
      onMcpToolCall: callbacks?.onMcpToolCall,
      onMcpConnectionStatus: callbacks?.onMcpConnectionStatus,
      onAgentToolResponse: callbacks?.onAgentToolResponse,
      onDebug: callbacks?.onDebug,
      onEndCallRequested: () {
        // Agent requested to end the call - trigger session end
        endSession();
        callbacks?.onEndCallRequested?.call();
      },
      onTentativeUserTranscript: callbacks?.onTentativeUserTranscript,
      onUserTranscript: callbacks?.onUserTranscript,
      onAgentResponseCorrection: callbacks?.onAgentResponseCorrection,
      onTentativeAgentResponse: callbacks?.onTentativeAgentResponse,
    );
  }

  /// Starts a new conversation session
  ///
  /// Either [agentId] or [conversationToken] must be provided:
  /// - Use [agentId] for public agents (token will be fetched automatically)
  /// - Use [conversationToken] for private agents (token from your backend)
  Future<void> startSession({
    String? agentId,
    String? conversationToken,
    String? userId,
    ConversationOverrides? overrides,
    Map<String, dynamic>? customLlmExtraBody,
    Map<String, dynamic>? dynamicVariables,
  }) async {
    if (_status != ConversationStatus.disconnected) {
      throw StateError('Session already active');
    }

    if (agentId == null && conversationToken == null) {
      throw ArgumentError(
        'Either agentId or conversationToken must be provided',
      );
    }

    try {
      // Ensure clean state (important for hot-reload and multiple sessions)
      _overridesSent = false;

      _setStatus(ConversationStatus.connecting);

      // Get token and WebSocket URL
      late final String token;
      late final String wsUrl;

      if (conversationToken != null) {
        // Private agent - use provided token
        token = conversationToken;
      } else if (agentId != null) {
        // Public agent - fetch token
        final result = await _tokenService.fetchToken(agentId: agentId);
        token = result.token;
      } else {
        throw ArgumentError(
          'Either agentId or conversationToken must be provided',
        );
      }

      wsUrl = _websocketUrl ?? 'wss://livekit.rtc.elevenlabs.io';

      // Listen to connection state changes (but don't set connected until after initialization)
      _stateSubscription = _liveKitManager.stateStream.listen((state) {
        if (state == livekit.ConnectionState.disconnected) {
          _handleDisconnection('Connection lost');
        }
      });

      // Listen to agent speaking state from LiveKit
      _speakingSubscription = _liveKitManager.speakingStateStream.listen((
        isSpeaking,
      ) {
        _mode =
            isSpeaking ? ConversationMode.speaking : ConversationMode.listening;
        _isSpeaking = isSpeaking;
        notifyListeners();
        _callbacks?.onModeChange?.call(mode: _mode);
      });

      // Start message handling
      _messageHandler.startListening();

      // Start waiting for room ready event BEFORE connecting
      final roomReadyFuture = _liveKitManager.roomReadyStream.first;

      // Connect to LiveKit (will emit roomReady event when done)
      await _liveKitManager.connect(wsUrl, token);

      // Wait for room to be fully ready and send overrides
      await roomReadyFuture;
      await _sendOverrides(
        userId: userId,
        overrides: overrides,
        customLlmExtraBody: customLlmExtraBody,
        dynamicVariables: dynamicVariables,
      );

      _setStatus(ConversationStatus.connected);
    } catch (e) {
      _setStatus(ConversationStatus.disconnected);
      _callbacks?.onError?.call('Failed to start session', e);
      rethrow;
    }
  }

  /// Ends the current conversation session
  Future<void> endSession() async {
    if (_status == ConversationStatus.disconnected ||
        _status == ConversationStatus.disconnecting) {
      return;
    }

    try {
      _setStatus(ConversationStatus.disconnecting);
      await _cleanup();
      _handleDisconnection('Session ended by user');
    } catch (e) {
      _callbacks?.onError?.call('Error ending session', e);
      _setStatus(ConversationStatus.disconnected);
    }
  }

  /// Sends a text message to the agent
  void sendUserMessage(String text) {
    _ensureConnected();
    _messageSender.sendUserMessage(text).catchError((e) {
      _callbacks?.onError?.call('Failed to send message', e);
    });
  }

  /// Sends a contextual update to the agent
  void sendContextualUpdate(String text) {
    _ensureConnected();
    _messageSender.sendContextualUpdate(text).catchError((e) {
      _callbacks?.onError?.call('Failed to send contextual update', e);
    });
  }

  /// Sends a user activity signal
  void sendUserActivity() {
    _ensureConnected();
    _messageSender.sendUserActivity().catchError((e) {
      _callbacks?.onError?.call('Failed to send user activity', e);
    });
  }

  /// Sends feedback for the last agent response
  void sendFeedback({required bool isPositive}) {
    _ensureConnected();

    if (!canSendFeedback) {
      _callbacks?.onError?.call('Cannot send feedback at this time', null);
      return;
    }

    final eventId = _messageHandler.currentEventId;
    _lastFeedbackEventId = eventId;
    notifyListeners();
    _callbacks?.onCanSendFeedbackChange?.call(canSendFeedback: false);

    _messageSender
        .sendFeedback(isPositive: isPositive, eventId: eventId)
        .catchError((e) {
      _callbacks?.onError?.call('Failed to send feedback', e);
    });
  }

  /// Sets the microphone mute state
  Future<void> setMicMuted(bool muted) async {
    try {
      await _liveKitManager.setMicMuted(muted);
      notifyListeners();
    } catch (e) {
      _callbacks?.onError?.call('Failed to set mic mute state', e);
    }
  }

  /// Toggles the microphone mute state
  Future<void> toggleMute() async {
    try {
      await _liveKitManager.toggleMute();
      notifyListeners();
    } catch (e) {
      _callbacks?.onError?.call('Failed to toggle mute', e);
    }
  }

  void _setStatus(ConversationStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      _callbacks?.onStatusChange?.call(status: newStatus);
    }
  }

  void _ensureConnected() {
    if (_status != ConversationStatus.connected) {
      throw StateError('Not connected to agent');
    }
  }

  void _handleDisconnection(String reason) {
    _callbacks?.onDisconnect?.call(DisconnectionDetails(reason: reason));
    _setStatus(ConversationStatus.disconnected);
  }

  /// Sends the conversation initiation overrides message
  Future<void> _sendOverrides({
    String? userId,
    ConversationOverrides? overrides,
    Map<String, dynamic>? customLlmExtraBody,
    Map<String, dynamic>? dynamicVariables,
  }) async {
    // Guard against sending overrides multiple times
    // This can happen during hot-reload when old stream listeners persist
    if (_overridesSent) {
      return;
    }

    _overridesSent = true;

    final config = ConversationConfig(
      userId: userId,
      overrides: overrides,
      customLlmExtraBody: customLlmExtraBody,
      dynamicVariables: dynamicVariables,
    );

    final overridesMessage = constructOverrides(config);

    try {
      await _liveKitManager.sendMessage(overridesMessage);
    } catch (e) {
      _overridesSent = false; // Reset flag on error so retry is possible
      _callbacks?.onError?.call('Failed to send overrides', e);
      rethrow;
    }
  }

  Future<void> _cleanup() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;

    await _speakingSubscription?.cancel();
    _speakingSubscription = null;

    _messageHandler.stopListening();
    await _liveKitManager.disconnect();

    _conversationId = null;
    _lastFeedbackEventId = 0;
    _overridesSent = false; // Reset for next session
  }

  @override
  void dispose() {
    _cleanup();
    _messageHandler.dispose();
    _liveKitManager.dispose().ignore();
    super.dispose();
  }
}
