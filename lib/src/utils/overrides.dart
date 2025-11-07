import '../models/conversation_config.dart';
import '../../version.dart';

Map<String, dynamic> constructOverrides(ConversationConfig config) {
  final overrides = config.overrides;

  final conversationConfigOverride = <String, dynamic>{
    'agent': {
      'first_message': overrides?.agent?.firstMessage,
      'language': overrides?.agent?.language,
      'prompt': overrides?.agent?.prompt,
    },
    'conversation': {
      'text_only': overrides?.conversation?.textOnly,
    },
    'tts': {
      'voice_id': overrides?.tts?.voiceId,
    },
  };

  final overridesEvent = <String, dynamic>{
    'conversation_config_override': conversationConfigOverride,
    'dynamic_variables': config.dynamicVariables ?? {},
    'source_info': {
      'source': 'react_native_sdk',
      'version': overrides?.client?.version ?? packageVersion,
    },
    'type': 'conversation_initiation_client_data',
  };

  // Add optional fields
  if (config.userId != null) {
    overridesEvent['user_id'] = config.userId;
  }

  if (config.customLlmExtraBody != null) {
    overridesEvent['custom_llm_extra_body'] = config.customLlmExtraBody;
  }

  return overridesEvent;
}

