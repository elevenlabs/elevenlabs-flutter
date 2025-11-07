import 'dart:async';
import 'package:flutter/foundation.dart';
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
        debugPrint('Error in data stream: $error');
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

      // Update event ID if present
      if (json['event_id'] != null) {
        _currentEventId = json['event_id'] as int;
      }

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
          _handleMcpToolCall(json);
          break;

        case 'mcp_connection_status':
          _handleMcpConnectionStatus(json);
          break;

        case 'agent_tool_response':
          callbacks.onDebug?.call(json);
          _handleAgentToolResponse(json);
          break;

        case "agent_chat_response_part":
        case "internal_tentative_agent_response":
        case "vad_score":
        case "tentative_user_transcript":
        case "user_transcript":
        case "agent_response_correction":
          callbacks.onDebug?.call(json);
          break;

        default:
          debugPrint('Unknown event type: $eventType');
          callbacks.onDebug?.call(json);
      }
    } catch (e, stackTrace) {
      debugPrint('Error processing message: $e\n$stackTrace');
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
        callbacks.onMessage?.call(
          message: transcript,
          source: Role.user,
        );
      }
    }
  }

  void _handleAgentResponse(Map<String, dynamic> json) {
    final response = json['agent_response'] as Map<String, dynamic>?;
    if (response != null) {
      final text = response['response'] as String?;
      if (text != null && text.isNotEmpty) {
        callbacks.onMessage?.call(
          message: text,
          source: Role.ai,
        );
      }
    }
  }

  void _handleAgentResponsePart(Map<String, dynamic> json) {
    try {
      final part = AgentChatResponsePart.fromJson(json);
      callbacks.onAgentChatResponsePart?.call(part);
    } catch (e) {
      debugPrint('Error parsing agent response part: $e');
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
      liveKit.sendMessage({
        'type': 'pong',
        'event_id': eventId,
      }).catchError((e) {
        debugPrint('❌ Failed to send pong: $e');
      });
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
      debugPrint('Error handling client tool call: $e');
      callbacks.onError?.call('Client tool execution failed', e);
    }
  }

  Future<void> _sendClientToolResponse(
    String toolCallId,
    ClientToolResult result,
  ) async {
    try {
      await liveKit.sendMessage({
        'type': 'client_tool_result',
        'tool_call_id': toolCallId,
        'result': result.toJson(),
      });
    } catch (e) {
      debugPrint('Error sending client tool response: $e');
    }
  }

  void _handleMcpToolCall(Map<String, dynamic> json) {
    try {
      final toolCall = McpToolCall.fromJson(json);
      callbacks.onMcpToolCall?.call(toolCall);
    } catch (e) {
      debugPrint('Error parsing MCP tool call: $e');
    }
  }

  void _handleMcpConnectionStatus(Map<String, dynamic> json) {
    try {
      final status = McpConnectionStatus.fromJson(json);
      callbacks.onMcpConnectionStatus?.call(status);
    } catch (e) {
      debugPrint('Error parsing MCP connection status: $e');
    }
  }

  void _handleAgentToolResponse(Map<String, dynamic> json) {
    try {
      final response = AgentToolResponse.fromJson(json);
      callbacks.onAgentToolResponse?.call(response);

      // If agent calls end_call tool, trigger session end
      if (json['tool_name'] == 'end_call') {
        debugPrint('🔚 Agent requested end_call, ending session');
        callbacks.onEndCallRequested?.call();
      }
    } catch (e) {
      debugPrint('Error parsing agent tool response: $e');
    }
  }

  /// Disposes of resources
  void dispose() {
    stopListening();
  }
}

