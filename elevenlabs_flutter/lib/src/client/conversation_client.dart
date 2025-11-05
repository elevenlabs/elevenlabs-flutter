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

  StreamSubscription<livekit.ConnectionState>? _stateSubscription;

  /// Current connection status
  ConversationStatus get status => _status;

  /// Whether the agent is currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Current conversation mode (listening/speaking)
  ConversationMode get mode => _mode;

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
  }  )  : _apiEndpoint = apiEndpoint,
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
      onConnect: ({required String conversationId}) {
        _conversationId = conversationId;
        callbacks?.onConnect?.call(conversationId: conversationId);
      },
      onDisconnect: callbacks?.onDisconnect,
      onStatusChange: callbacks?.onStatusChange,
      onError: callbacks?.onError,
      onMessage: callbacks?.onMessage,
      onModeChange: ({required ConversationMode mode}) {
        _mode = mode;
        _isSpeaking = mode == ConversationMode.speaking;
        notifyListeners();
        callbacks?.onModeChange?.call(mode: mode);
      },
      onAudio: callbacks?.onAudio,
      onVadScore: callbacks?.onVadScore,
      onInterruption: callbacks?.onInterruption,
      onAgentChatResponsePart: callbacks?.onAgentChatResponsePart,
      onConversationMetadata: (metadata) {
        if (metadata.conversationId != null) {
          _conversationId = metadata.conversationId;
          notifyListeners();
          callbacks?.onConnect?.call(conversationId: metadata.conversationId!);
        }
        callbacks?.onConversationMetadata?.call(metadata);
      },
      onAsrInitiationMetadata: callbacks?.onAsrInitiationMetadata,
      onCanSendFeedbackChange: callbacks?.onCanSendFeedbackChange,
      onUnhandledClientToolCall: callbacks?.onUnhandledClientToolCall,
      onMcpToolCall: callbacks?.onMcpToolCall,
      onMcpConnectionStatus: callbacks?.onMcpConnectionStatus,
      onAgentToolResponse: callbacks?.onAgentToolResponse,
      onDebug: callbacks?.onDebug,
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
      throw ArgumentError('Either agentId or conversationToken must be provided');
    }

    try {
      _setStatus(ConversationStatus.connecting);

      // Get token and WebSocket URL
      late final String token;
      late final String wsUrl;

      if (conversationToken != null) {
        // Private agent - use provided token
        token = conversationToken;
      } else if (agentId != null) {
        // Public agent - fetch token
        final result = await _tokenService.fetchToken(
          agentId: agentId,
        );
        token = result.token;
      } else {
        throw ArgumentError('Either agentId or conversationToken must be provided');
      }

      wsUrl = _websocketUrl ?? 'wss://livekit.rtc.elevenlabs.io';

      // Connect to LiveKit
      await _liveKitManager.connect(wsUrl, token);

      // Set up data listener
      _liveKitManager.setupDataListener();

      // Start message handling
      _messageHandler.startListening();

      // Listen to connection state changes
      _stateSubscription = _liveKitManager.stateStream.listen((state) {
        if (state == livekit.ConnectionState.connected) {
          _setStatus(ConversationStatus.connected);
        } else if (state == livekit.ConnectionState.disconnected) {
          _handleDisconnection('Connection lost');
        }
      });

      _setStatus(ConversationStatus.connected);
    } catch (e) {
      _setStatus(ConversationStatus.disconnected);
      _callbacks?.onError?.call('Failed to start session', e);
      rethrow;
    }
  }

  /// Ends the current conversation session
  Future<void> endSession() async {
    if (_status == ConversationStatus.disconnected) {
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

    _messageSender.sendFeedback(
      isPositive: isPositive,
      eventId: eventId,
    ).catchError((e) {
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

  /// Gets the current conversation ID
  String? getId() => _conversationId;

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
    _callbacks?.onDisconnect?.call(
      DisconnectionDetails(reason: reason),
    );
    _setStatus(ConversationStatus.disconnected);
  }

  Future<void> _cleanup() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;

    _messageHandler.stopListening();
    await _liveKitManager.disconnect();

    _conversationId = null;
    _lastFeedbackEventId = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanup();
    _messageHandler.dispose();
    _liveKitManager.dispose();
    super.dispose();
  }
}

