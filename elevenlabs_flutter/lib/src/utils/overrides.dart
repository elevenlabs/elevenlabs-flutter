import '../models/conversation_config.dart';
import '../../version.dart';

/// Constructs the conversation initiation client data event with overrides
/// from the provided [config]. This event is sent to the server when
/// initiating a conversation.
Map<String, dynamic> constructOverrides(ConversationConfig config) {
  final Map<String, dynamic> overridesEvent = {
    'type': 'conversation_initiation_client_data',
  };

  // Build conversation_config_override if overrides exist
  if (config.overrides != null) {
    final conversationConfigOverride = <String, dynamic>{};

    // Agent overrides
    if (config.overrides!.agent != null) {
      conversationConfigOverride['agent'] = {
        if (config.overrides!.agent!.prompt != null)
          'prompt': config.overrides!.agent!.prompt,
        if (config.overrides!.agent!.firstMessage != null)
          'first_message': config.overrides!.agent!.firstMessage,
        if (config.overrides!.agent!.language != null)
          'language': config.overrides!.agent!.language,
      };
    }

    // TTS overrides
    if (config.overrides!.tts != null) {
      conversationConfigOverride['tts'] = {
        if (config.overrides!.tts!.voiceId != null)
          'voice_id': config.overrides!.tts!.voiceId,
      };
    }

    // Conversation overrides
    if (config.overrides!.conversation != null) {
      conversationConfigOverride['conversation'] = {
        if (config.overrides!.conversation!.textOnly != null)
          'text_only': config.overrides!.conversation!.textOnly,
      };
    }

    overridesEvent['conversation_config_override'] = conversationConfigOverride;
  }

  // Add source info
  overridesEvent['source_info'] = {
    'source': 'flutter_sdk',
    'version': config.overrides?.client?.version ?? packageVersion,
  };

  // Add optional fields
  if (config.customLlmExtraBody != null) {
    overridesEvent['custom_llm_extra_body'] = config.customLlmExtraBody;
  }

  if (config.dynamicVariables != null) {
    overridesEvent['dynamic_variables'] = config.dynamicVariables;
  }

  if (config.userId != null) {
    overridesEvent['user_id'] = config.userId;
  }

  return overridesEvent;
}

