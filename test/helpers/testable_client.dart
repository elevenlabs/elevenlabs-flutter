import 'dart:async';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:flutter/foundation.dart';

/// A testable version of ConversationClient that allows dependency injection
class TestableConversationClient extends ChangeNotifier {
  final ConversationCallbacks? callbacks;
  final Map<String, ClientTool>? clientTools;
  final MockLiveKitManager liveKitManager;
  final MockTokenService tokenService;

  ConversationStatus _status = ConversationStatus.disconnected;
  bool _isSpeaking = false;
  String? _conversationId;
  bool _canSendFeedback = false;

  ConversationStatus get status => _status;
  bool get isSpeaking => _isSpeaking;
  bool get isMuted => liveKitManager.isMuted;
  String? get conversationId => _conversationId;
  bool get canSendFeedback => _canSendFeedback;

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _speakingSubscription;

  TestableConversationClient({
    this.callbacks,
    this.clientTools,
    MockLiveKitManager? liveKitManager,
    MockTokenService? tokenService,
  })  : liveKitManager = liveKitManager ?? MockLiveKitManager(),
        tokenService = tokenService ?? MockTokenService();

  Future<void> startSession({
    String? agentId,
    String? conversationToken,
    String? userId,
    ConversationOverrides? overrides,
    Map<String, dynamic>? customLlmExtraBody,
    Map<String, dynamic>? dynamicVariables,
  }) async {
    if (agentId == null && conversationToken == null) {
      throw ArgumentError(
        'Either agentId or conversationToken must be provided',
      );
    }

    if (_status != ConversationStatus.disconnected) {
      throw StateError('Session already active');
    }

    _setStatus(ConversationStatus.connecting);

    try {
      // Get token if needed
      String token;
      if (conversationToken != null) {
        token = conversationToken;
      } else {
        token = await tokenService.fetchToken(agentId!);
      }

      // Create a completer to wait for connection
      final connectedCompleter = Completer<void>();

      // Listen to connection state
      _connectionSubscription = liveKitManager.connectionStateStream.listen((
        state,
      ) {
        if (state == MockConnectionState.connected) {
          _conversationId = liveKitManager.mockConversationId;
          _setStatus(ConversationStatus.connected);
          callbacks?.onConnect?.call(conversationId: _conversationId!);
          if (!connectedCompleter.isCompleted) {
            connectedCompleter.complete();
          }
        } else if (state == MockConnectionState.disconnected) {
          _setStatus(ConversationStatus.disconnected);
        }
      });

      // Listen to speaking state
      _speakingSubscription = liveKitManager.speakingStateStream.listen((
        speaking,
      ) {
        _isSpeaking = speaking;
        notifyListeners();
        callbacks?.onModeChange?.call(
          mode:
              speaking ? ConversationMode.speaking : ConversationMode.listening,
        );
      });

      // Connect (this will emit the connected state)
      await liveKitManager.connect(token);

      // Wait for the connection state listener to process the connected event
      await connectedCompleter.future;
    } catch (e) {
      _setStatus(ConversationStatus.disconnected);
      callbacks?.onError?.call('Failed to start session', e);
      rethrow;
    }
  }

  Future<void> endSession() async {
    if (_status == ConversationStatus.disconnected ||
        _status == ConversationStatus.disconnecting) {
      return;
    }

    _setStatus(ConversationStatus.disconnecting);

    await _connectionSubscription?.cancel();
    await _speakingSubscription?.cancel();

    await liveKitManager.disconnect();

    callbacks?.onDisconnect?.call(
      DisconnectionDetails(reason: 'Session ended by user'),
    );

    _conversationId = null;
    _canSendFeedback = false;
    _setStatus(ConversationStatus.disconnected);
  }

  void sendUserMessage(String text) {
    _ensureConnected();
    liveKitManager.sendMessage({'type': 'user_message', 'text': text});
    callbacks?.onMessage?.call(message: text, source: Role.user);
  }

  void sendContextualUpdate(String text) {
    _ensureConnected();
    liveKitManager.sendMessage({'type': 'contextual_update', 'text': text});
  }

  void sendUserActivity() {
    _ensureConnected();
    liveKitManager.sendMessage({'type': 'user_activity'});
  }

  void sendFeedback({required bool isPositive}) {
    _ensureConnected();
    liveKitManager.sendMessage({
      'type': 'feedback',
      'score': isPositive ? 'like' : 'dislike',
    });
  }

  Future<void> setMicMuted(bool muted) async {
    await liveKitManager.setMicMuted(muted);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    await liveKitManager.toggleMute();
    notifyListeners();
  }

  void simulateAgentMessage(String message) {
    callbacks?.onMessage?.call(message: message, source: Role.ai);
  }

  void simulateAgentSpeaking() {
    liveKitManager.simulateSpeaking(true);
  }

  void simulateAgentStoppedSpeaking() {
    liveKitManager.simulateSpeaking(false);
  }

  void simulateFeedbackAvailable() {
    _canSendFeedback = true;
    notifyListeners();
    callbacks?.onCanSendFeedbackChange?.call(canSendFeedback: true);
  }

  void _setStatus(ConversationStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      callbacks?.onStatusChange?.call(status: newStatus);
    }
  }

  void _ensureConnected() {
    if (_status != ConversationStatus.connected) {
      throw StateError('Not connected to agent');
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _speakingSubscription?.cancel();
    liveKitManager.dispose();
    super.dispose();
  }
}

/// Mock connection states
enum MockConnectionState { disconnected, connecting, connected }

/// Mock LiveKit manager for testing
class MockLiveKitManager {
  final _connectionStateController =
      StreamController<MockConnectionState>.broadcast();
  final _speakingStateController = StreamController<bool>.broadcast();
  final _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<MockConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<bool> get speakingStateStream => _speakingStateController.stream;
  Stream<Map<String, dynamic>> get messagesStream => _messagesController.stream;

  bool _isMuted = true;
  bool _isConnected = false;
  String mockConversationId = 'test-conversation-123';

  bool get isMuted => _isMuted;
  bool get isConnected => _isConnected;

  Future<void> connect(String token) async {
    _connectionStateController.add(MockConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 10));
    _isConnected = true;
    _isMuted = false;
    _connectionStateController.add(MockConnectionState.connected);
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _isMuted = true;
    _connectionStateController.add(MockConnectionState.disconnected);
  }

  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected) {
      throw StateError('Not connected');
    }
    _messagesController.add(message);
  }

  Future<void> setMicMuted(bool muted) async {
    _isMuted = muted;
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
  }

  void simulateSpeaking(bool speaking) {
    _speakingStateController.add(speaking);
  }

  void dispose() {
    _connectionStateController.close();
    _speakingStateController.close();
    _messagesController.close();
  }
}

/// Mock token service for testing
class MockTokenService {
  String mockToken = 'mock-token-12345';
  bool shouldFail = false;

  Future<String> fetchToken(String agentId) async {
    await Future.delayed(const Duration(milliseconds: 5));

    if (shouldFail) {
      throw Exception('Failed to fetch token');
    }

    return mockToken;
  }
}
