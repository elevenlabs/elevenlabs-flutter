import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:elevenlabs_agents/src/messaging/message_handler.dart';
import 'package:elevenlabs_agents/src/connection/livekit_manager.dart';

/// Minimal mock of LiveKitManager for MessageHandler tests.
/// Only needs dataStream and sendMessage.
class FakeLiveKitManager extends LiveKitManager {
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();
  final sentMessages = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  @override
  Future<void> sendMessage(Map<String, dynamic> message) async {
    sentMessages.add(message);
  }

  /// Simulate an incoming message from the agent
  void simulateIncomingMessage(Map<String, dynamic> json) {
    _dataController.add(json);
  }

  @override
  Future<void> dispose() async {
    _dataController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLiveKitManager fakeLiveKit;

  setUp(() {
    fakeLiveKit = FakeLiveKitManager();
  });

  tearDown(() async {
    await fakeLiveKit.dispose();
  });

  group('Event model parsing', () {
    test('AgentToolRequest.fromJson parses correctly', () {
      final json = {
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'get_weather',
          'tool_call_id': 'call-abc-123',
          'tool_type': 'webhook',
          'event_id': 42,
        },
      };

      final request = AgentToolRequest.fromJson(json);

      expect(request.toolName, 'get_weather');
      expect(request.toolCallId, 'call-abc-123');
      expect(request.toolType, 'webhook');
      expect(request.eventId, 42);
    });

    test('AgentToolResponse.fromJson parses correctly', () {
      final json = {
        'type': 'agent_tool_response',
        'agent_tool_response': {
          'tool_name': 'get_weather',
          'tool_call_id': 'call-abc-123',
          'tool_type': 'webhook',
          'is_error': false,
          'event_id': 43,
        },
      };

      final response = AgentToolResponse.fromJson(json);

      expect(response.toolName, 'get_weather');
      expect(response.toolCallId, 'call-abc-123');
      expect(response.toolType, 'webhook');
      expect(response.isError, false);
      expect(response.eventId, 43);
    });

    test('InterruptionEvent.fromJson parses correctly', () {
      final json = {
        'type': 'interruption',
        'interruption_event': {'event_id': 10},
      };

      final event = InterruptionEvent.fromJson(json);
      expect(event.eventId, 10);
    });

    test('ClientToolCall.fromJson parses correctly', () {
      final json = {
        'type': 'client_tool_call',
        'client_tool_call': {
          'tool_call_id': 'tc-001',
          'tool_name': 'my_tool',
          'parameters': {'key': 'value'},
          'event_id': 5,
        },
      };

      final toolCall = ClientToolCall.fromJson(json);
      expect(toolCall.toolCallId, 'tc-001');
      expect(toolCall.toolName, 'my_tool');
      expect(toolCall.parameters, {'key': 'value'});
      expect(toolCall.eventId, 5);
    });
  });

  group('MessageHandler event dispatch', () {
    test('dispatches agent_tool_request to onAgentToolRequest callback',
        () async {
      AgentToolRequest? receivedRequest;

      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onAgentToolRequest: (request) {
            receivedRequest = request;
          },
        ),
        liveKit: fakeLiveKit,
      );

      handler.startListening();

      fakeLiveKit.simulateIncomingMessage({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'search_recipes',
          'tool_call_id': 'call-xyz',
          'tool_type': 'webhook',
          'event_id': 99,
        },
      });

      // Allow the stream event to propagate
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedRequest, isNotNull);
      expect(receivedRequest!.toolName, 'search_recipes');
      expect(receivedRequest!.toolCallId, 'call-xyz');
      expect(receivedRequest!.toolType, 'webhook');
      expect(receivedRequest!.eventId, 99);

      handler.dispose();
    });

    test('dispatches agent_tool_response to onAgentToolResponse callback',
        () async {
      AgentToolResponse? receivedResponse;

      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onAgentToolResponse: (response) {
            receivedResponse = response;
          },
        ),
        liveKit: fakeLiveKit,
      );

      handler.startListening();

      fakeLiveKit.simulateIncomingMessage({
        'type': 'agent_tool_response',
        'agent_tool_response': {
          'tool_name': 'search_recipes',
          'tool_call_id': 'call-xyz',
          'tool_type': 'webhook',
          'is_error': false,
          'event_id': 100,
        },
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedResponse, isNotNull);
      expect(receivedResponse!.toolName, 'search_recipes');
      expect(receivedResponse!.isError, false);
      expect(receivedResponse!.eventId, 100);

      handler.dispose();
    });

    test('agent_tool_response with end_call triggers onEndCallRequested',
        () async {
      bool endCallRequested = false;

      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onAgentToolResponse: (response) {},
          onEndCallRequested: () {
            endCallRequested = true;
          },
        ),
        liveKit: fakeLiveKit,
      );

      handler.startListening();

      fakeLiveKit.simulateIncomingMessage({
        'type': 'agent_tool_response',
        'agent_tool_response': {
          'tool_name': 'end_call',
          'tool_call_id': 'call-end',
          'tool_type': 'system',
          'is_error': false,
          'event_id': 101,
        },
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(endCallRequested, true);

      handler.dispose();
    });

    test('dispatches ping with pong response', () async {
      final handler = MessageHandler(
        callbacks: const ConversationCallbacks(),
        liveKit: fakeLiveKit,
      );

      handler.startListening();

      fakeLiveKit.simulateIncomingMessage({
        'type': 'ping',
        'ping_event': {'event_id': 7},
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(fakeLiveKit.sentMessages, hasLength(1));
      expect(fakeLiveKit.sentMessages.first['type'], 'pong');
      expect(fakeLiveKit.sentMessages.first['event_id'], 7);

      handler.dispose();
    });

    test('calls onDebug for known event types', () async {
      final debugCalls = <dynamic>[];

      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onDebug: (data) {
            debugCalls.add(data);
          },
        ),
        liveKit: fakeLiveKit,
      );

      handler.startListening();

      fakeLiveKit.simulateIncomingMessage({
        'type': 'agent_tool_request',
        'agent_tool_request': {
          'tool_name': 'test',
          'tool_call_id': 'tc-1',
          'tool_type': 'webhook',
          'event_id': 1,
        },
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(debugCalls, hasLength(1));

      handler.dispose();
    });

    test('logs unknown event types to onDebug', () async {
      final debugCalls = <dynamic>[];

      final handler = MessageHandler(
        callbacks: ConversationCallbacks(
          onDebug: (data) {
            debugCalls.add(data);
          },
        ),
        liveKit: fakeLiveKit,
      );

      handler.startListening();

      fakeLiveKit.simulateIncomingMessage({
        'type': 'some_future_event',
        'data': 'whatever',
      });

      await Future.delayed(const Duration(milliseconds: 10));

      expect(debugCalls, hasLength(1));
      expect(debugCalls.first.toString(), contains('Unknown event type'));

      handler.dispose();
    });
  });
}
