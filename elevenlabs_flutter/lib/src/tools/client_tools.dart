/// Interface for client-side tool implementations
abstract class ClientTool {
  /// Executes the tool with the given parameters
  ///
  /// Returns null for fire-and-forget tools (expects_response=false on server)
  /// Returns a ClientToolResult for tools that require a response
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters);
}

/// Result of a client tool execution
class ClientToolResult {
  /// Whether the tool execution was successful
  final bool success;

  /// Data returned by the tool
  final dynamic data;

  /// Error message if execution failed
  final String? error;

  ClientToolResult._({
    required this.success,
    this.data,
    this.error,
  });

  /// Creates a successful result
  factory ClientToolResult.success(dynamic data) => ClientToolResult._(
        success: true,
        data: data,
      );

  /// Creates a failure result
  factory ClientToolResult.failure(String error) => ClientToolResult._(
        success: false,
        error: error,
      );

  /// Converts to JSON for sending to the agent
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
    };
  }
}

