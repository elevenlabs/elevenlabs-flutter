/// Configuration for starting a conversation
class ConversationConfig {
  /// Public agent ID (for public agents)
  final String? agentId;

  /// Conversation token (for private agents, provided by your backend)
  final String? conversationToken;

  /// User identifier
  final String? userId;

  /// Configuration overrides
  final ConversationOverrides? overrides;

  /// Custom LLM extra body parameters
  final Map<String, dynamic>? customLlmExtraBody;

  /// Dynamic variables for the conversation
  final Map<String, dynamic>? dynamicVariables;

  ConversationConfig({
    this.agentId,
    this.conversationToken,
    this.userId,
    this.overrides,
    this.customLlmExtraBody,
    this.dynamicVariables,
  });

  Map<String, dynamic> toJson() {
    return {
      if (agentId != null) 'agent_id': agentId,
      if (userId != null) 'user_id': userId,
      if (overrides != null) 'overrides': overrides!.toJson(),
      if (customLlmExtraBody != null)
        'custom_llm_extra_body': customLlmExtraBody,
      if (dynamicVariables != null) 'dynamic_variables': dynamicVariables,
    };
  }
}

/// Overrides for conversation configuration
class ConversationOverrides {
  /// Agent configuration overrides
  final AgentOverrides? agent;

  /// Text-to-speech overrides
  final TtsOverrides? tts;

  /// Conversation settings overrides
  final ConversationSettingsOverrides? conversation;

  /// Client configuration overrides
  final ClientOverrides? client;

  ConversationOverrides({
    this.agent,
    this.tts,
    this.conversation,
    this.client,
  });

  Map<String, dynamic> toJson() {
    return {
      if (agent != null) 'agent': agent!.toJson(),
      if (tts != null) 'tts': tts!.toJson(),
      if (conversation != null) 'conversation': conversation!.toJson(),
      if (client != null) 'client': client!.toJson(),
    };
  }
}

/// Agent configuration overrides
class AgentOverrides {
  /// First message override
  final String? firstMessage;

  /// System prompt override
  final String? prompt;

  /// LLM model override
  final String? llm;

  /// Temperature override
  final double? temperature;

  /// Max tokens override
  final int? maxTokens;

  /// Language override
  final String? language;

  AgentOverrides({
    this.firstMessage,
    this.prompt,
    this.llm,
    this.temperature,
    this.maxTokens,
    this.language,
  });

  Map<String, dynamic> toJson() {
    return {
      if (firstMessage != null) 'first_message': firstMessage,
      if (prompt != null) 'prompt': prompt,
      if (llm != null) 'llm': llm,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (language != null) 'language': language,
    };
  }
}

/// Text-to-speech configuration overrides
class TtsOverrides {
  /// Voice ID override
  final String? voiceId;

  /// Model ID override
  final String? modelId;

  /// Stability override (0-1)
  final double? stability;

  /// Similarity boost override (0-1)
  final double? similarityBoost;

  /// Style override (0-1)
  final double? style;

  /// Use speaker boost
  final bool? useSpeakerBoost;

  TtsOverrides({
    this.voiceId,
    this.modelId,
    this.stability,
    this.similarityBoost,
    this.style,
    this.useSpeakerBoost,
  });

  Map<String, dynamic> toJson() {
    return {
      if (voiceId != null) 'voice_id': voiceId,
      if (modelId != null) 'model_id': modelId,
      if (stability != null) 'stability': stability,
      if (similarityBoost != null) 'similarity_boost': similarityBoost,
      if (style != null) 'style': style,
      if (useSpeakerBoost != null) 'use_speaker_boost': useSpeakerBoost,
    };
  }
}

/// Conversation settings overrides
class ConversationSettingsOverrides {
  /// Maximum duration in seconds
  final int? maxDurationSeconds;

  /// Turn timeout in seconds
  final int? turnTimeoutSeconds;

  /// Text-only mode
  final bool? textOnly;

  ConversationSettingsOverrides({
    this.maxDurationSeconds,
    this.turnTimeoutSeconds,
    this.textOnly,
  });

  Map<String, dynamic> toJson() {
    return {
      if (maxDurationSeconds != null)
        'max_duration_seconds': maxDurationSeconds,
      if (turnTimeoutSeconds != null) 'turn_timeout_seconds': turnTimeoutSeconds,
      if (textOnly != null) 'text_only': textOnly,
    };
  }
}

/// Client configuration overrides
class ClientOverrides {
  /// ASR quality
  final String? asrQuality;

  /// Optimize streaming latency (0-4)
  final int? optimizeStreamingLatency;

  /// SDK version
  final String? version;

  ClientOverrides({
    this.asrQuality,
    this.optimizeStreamingLatency,
    this.version,
  });

  Map<String, dynamic> toJson() {
    return {
      if (asrQuality != null) 'asr_quality': asrQuality,
      if (optimizeStreamingLatency != null)
        'optimize_streaming_latency': optimizeStreamingLatency,
      if (version != null) 'version': version,
    };
  }
}

/// Details about a disconnection event
class DisconnectionDetails {
  /// Reason for disconnection
  final String reason;

  /// Optional error code
  final int? code;

  DisconnectionDetails({
    required this.reason,
    this.code,
  });
}

