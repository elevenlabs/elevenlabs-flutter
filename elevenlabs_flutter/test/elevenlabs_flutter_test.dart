import 'package:flutter_test/flutter_test.dart';
import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';

void main() {
  group('ConversationClient', () {
    test('initializes with disconnected status', () {
      final client = ConversationClient();
      expect(client.status, ConversationStatus.disconnected);
      expect(client.isSpeaking, false);
      expect(client.isMuted, false);
      expect(client.conversationId, null);
      expect(client.canSendFeedback, false);
      client.dispose();
    });

    test('requires agentId or conversationToken', () async {
      final client = ConversationClient();

      expect(
        () => client.startSession(),
        throwsArgumentError,
      );

      client.dispose();
    });
  });

  group('ConversationStatus', () {
    test('has all expected values', () {
      expect(ConversationStatus.values, [
        ConversationStatus.disconnected,
        ConversationStatus.connecting,
        ConversationStatus.connected,
        ConversationStatus.disconnecting,
      ]);
    });
  });

  group('ConversationMode', () {
    test('has listening and speaking modes', () {
      expect(ConversationMode.values, [
        ConversationMode.listening,
        ConversationMode.speaking,
      ]);
    });
  });

  group('Role', () {
    test('has user and ai roles', () {
      expect(Role.values, [
        Role.user,
        Role.ai,
      ]);
    });
  });

  group('ClientToolResult', () {
    test('creates success result', () {
      final result = ClientToolResult.success({'key': 'value'});
      expect(result.success, true);
      expect(result.data, {'key': 'value'});
      expect(result.error, null);
    });

    test('creates failure result', () {
      final result = ClientToolResult.failure('Error message');
      expect(result.success, false);
      expect(result.error, 'Error message');
    });

    test('converts to JSON correctly', () {
      final successResult = ClientToolResult.success({'data': 'test'});
      expect(successResult.toJson(), {
        'success': true,
        'data': {'data': 'test'},
      });

      final failureResult = ClientToolResult.failure('Error');
      expect(failureResult.toJson(), {
        'success': false,
        'error': 'Error',
      });
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
          agent: AgentOverrides(
            firstMessage: 'Hello!',
            temperature: 0.7,
          ),
        ),
      );

      final json = config.toJson();
      expect(json['overrides'], isNotNull);
      expect(json['overrides']['agent']['first_message'], 'Hello!');
      expect(json['overrides']['agent']['temperature'], 0.7);
    });
  });

  group('DisconnectionDetails', () {
    test('stores reason and code', () {
      final details = DisconnectionDetails(
        reason: 'Connection lost',
        code: 1000,
      );

      expect(details.reason, 'Connection lost');
      expect(details.code, 1000);
    });
  });
}

