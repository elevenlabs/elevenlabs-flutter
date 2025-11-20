import 'conversation_status.dart';
import 'conversation_config.dart';
import 'events.dart';

/// Callbacks for conversation events
class ConversationCallbacks {
  /// Called when connected to the agent
  final void Function({required String conversationId})? onConnect;

  /// Called when disconnected from the agent
  final void Function(DisconnectionDetails details)? onDisconnect;

  /// Called when connection status changes
  final void Function({required ConversationStatus status})? onStatusChange;

  /// Called when an error occurs
  final void Function(String message, [dynamic context])? onError;

  /// Called when a message is received (transcription or agent response)
  final void Function({required String message, required Role source})?
      onMessage;

  /// Called when the conversation mode changes (listening/speaking)
  final void Function({required ConversationMode mode})? onModeChange;

  /// Called when audio data is received
  final void Function(String base64Audio)? onAudio;

  /// Called with voice activity detection scores
  final void Function({required double vadScore})? onVadScore;

  /// Called when an interruption occurs
  final void Function(InterruptionEvent event)? onInterruption;

  /// Called when an agent chat response part is received
  final void Function(AgentChatResponsePart part)? onAgentChatResponsePart;

  /// Called when conversation metadata is received
  final void Function(ConversationMetadata metadata)? onConversationMetadata;

  /// Called when ASR initiation metadata is received
  final void Function(AsrInitiationMetadata metadata)? onAsrInitiationMetadata;

  /// Called when feedback can be sent changes
  final void Function({required bool canSendFeedback})? onCanSendFeedbackChange;

  /// Called when a client tool call is not handled
  final void Function(ClientToolCall toolCall)? onUnhandledClientToolCall;

  /// Called when an MCP tool call is received
  final void Function(McpToolCall toolCall)? onMcpToolCall;

  /// Called when MCP connection status changes
  final void Function(McpConnectionStatus status)? onMcpConnectionStatus;

  /// Called when an agent tool response is received
  final void Function(AgentToolResponse response)? onAgentToolResponse;

  /// Called with debug information
  final void Function(dynamic data)? onDebug;

  /// Called when the agent requests to end the call (via end_call tool)
  final void Function()? onEndCallRequested;

  /// Called when a tentative user transcript is received (real-time transcription)
  final void Function({required String transcript, required int eventId})?
      onTentativeUserTranscript;

  /// Called when a user transcript is finalized
  final void Function({required String transcript, required int eventId})?
      onUserTranscript;

  /// Called when an agent response correction is received
  final void Function(Map<String, dynamic> correction)?
      onAgentResponseCorrection;

  /// Called when a tentative agent response is received (streaming text)
  final void Function({required String response})? onTentativeAgentResponse;

  const ConversationCallbacks({
    this.onConnect,
    this.onDisconnect,
    this.onStatusChange,
    this.onError,
    this.onMessage,
    this.onModeChange,
    this.onAudio,
    this.onVadScore,
    this.onInterruption,
    this.onAgentChatResponsePart,
    this.onConversationMetadata,
    this.onAsrInitiationMetadata,
    this.onCanSendFeedbackChange,
    this.onUnhandledClientToolCall,
    this.onMcpToolCall,
    this.onMcpConnectionStatus,
    this.onAgentToolResponse,
    this.onDebug,
    this.onEndCallRequested,
    this.onTentativeUserTranscript,
    this.onUserTranscript,
    this.onAgentResponseCorrection,
    this.onTentativeAgentResponse,
  });
}
