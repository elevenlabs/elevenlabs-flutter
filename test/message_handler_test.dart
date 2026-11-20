import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:elevenlabs_agents/src/connection/livekit_manager.dart';
import 'package:elevenlabs_agents/src/messaging/message_handler.dart';

/// Minimal fake LiveKitManager that feeds test messages into the handler
/// without requiring a real LiveKit Room.
class _FakeLiveKitManager extends LiveKitManager {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final List<Map<String, dynamic>> sentMessages = [];

  @override
  Stream<Map<String, dynamic>> get dataStream => _controller.stream;

  @override
  Future<void> sendMessage(Map<String, dynamic> message) async {
    sentMessages.add(message);
  }

  void inject(Map<String, dynamic> message) => _controller.add(message);

  void close() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageHandler - agent_tool_request (webhook)', () {
    test('fires onAgentToolRequest for webhook tool type', () async {
      String? receivedToolName;
      String? receivedToolCallId;

      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onAgentToolRequest: ({required toolName, required toolCallId}) {
            receivedToolName = toolName;
            receivedToolCallId = toolCallId;
          },
        ),
        liveKit: fakeManager,
      );

      handler.startListening();

      fakeManager.inject({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'fetch_weather',
          'tool_call_id': 'call-abc',
          'tool_type': 'webhook',
        },
      });

      await Future.delayed(Duration.zero);

      expect(receivedToolName, 'fetch_weather');
      expect(receivedToolCallId, 'call-abc');

      handler.dispose();
      fakeManager.close();
    });

    test('does not send a client_tool_result for webhook tool type', () async {
      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: const ConversationCallbacks(),
        liveKit: fakeManager,
      );

      handler.startListening();

      fakeManager.inject({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'backend_lookup',
          'tool_call_id': 'call-xyz',
          'tool_type': 'webhook',
        },
      });

      await Future.delayed(Duration.zero);

      expect(fakeManager.sentMessages, isEmpty);

      handler.dispose();
      fakeManager.close();
    });
  });

  group('MessageHandler - agent_tool_request (client tool)', () {
    test('executes registered client tool and sends result', () async {
      final fakeManager = _FakeLiveKitManager();
      final tool = _EchoTool();

      final handler = MessageHandler(
        callbacks: const ConversationCallbacks(),
        liveKit: fakeManager,
        clientTools: {'echo': tool},
      );

      handler.startListening();

      fakeManager.inject({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'echo',
          'tool_call_id': 'call-echo-1',
          'tool_type': 'client',
          'parameters': {'message': 'hello'},
        },
      });

      await Future.delayed(Duration.zero);

      expect(fakeManager.sentMessages, hasLength(1));
      final sent = fakeManager.sentMessages.first;
      expect(sent['type'], 'client_tool_result');
      expect(sent['tool_call_id'], 'call-echo-1');
      expect(sent['is_error'], false);
      expect(sent['result'], isA<String>());
      expect(
        jsonDecode(sent['result'] as String),
        {'echo': 'hello'},
      );

      handler.dispose();
      fakeManager.close();
    });

    test('fires onAgentToolRequest callback even for client tool type',
        () async {
      String? receivedToolName;

      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onAgentToolRequest: ({required toolName, required toolCallId}) {
            receivedToolName = toolName;
          },
        ),
        liveKit: fakeManager,
        clientTools: {'echo': _EchoTool()},
      );

      handler.startListening();

      fakeManager.inject({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'echo',
          'tool_call_id': 'call-echo-2',
          'tool_type': 'client',
        },
      });

      await Future.delayed(Duration.zero);

      expect(receivedToolName, 'echo');

      handler.dispose();
      fakeManager.close();
    });

    test('fires onUnhandledClientToolCall when no tool is registered',
        () async {
      ClientToolCall? unhandled;

      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onUnhandledClientToolCall: (toolCall) {
            unhandled = toolCall;
          },
        ),
        liveKit: fakeManager,
      );

      handler.startListening();

      fakeManager.inject({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'missing_tool',
          'tool_call_id': 'call-miss-1',
          'tool_type': 'client',
          'parameters': {'key': 'value'},
        },
      });

      await Future.delayed(Duration.zero);

      expect(unhandled, isNotNull);
      expect(unhandled!.toolName, 'missing_tool');
      expect(unhandled!.toolCallId, 'call-miss-1');
      expect(unhandled!.parameters, {'key': 'value'});
      expect(fakeManager.sentMessages, [
        {
          'type': 'client_tool_result',
          'tool_call_id': 'call-miss-1',
          'result': "Tool 'missing_tool' is not registered",
          'is_error': true,
        },
      ]);

      handler.dispose();
      fakeManager.close();
    });

    test('does not send result when client tool returns null', () async {
      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: const ConversationCallbacks(),
        liveKit: fakeManager,
        clientTools: {'fire_forget': _FireForgetTool()},
      );

      handler.startListening();

      fakeManager.inject({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'fire_forget',
          'tool_call_id': 'call-ff-1',
          'tool_type': 'client',
        },
      });

      await Future.delayed(Duration.zero);

      expect(fakeManager.sentMessages, isEmpty);

      handler.dispose();
      fakeManager.close();
    });
  });

  group('MessageHandler - client_tool_call (no tool registered)', () {
    Map<String, dynamic> clientToolCall(String toolCallId) => {
          'type': 'client_tool_call',
          'client_tool_call': {
            'tool_name': 'missing_tool',
            'tool_call_id': toolCallId,
            'parameters': {'key': 'value'},
            'event_id': 7,
          },
        };

    Map<String, dynamic> errorResult(String toolCallId) => {
          'type': 'client_tool_result',
          'tool_call_id': toolCallId,
          'result': "Tool 'missing_tool' is not registered",
          'is_error': true,
        };

    test('sends an error result', () async {
      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: const ConversationCallbacks(),
        liveKit: fakeManager,
        clientTools: {'echo': _EchoTool()},
      );

      handler.startListening();
      fakeManager.inject(clientToolCall('call-miss-2'));
      await Future.delayed(Duration.zero);

      expect(fakeManager.sentMessages, [errorResult('call-miss-2')]);

      handler.dispose();
      fakeManager.close();
    });

    test('sends an error result and fires onUnhandledClientToolCall', () async {
      ClientToolCall? unhandled;

      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onUnhandledClientToolCall: (toolCall) => unhandled = toolCall,
        ),
        liveKit: fakeManager,
      );

      handler.startListening();
      fakeManager.inject(clientToolCall('call-miss-3'));
      await Future.delayed(Duration.zero);

      expect(unhandled?.toolCallId, 'call-miss-3');
      expect(fakeManager.sentMessages, [errorResult('call-miss-3')]);

      handler.dispose();
      fakeManager.close();
    });

    test('sends one error result when agent_tool_request announces the call',
        () async {
      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: const ConversationCallbacks(),
        liveKit: fakeManager,
      );

      handler.startListening();
      fakeManager.inject({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'missing_tool',
          'tool_call_id': 'call-miss-4',
          'tool_type': 'client',
        },
      });
      fakeManager.inject(clientToolCall('call-miss-4'));
      await Future.delayed(Duration.zero);

      expect(fakeManager.sentMessages, [errorResult('call-miss-4')]);

      handler.dispose();
      fakeManager.close();
    });
  });

  group('MessageHandler - agent_tool_request (debug)', () {
    test('calls onDebug with the raw JSON', () async {
      dynamic debugData;

      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onDebug: (data) => debugData = data,
        ),
        liveKit: fakeManager,
      );

      handler.startListening();

      final message = {
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'some_tool',
          'tool_call_id': 'call-dbg',
          'tool_type': 'webhook',
        },
      };

      fakeManager.inject(message);

      await Future.delayed(Duration.zero);

      expect(debugData, equals(message));

      handler.dispose();
      fakeManager.close();
    });
  });

  group('MessageHandler - onIncomingEvent', () {
    // The server-to-client messages of /v1/convai/conversation in
    // https://api.elevenlabs.io/convai-asyncapi.yml
    const publishedEventTypes = [
      'conversation_initiation_metadata',
      'agent_response_complete',
      'context_usage',
      'mcp_tool_call',
      'client_error',
      'guardrail_triggered',
      'user_transcript',
      'agent_response',
      'queue_status',
      'agent_response_correction',
      'agent_response_metadata',
      'audio',
      'interruption',
      'vad_score',
      'agent_chat_response_part',
      'client_tool_call',
      'agent_tool_response',
      'agent_tool_response_full_payload',
      'agent_tool_request',
      'ping',
      'mcp_connection_status',
    ];

    test('receives every published event type', () async {
      final received = <Map<String, dynamic>>[];
      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: ConversationCallbacks(onIncomingEvent: received.add),
        liveKit: fakeManager,
      );

      handler.startListening();

      final messages = [
        for (final type in publishedEventTypes) {'type': type},
      ];
      messages.forEach(fakeManager.inject);

      await Future.delayed(Duration.zero);

      expect(received, equals(messages));

      handler.dispose();
      fakeManager.close();
    });

    test('still handles an event when the callback throws', () async {
      String? errorMessage;
      final fakeManager = _FakeLiveKitManager();
      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onIncomingEvent: (_) => throw StateError('app bug'),
          onError: (message, [context]) => errorMessage = message,
        ),
        liveKit: fakeManager,
      );

      handler.startListening();

      fakeManager.inject({
        'type': 'ping',
        'ping_event': {'event_id': 7},
      });

      await Future.delayed(Duration.zero);

      expect(fakeManager.sentMessages, [
        {'type': 'pong', 'event_id': 7},
      ]);
      expect(errorMessage, 'onIncomingEvent callback failed');

      handler.dispose();
      fakeManager.close();
    });
  });
}

// ---------------------------------------------------------------------------
// Test tool implementations
// ---------------------------------------------------------------------------

class _EchoTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    return ClientToolResult.success({'echo': parameters['message']});
  }
}

class _FireForgetTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    return null;
  }
}
