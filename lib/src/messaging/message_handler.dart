import 'dart:async';
import '../models/callbacks.dart';
import '../models/conversation_status.dart';
import '../models/events.dart';
import '../connection/livekit_manager.dart';
import '../tools/client_tools.dart';

/// Handles incoming messages from the LiveKit data channel
class MessageHandler {
  final ConversationCallbacks callbacks;
  final LiveKitManager liveKit;
  final Map<String, ClientTool>? clientTools;

  StreamSubscription<Map<String, dynamic>>? _dataSubscription;

  int _currentEventId = 0;

  /// Current event ID for feedback tracking
  int get currentEventId => _currentEventId;

  MessageHandler({
    required this.callbacks,
    required this.liveKit,
    this.clientTools,
  });

  /// Starts listening to data messages
  void startListening() {
    _dataSubscription = liveKit.dataStream.listen(
      _processIncomingMessage,
      onError: (error) {
        callbacks.onError?.call('Data stream error', error);
      },
    );
  }

  /// Stops listening to data messages
  void stopListening() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
  }

  /// Processes an incoming message from the agent
  void _processIncomingMessage(Map<String, dynamic> json) {
    try {
      final eventType = json['type'] as String?;
      if (eventType == null) return;

      switch (eventType) {
        case 'conversation_initiation_metadata':
          callbacks.onDebug?.call(json);
          _handleConversationMetadata(json);
          break;

        case 'user_transcription':
          callbacks.onDebug?.call(json);
          _handleUserTranscription(json);
          break;

        case 'agent_response':
          callbacks.onDebug?.call(json);
          _handleAgentResponse(json);
          break;

        case 'agent_response_part':
          callbacks.onDebug?.call(json);
          _handleAgentResponsePart(json);
          break;

        case 'audio':
          callbacks.onDebug?.call(json);
          _handleAudio(json);
          break;

        case 'interruption':
          callbacks.onDebug?.call(json);
          _handleInterruption(json);
          break;

        case 'ping':
          _handlePing(json);
          break;

        case 'client_tool_call':
          callbacks.onDebug?.call(json);
          _handleClientToolCall(json);
          break;

        case 'mcp_tool_call':
          callbacks.onDebug?.call(json);
          _handleMcpToolCall(json);
          break;

        case 'mcp_connection_status':
          callbacks.onDebug?.call(json);
          _handleMcpConnectionStatus(json);
          break;

        case 'agent_tool_response':
          callbacks.onDebug?.call(json);
          _handleAgentToolResponse(json);
          break;

        case "agent_chat_response_part":
          callbacks.onDebug?.call(json);
          _handleAgentChatResponsePart(json);
          break;

        case "internal_tentative_agent_response":
          callbacks.onDebug?.call(json);
          _handleTentativeAgentResponse(json);
          break;

        case "vad_score":
          _handleVadScore(json);
          break;

        case "tentative_user_transcript":
          callbacks.onDebug?.call(json);
          _handleTentativeUserTranscript(json);
          break;

        case "user_transcript":
          callbacks.onDebug?.call(json);
          _handleUserTranscript(json);
          break;

        case "agent_response_correction":
          callbacks.onDebug?.call(json);
          _handleAgentResponseCorrection(json);
          break;

        case "asr_initiation_metadata":
          callbacks.onDebug?.call(json);
          _handleAsrInitiationMetadata(json);
          break;

        default:
          callbacks.onDebug?.call('Unknown event type: $eventType - $json');
      }
    } catch (e) {
      callbacks.onError?.call('Failed to process message', e);
    }
  }

  void _handleConversationMetadata(Map<String, dynamic> json) {
    final metadata = ConversationMetadata.fromJson(json);
    callbacks.onConversationMetadata?.call(metadata);
  }

  void _handleUserTranscription(Map<String, dynamic> json) {
    final transcription = json['user_transcription'] as Map<String, dynamic>?;
    if (transcription != null) {
      final transcript = transcription['transcript'] as String?;
      if (transcript != null && transcript.isNotEmpty) {
        callbacks.onMessage?.call(message: transcript, source: Role.user);
      }
    }
  }

  void _handleAgentResponse(Map<String, dynamic> json) {
    final response = json['agent_response_event'] as Map<String, dynamic>?;
    if (response != null) {
      // Update event ID for feedback tracking
      final eventId = response['event_id'] as int?;
      if (eventId != null) {
        _updateEventId(eventId);
      }

      final text = response['agent_response'] as String?;
      if (text != null && text.isNotEmpty) {
        callbacks.onMessage?.call(message: text, source: Role.ai);
      }
    }
  }

  void _handleAgentResponsePart(Map<String, dynamic> json) {
    try {
      final part = AgentChatResponsePart.fromJson(json);
      callbacks.onAgentChatResponsePart?.call(part);
    } catch (e) {
      callbacks.onError?.call('Failed to parse agent response part', e);
    }
  }

  void _handleAudio(Map<String, dynamic> json) {
    final audio = json['audio'] as Map<String, dynamic>?;
    if (audio != null) {
      final chunk = audio['chunk'] as String?;
      if (chunk != null) {
        callbacks.onAudio?.call(chunk);
      }
    }
  }

  void _handleInterruption(Map<String, dynamic> json) {
    final event = InterruptionEvent.fromJson(json);
    callbacks.onInterruption?.call(event);
  }

  void _handlePing(Map<String, dynamic> json) {
    // Respond to ping with pong
    final pingEvent = json['ping_event'] as Map<String, dynamic>?;
    final eventId = pingEvent?['event_id'];

    if (eventId != null) {
      liveKit.sendMessage({'type': 'pong', 'event_id': eventId});
    }
  }

  Future<void> _handleClientToolCall(Map<String, dynamic> json) async {
    try {
      final toolCall = ClientToolCall.fromJson(json);
      final tool = clientTools?[toolCall.toolName];

      if (tool != null) {
        // Execute the tool
        final result = await tool.execute(toolCall.parameters);

        // Send response if tool expects one
        if (result != null) {
          await _sendClientToolResponse(toolCall.toolCallId, result);
        }
      } else {
        // No handler registered for this tool
        callbacks.onUnhandledClientToolCall?.call(toolCall);
      }
    } catch (e) {
      callbacks.onError?.call('Client tool execution failed', e);
    }
  }

  Future<void> _sendClientToolResponse(
    String toolCallId,
    ClientToolResult result,
  ) async {
    await liveKit.sendMessage({
      'type': 'client_tool_result',
      'tool_call_id': toolCallId,
      'result': result.toJson(),
    });
  }

  void _handleMcpToolCall(Map<String, dynamic> json) {
    final toolCall = McpToolCall.fromJson(json);
    callbacks.onMcpToolCall?.call(toolCall);
  }

  void _handleMcpConnectionStatus(Map<String, dynamic> json) {
    final status = McpConnectionStatus.fromJson(json);
    callbacks.onMcpConnectionStatus?.call(status);
  }

  void _handleAgentToolResponse(Map<String, dynamic> json) {
    final response = AgentToolResponse.fromJson(json);
    callbacks.onAgentToolResponse?.call(response);

    // If agent calls end_call tool, trigger session end
    if (response.toolName == 'end_call') {
      callbacks.onEndCallRequested?.call();
    }
  }

  void _handleAgentChatResponsePart(Map<String, dynamic> json) {
    try {
      final part = AgentChatResponsePart.fromJson(json);
      callbacks.onAgentChatResponsePart?.call(part);
    } catch (e) {
      callbacks.onError?.call('Failed to parse agent chat response part', e);
    }
  }

  void _handleTentativeAgentResponse(Map<String, dynamic> json) {
    final event = json['tentative_agent_response_internal_event']
        as Map<String, dynamic>?;
    final response = event?['tentative_agent_response'] as String?;
    if (response != null) {
      callbacks.onTentativeAgentResponse?.call(response: response);
    }
  }

  void _handleVadScore(Map<String, dynamic> json) {
    final event = json['vad_score_event'] as Map<String, dynamic>?;
    final score = event?['vad_score'] as num?;
    if (score != null) {
      callbacks.onVadScore?.call(vadScore: score.toDouble());
    }
  }

  void _handleTentativeUserTranscript(Map<String, dynamic> json) {
    final event =
        json['tentative_user_transcription_event'] as Map<String, dynamic>?;
    final transcript = event?['user_transcript'] as String?;
    final eventId = event?['event_id'] as int?;
    if (transcript != null && eventId != null) {
      callbacks.onTentativeUserTranscript?.call(
        transcript: transcript,
        eventId: eventId,
      );
    }
  }

  void _handleUserTranscript(Map<String, dynamic> json) {
    final event = json['user_transcription_event'] as Map<String, dynamic>?;
    final transcript = event?['user_transcript'] as String?;
    final eventId = event?['event_id'] as int?;
    if (transcript != null && eventId != null) {
      callbacks.onUserTranscript?.call(
        transcript: transcript,
        eventId: eventId,
      );
    }
  }

  void _handleAgentResponseCorrection(Map<String, dynamic> json) {
    final event =
        json['agent_response_correction_event'] as Map<String, dynamic>?;
    if (event != null) {
      // Update event ID for feedback tracking
      final eventId = event['event_id'] as int?;
      if (eventId != null) {
        _updateEventId(eventId);
      }
    }
    callbacks.onAgentResponseCorrection?.call(json);
  }

  void _updateEventId(int newEventId) {
    final previousEventId = _currentEventId;
    _currentEventId = newEventId;

    // Notify when event ID changes (feedback becomes available)
    if (_currentEventId != previousEventId) {
      callbacks.onCanSendFeedbackChange?.call(canSendFeedback: true);
    }
  }

  void _handleAsrInitiationMetadata(Map<String, dynamic> json) {
    final metadata = AsrInitiationMetadata.fromJson(json);
    callbacks.onAsrInitiationMetadata?.call(metadata);
  }

  /// Disposes of resources
  void dispose() {
    stopListening();
  }
}
