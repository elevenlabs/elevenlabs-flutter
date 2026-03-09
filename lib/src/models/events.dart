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
    // Extract the nested client_tool_call object
    final clientToolCall = json['client_tool_call'] as Map<String, dynamic>;
    return ClientToolCall(
      toolCallId: clientToolCall['tool_call_id'] as String,
      toolName: clientToolCall['tool_name'] as String,
      parameters: clientToolCall['parameters'] as Map<String, dynamic>? ?? {},
      eventId: clientToolCall['event_id'] as int,
    );
  }
}

/// Interruption event
class InterruptionEvent {
  final int eventId;

  InterruptionEvent({required this.eventId});

  factory InterruptionEvent.fromJson(Map<String, dynamic> json) {
    final interruptionEvent =
        json['interruption_event'] as Map<String, dynamic>;
    return InterruptionEvent(eventId: interruptionEvent['event_id'] as int);
  }
}

/// Agent chat response part
class AgentChatResponsePart {
  /// Text content of the response
  final String text;

  /// Type of the text response part: "start", "delta", or "stop"
  final String type;

  AgentChatResponsePart({required this.text, required this.type});

  factory AgentChatResponsePart.fromJson(Map<String, dynamic> json) {
    final textResponsePart = json['text_response_part'] as Map<String, dynamic>;
    return AgentChatResponsePart(
      text: textResponsePart['text'] as String,
      type: textResponsePart['type'] as String,
    );
  }
}

/// Conversation metadata
class ConversationMetadata {
  /// Conversation identifier
  final String conversationId;

  /// Agent output audio format
  final String agentOutputAudioFormat;

  /// User input audio format
  final String userInputAudioFormat;

  ConversationMetadata({
    required this.conversationId,
    required this.agentOutputAudioFormat,
    required this.userInputAudioFormat,
  });

  factory ConversationMetadata.fromJson(Map<String, dynamic> json) {
    final event =
        json['conversation_initiation_metadata_event'] as Map<String, dynamic>;
    return ConversationMetadata(
      conversationId: event['conversation_id'] as String,
      agentOutputAudioFormat: event['agent_output_audio_format'] as String,
      userInputAudioFormat: event['user_input_audio_format'] as String,
    );
  }
}

/// ASR initiation metadata
class AsrInitiationMetadata {
  /// Raw metadata as a map
  final Map<String, dynamic> metadata;

  AsrInitiationMetadata({required this.metadata});

  factory AsrInitiationMetadata.fromJson(Map<String, dynamic> json) {
    return AsrInitiationMetadata(
      metadata: json['asr_initiation_metadata_event'] as Map<String, dynamic>,
    );
  }
}

/// MCP tool call event
class McpToolCall {
  /// Service identifier
  final String serviceId;

  /// Tool call identifier
  final String toolCallId;

  /// Tool name
  final String toolName;

  /// Tool description (optional)
  final String? toolDescription;

  /// Parameters
  final Map<String, dynamic> parameters;

  /// Timestamp
  final String timestamp;

  /// State: "loading", "awaiting_approval", "success", or "failure"
  final String state;

  /// Approval timeout in seconds (for awaiting_approval state)
  final int? approvalTimeoutSecs;

  /// Result (for success state)
  final List<Map<String, dynamic>>? result;

  /// Error message (for failure state)
  final String? errorMessage;

  McpToolCall({
    required this.serviceId,
    required this.toolCallId,
    required this.toolName,
    this.toolDescription,
    required this.parameters,
    required this.timestamp,
    required this.state,
    this.approvalTimeoutSecs,
    this.result,
    this.errorMessage,
  });

  factory McpToolCall.fromJson(Map<String, dynamic> json) {
    final mcpToolCall = json['mcp_tool_call'] as Map<String, dynamic>;
    return McpToolCall(
      serviceId: mcpToolCall['service_id'] as String,
      toolCallId: mcpToolCall['tool_call_id'] as String,
      toolName: mcpToolCall['tool_name'] as String,
      toolDescription: mcpToolCall['tool_description'] as String?,
      parameters: mcpToolCall['parameters'] as Map<String, dynamic>? ?? {},
      timestamp: mcpToolCall['timestamp'] as String,
      state: mcpToolCall['state'] as String,
      approvalTimeoutSecs: mcpToolCall['approval_timeout_secs'] as int?,
      result: (mcpToolCall['result'] as List?)?.cast<Map<String, dynamic>>(),
      errorMessage: mcpToolCall['error_message'] as String?,
    );
  }
}

/// MCP connection status
class McpConnectionStatus {
  /// List of integrations
  final List<McpIntegration> integrations;

  McpConnectionStatus({required this.integrations});

  factory McpConnectionStatus.fromJson(Map<String, dynamic> json) {
    final mcpConnectionStatus =
        json['mcp_connection_status'] as Map<String, dynamic>;
    final integrationsList = mcpConnectionStatus['integrations'] as List;
    return McpConnectionStatus(
      integrations: integrationsList
          .map((e) => McpIntegration.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// MCP integration item
class McpIntegration {
  /// Integration identifier
  final String integrationId;

  /// Integration type: "mcp_server" or "mcp_integration"
  final String integrationType;

  /// Whether the integration is connected
  final bool isConnected;

  /// Number of tools available
  final int toolCount;

  McpIntegration({
    required this.integrationId,
    required this.integrationType,
    required this.isConnected,
    required this.toolCount,
  });

  factory McpIntegration.fromJson(Map<String, dynamic> json) {
    return McpIntegration(
      integrationId: json['integration_id'] as String,
      integrationType: json['integration_type'] as String,
      isConnected: json['is_connected'] as bool,
      toolCount: json['tool_count'] as int,
    );
  }
}

/// Agent tool request event (fired when the agent initiates any tool call)
class AgentToolRequest {
  /// Name of the tool being invoked
  final String toolName;

  /// Tool call identifier
  final String toolCallId;

  /// Tool type (e.g., "client", "webhook", "system")
  final String toolType;

  /// Parameters passed to the tool
  final Map<String, dynamic> parameters;

  AgentToolRequest({
    required this.toolName,
    required this.toolCallId,
    required this.toolType,
    required this.parameters,
  });

  factory AgentToolRequest.fromJson(Map<String, dynamic> json) {
    final agentToolRequest = json['agent_tool_request'] as Map<String, dynamic>;
    return AgentToolRequest(
      toolName: agentToolRequest['tool_name'] as String,
      toolCallId: agentToolRequest['tool_call_id'] as String,
      toolType: agentToolRequest['tool_type'] as String,
      parameters: agentToolRequest['parameters'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Agent tool response
class AgentToolResponse {
  /// Tool name
  final String toolName;

  /// Tool call identifier
  final String toolCallId;

  /// Tool type
  final String toolType;

  /// Whether this is an error response
  final bool isError;

  /// Event identifier
  final int eventId;

  AgentToolResponse({
    required this.toolName,
    required this.toolCallId,
    required this.toolType,
    required this.isError,
    required this.eventId,
  });

  factory AgentToolResponse.fromJson(Map<String, dynamic> json) {
    final agentToolResponse =
        json['agent_tool_response'] as Map<String, dynamic>;
    return AgentToolResponse(
      toolName: agentToolResponse['tool_name'] as String,
      toolCallId: agentToolResponse['tool_call_id'] as String,
      toolType: agentToolResponse['tool_type'] as String,
      isError: agentToolResponse['is_error'] as bool,
      eventId: agentToolResponse['event_id'] as int,
    );
  }
}
