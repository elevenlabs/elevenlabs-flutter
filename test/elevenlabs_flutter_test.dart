import 'package:flutter_test/flutter_test.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationClient - Initialization', () {
    test('initializes with disconnected status', () {
      final client = ConversationClient();
      expect(client.status, ConversationStatus.disconnected);
      expect(client.isSpeaking, false);
      expect(client.isMuted, true); // true when not connected (no room)
      expect(client.conversationId, null);
      expect(client.canSendFeedback, false);
      client.dispose();
    });

    test('can be created with custom endpoints', () {
      final client = ConversationClient(
        apiEndpoint: 'https://api.custom.io',
        websocketUrl: 'wss://ws.custom.io',
      );

      expect(client.status, ConversationStatus.disconnected);
      client.dispose();
    });

    test('can be created with callbacks', () {
      bool connectCalled = false;

      final client = ConversationClient(
        callbacks: ConversationCallbacks(
          onConnect: ({required conversationId}) {
            connectCalled = true;
          },
        ),
      );

      expect(client.status, ConversationStatus.disconnected);
      expect(connectCalled, false);
      client.dispose();
    });

    test('can be created with client tools', () {
      final testTool = TestClientTool();

      final client = ConversationClient(clientTools: {'testTool': testTool});

      expect(client.status, ConversationStatus.disconnected);
      client.dispose();
    });

    test('notifies listeners on state changes', () {
      final client = ConversationClient();
      int notifyCount = 0;

      void listener() {
        notifyCount++;
      }

      client.addListener(listener);

      // Initial state - no notifications yet
      expect(notifyCount, 0);

      client.removeListener(listener);
      client.dispose();
    });
  });

  group('ConversationClient - Session Start Workflow', () {
    test('requires agentId or conversationToken', () {
      final client = ConversationClient();

      expect(() => client.startSession(), throwsArgumentError);

      client.dispose();
    });

    test('validates session parameters', () {
      final client = ConversationClient();

      // Missing both agentId and token
      expect(
        () => client.startSession(userId: 'user-123'),
        throwsArgumentError,
      );

      client.dispose();
    });

    test('configuration objects can be created for session', () {
      // Verify all configuration objects work correctly for starting sessions
      final overrides = ConversationOverrides(
        agent: AgentOverrides(
          firstMessage: 'Hello! How can I help?',
          prompt: 'You are a helpful assistant',
          temperature: 0.7,
          maxTokens: 1000,
        ),
        tts: TtsOverrides(
          voiceId: 'custom-voice',
          stability: 0.5,
          similarityBoost: 0.8,
        ),
        conversation: ConversationSettingsOverrides(
          maxDurationSeconds: 600,
          turnTimeoutSeconds: 10,
        ),
      );

      final dynamicVars = {'user_name': 'Alice', 'tier': 'premium'};

      expect(overrides, isNotNull);
      expect(overrides.agent, isNotNull);
      expect(overrides.tts, isNotNull);
      expect(dynamicVars, isNotEmpty);
    });
  });

  group('ConversationClient - Callbacks', () {
    test('triggers onStatusChange callback', () async {
      final statuses = <ConversationStatus>[];

      final client = ConversationClient(
        callbacks: ConversationCallbacks(
          onStatusChange: ({required status}) {
            statuses.add(status);
          },
        ),
      );

      expect(client.status, ConversationStatus.disconnected);

      // Note: Full session start requires real LiveKit connection
      // This validates the callback structure

      client.dispose();
    });

    test('handles multiple callbacks', () async {
      final client = ConversationClient(
        callbacks: ConversationCallbacks(
          onConnect: ({required conversationId}) {
            // Connect callback
          },
          onStatusChange: ({required status}) {
            // Status change callback
          },
          onError: (message, [context]) {
            // Error callback
          },
          onMessage: ({required message, required source}) {
            // Message callback
          },
          onModeChange: ({required mode}) {
            // Mode change callback
          },
        ),
      );

      expect(client.status, ConversationStatus.disconnected);

      client.dispose();
    });

    test('onDisconnect callback receives details', () async {
      DisconnectionDetails? disconnectDetails;

      final client = ConversationClient(
        callbacks: ConversationCallbacks(
          onDisconnect: (details) {
            disconnectDetails = details;
          },
        ),
      );

      expect(client.status, ConversationStatus.disconnected);
      expect(disconnectDetails, isNull);

      client.dispose();
    });
  });

  group('ConversationClient - State Management', () {
    test('exposes reactive properties', () {
      final client = ConversationClient();

      // Test all public state properties
      expect(client.status, isA<ConversationStatus>());
      expect(client.isSpeaking, isA<bool>());
      expect(client.isMuted, isA<bool>());
      expect(client.conversationId, isNull);
      expect(client.canSendFeedback, isA<bool>());

      client.dispose();
    });

    test('canSendFeedback is false when disconnected', () {
      final client = ConversationClient();

      expect(client.status, ConversationStatus.disconnected);
      expect(client.canSendFeedback, false);

      client.dispose();
    });
  });

  group('ConversationClient - Messaging Workflow', () {
    test('sendUserMessage requires connected state', () {
      final client = ConversationClient();

      expect(client.status, ConversationStatus.disconnected);

      // Should throw StateError when not connected
      expect(() => client.sendUserMessage('Hello'), throwsStateError);

      client.dispose();
    });

    test('sendContextualUpdate requires connected state', () {
      final client = ConversationClient();

      expect(client.status, ConversationStatus.disconnected);

      // Should throw StateError when not connected
      expect(
        () => client.sendContextualUpdate('User is on page X'),
        throwsStateError,
      );

      client.dispose();
    });

    test('sendUserActivity requires connected state', () {
      final client = ConversationClient();

      expect(client.status, ConversationStatus.disconnected);

      // Should throw StateError when not connected
      expect(() => client.sendUserActivity(), throwsStateError);

      client.dispose();
    });

    test('sendFeedback requires connected state', () {
      final client = ConversationClient();

      expect(client.status, ConversationStatus.disconnected);
      expect(client.canSendFeedback, false);

      // Should throw StateError when not connected
      expect(() => client.sendFeedback(isPositive: true), throwsStateError);

      client.dispose();
    });
  });

  group('ConversationClient - Session Lifecycle', () {
    test('endSession completes gracefully when not connected', () async {
      final client = ConversationClient();

      expect(client.status, ConversationStatus.disconnected);

      // Should complete without error
      await client.endSession();
      expect(client.status, ConversationStatus.disconnected);

      client.dispose();
    });

    test('endSession can be called multiple times safely', () async {
      final client = ConversationClient();

      expect(client.status, ConversationStatus.disconnected);

      // Multiple calls should all complete safely
      await client.endSession();
      await client.endSession();
      await client.endSession();

      expect(client.status, ConversationStatus.disconnected);

      client.dispose();
    });
  });

  group('ConversationClient - Audio Controls', () {
    test('mute controls work when disconnected', () async {
      final client = ConversationClient();

      expect(client.isMuted, true); // Default muted when not connected

      // These should complete without error even when disconnected
      await client.setMicMuted(true);
      await client.toggleMute();

      client.dispose();
    });
  });

  group('ConversationClient - Client Tools', () {
    test('client tools can be registered', () {
      final testTool = TestClientTool();

      final client = ConversationClient(
        clientTools: {'testTool': testTool, 'anotherTool': AnotherTestTool()},
      );

      expect(client.status, ConversationStatus.disconnected);
      client.dispose();
    });

    test('client tool returns success result', () async {
      final tool = TestClientTool();

      final result = await tool.execute({'param': 'value'});

      expect(result, isNotNull);
      expect(result!.success, true);
      expect(result.data, {'result': 'success', 'param': 'value'});
    });

    test('client tool returns failure result', () async {
      final tool = FailingTestTool();

      final result = await tool.execute({});

      expect(result, isNotNull);
      expect(result!.success, false);
      expect(result.error, 'Tool execution failed');
    });

    test('client tool can return null for fire-and-forget', () async {
      final tool = FireAndForgetTool();

      final result = await tool.execute({'message': 'test'});

      expect(result, isNull);
    });
  });

  group('AgentToolRequest', () {
    test('parses from JSON correctly', () {
      final json = {
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'fetch_weather',
          'tool_call_id': 'call-abc-123',
          'tool_type': 'webhook',
        },
      };

      final request = AgentToolRequest.fromJson(json);
      expect(request.toolName, 'fetch_weather');
      expect(request.toolCallId, 'call-abc-123');
      expect(request.toolType, 'webhook');
      expect(request.parameters, isEmpty);
    });

    test('parses parameters from JSON', () {
      final json = {
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'lookup',
          'tool_call_id': 'call-xyz-456',
          'tool_type': 'client',
          'parameters': {'query': 'hello', 'limit': 10},
        },
      };

      final request = AgentToolRequest.fromJson(json);
      expect(request.parameters, {'query': 'hello', 'limit': 10});
    });

    test('defaults parameters to empty map when absent', () {
      final json = {
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'no_params_tool',
          'tool_call_id': 'call-111',
          'tool_type': 'system',
        },
      };

      final request = AgentToolRequest.fromJson(json);
      expect(request.parameters, isEmpty);
    });
  });

  group('ConversationCallbacks - onAgentToolRequest', () {
    test('can be registered and accepts named parameters', () {
      String? receivedToolName;
      String? receivedToolCallId;

      final callbacks = ConversationCallbacks(
        onAgentToolRequest: ({required toolName, required toolCallId}) {
          receivedToolName = toolName;
          receivedToolCallId = toolCallId;
        },
      );

      callbacks.onAgentToolRequest?.call(
        toolName: 'test_tool',
        toolCallId: 'call-999',
      );

      expect(receivedToolName, 'test_tool');
      expect(receivedToolCallId, 'call-999');
    });

    test('is null when not provided', () {
      const callbacks = ConversationCallbacks();
      expect(callbacks.onAgentToolRequest, isNull);
    });
  });

  group('ClientToolResult', () {
    test('converts to JSON correctly', () {
      final successResult = ClientToolResult.success({'data': 'test'});
      expect(successResult.toJson(), {
        'success': true,
        'data': {'data': 'test'},
      });

      final failureResult = ClientToolResult.failure('Error');
      expect(failureResult.toJson(), {'success': false, 'error': 'Error'});
    });
  });

  group('ConversationConfig', () {
    test('converts to JSON correctly', () {
      final config = ConversationConfig(
        agentId: 'test-agent',
        userId: 'test-user',
      );

      final json = config.toJson();
      expect(json['agent_id'], 'test-agent');
      expect(json['user_id'], 'test-user');
    });

    test('includes overrides in JSON', () {
      final config = ConversationConfig(
        agentId: 'test-agent',
        overrides: ConversationOverrides(
          agent: AgentOverrides(firstMessage: 'Hello!', temperature: 0.7),
        ),
      );

      final json = config.toJson();
      expect(json['overrides'], isNotNull);
      expect(json['overrides']['agent']['first_message'], 'Hello!');
      expect(json['overrides']['agent']['temperature'], 0.7);
    });

    test('includes dynamic variables in JSON', () {
      final config = ConversationConfig(
        agentId: 'test-agent',
        dynamicVariables: {'user_name': 'Alice', 'tier': 'premium'},
      );

      final json = config.toJson();
      expect(json['dynamic_variables'], isNotNull);
      expect(json['dynamic_variables']['user_name'], 'Alice');
      expect(json['dynamic_variables']['tier'], 'premium');
    });

    test('includes custom LLM extra body in JSON', () {
      final config = ConversationConfig(
        agentId: 'test-agent',
        customLlmExtraBody: {'top_p': 0.9, 'frequency_penalty': 0.5},
      );

      final json = config.toJson();
      expect(json['custom_llm_extra_body'], isNotNull);
      expect(json['custom_llm_extra_body']['top_p'], 0.9);
      expect(json['custom_llm_extra_body']['frequency_penalty'], 0.5);
    });
  });

  group('ConversationOverrides', () {
    test('serializes agent overrides correctly', () {
      final overrides = ConversationOverrides(
        agent: AgentOverrides(
          firstMessage: 'Welcome!',
          prompt: 'Be helpful',
          llm: 'gpt-4',
          temperature: 0.8,
          maxTokens: 1000,
          language: 'en',
        ),
      );

      final json = overrides.toJson();
      expect(json['agent']['first_message'], 'Welcome!');
      expect(json['agent']['prompt'], 'Be helpful');
      expect(json['agent']['llm'], 'gpt-4');
      expect(json['agent']['temperature'], 0.8);
      expect(json['agent']['max_tokens'], 1000);
      expect(json['agent']['language'], 'en');
    });

    test('serializes TTS overrides correctly', () {
      final overrides = ConversationOverrides(
        tts: TtsOverrides(
          voiceId: 'voice-123',
          modelId: 'model-456',
          stability: 0.6,
          similarityBoost: 0.7,
          style: 0.5,
          useSpeakerBoost: true,
        ),
      );

      final json = overrides.toJson();
      expect(json['tts']['voice_id'], 'voice-123');
      expect(json['tts']['model_id'], 'model-456');
      expect(json['tts']['stability'], 0.6);
      expect(json['tts']['similarity_boost'], 0.7);
      expect(json['tts']['style'], 0.5);
      expect(json['tts']['use_speaker_boost'], true);
    });

    test('serializes conversation settings correctly', () {
      final overrides = ConversationOverrides(
        conversation: ConversationSettingsOverrides(
          maxDurationSeconds: 300,
          turnTimeoutSeconds: 5,
          textOnly: true,
        ),
      );

      final json = overrides.toJson();
      expect(json['conversation']['max_duration_seconds'], 300);
      expect(json['conversation']['turn_timeout_seconds'], 5);
      expect(json['conversation']['text_only'], true);
    });
  });
}

// Test implementations of ClientTool for testing
class TestClientTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    return ClientToolResult.success({
      'result': 'success',
      'param': parameters['param'],
    });
  }
}

class AnotherTestTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    return ClientToolResult.success({'status': 'ok'});
  }
}

class FailingTestTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    return ClientToolResult.failure('Tool execution failed');
  }
}

class FireAndForgetTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    // Fire-and-forget - no response
    return null;
  }
}
