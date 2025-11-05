/// Connection status of the conversation
enum ConversationStatus {
  /// Not connected to the agent
  disconnected,

  /// Attempting to connect
  connecting,

  /// Connected and ready for conversation
  connected,

  /// In the process of disconnecting
  disconnecting,
}

/// Mode of the conversation
enum ConversationMode {
  /// Agent is listening to the user
  listening,

  /// Agent is speaking
  speaking,
}

/// Role in the conversation
enum Role {
  /// User/customer role
  user,

  /// AI agent role
  ai,
}

