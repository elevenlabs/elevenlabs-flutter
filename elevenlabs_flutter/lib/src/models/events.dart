/// Event types from the ElevenLabs Agent Platform protocol
library;

/// Client tool call event
class ClientToolCall {
  /// Unique identifier for this tool call
  final String toolCallId;

  /// Name of the tool being invoked
  final String toolName;

  /// Parameters passed to the tool
  final Map<String, dynamic> parameters;

  /// Event ID
  final int eventId;

  ClientToolCall({
    required this.toolCallId,
    required this.toolName,
    required this.parameters,
    required this.eventId,
  });

  factory ClientToolCall.fromJson(Map<String, dynamic> json) {
    return ClientToolCall(
      toolCallId: json['tool_call_id'] as String,
      toolName: json['tool_name'] as String,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      eventId: json['event_id'] as int,
    );
  }
}

/// Interruption event
class InterruptionEvent {
  /// Event identifier
  final int eventId;

  InterruptionEvent({
    required this.eventId,
  });

  factory InterruptionEvent.fromJson(Map<String, dynamic> json) {
    return InterruptionEvent(
      eventId: json['event_id'] as int,
    );
  }
}

/// Agent chat response part
class AgentChatResponsePart {
  /// Text content of the response
  final String text;

  /// Event ID
  final int eventId;

  AgentChatResponsePart({
    required this.text,
    required this.eventId,
  });

  factory AgentChatResponsePart.fromJson(Map<String, dynamic> json) {
    return AgentChatResponsePart(
      text: json['text'] as String,
      eventId: json['event_id'] as int,
    );
  }
}

/// Conversation metadata
class ConversationMetadata {
  /// Conversation identifier
  final String? conversationId;

  /// Additional metadata
  final Map<String, dynamic>? metadata;

  ConversationMetadata({
    this.conversationId,
    this.metadata,
  });

  factory ConversationMetadata.fromJson(Map<String, dynamic> json) {
    return ConversationMetadata(
      conversationId: json['conversation_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// ASR initiation metadata
class AsrInitiationMetadata {
  /// Timestamp
  final int? timestamp;

  AsrInitiationMetadata({
    this.timestamp,
  });

  factory AsrInitiationMetadata.fromJson(Map<String, dynamic> json) {
    return AsrInitiationMetadata(
      timestamp: json['timestamp'] as int?,
    );
  }
}

/// MCP tool call event
class McpToolCall {
  /// Tool call identifier
  final String toolCallId;

  /// Tool name
  final String toolName;

  /// Parameters
  final Map<String, dynamic> parameters;

  McpToolCall({
    required this.toolCallId,
    required this.toolName,
    required this.parameters,
  });

  factory McpToolCall.fromJson(Map<String, dynamic> json) {
    return McpToolCall(
      toolCallId: json['tool_call_id'] as String,
      toolName: json['tool_name'] as String,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// MCP connection status
class McpConnectionStatus {
  /// Connection status
  final String status;

  McpConnectionStatus({
    required this.status,
  });

  factory McpConnectionStatus.fromJson(Map<String, dynamic> json) {
    return McpConnectionStatus(
      status: json['status'] as String,
    );
  }
}

/// Agent tool response
class AgentToolResponse {
  /// Tool call identifier
  final String toolCallId;

  /// Response data
  final dynamic response;

  AgentToolResponse({
    required this.toolCallId,
    required this.response,
  });

  factory AgentToolResponse.fromJson(Map<String, dynamic> json) {
    return AgentToolResponse(
      toolCallId: json['tool_call_id'] as String,
      response: json['response'],
    );
  }
}

