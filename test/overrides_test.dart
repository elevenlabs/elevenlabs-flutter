import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:elevenlabs_agents/src/utils/overrides.dart';

void main() {
  group('constructOverrides source_info', () {
    test('identifies the SDK as flutter_sdk at the package version', () {
      final event = constructOverrides(ConversationConfig(agentId: 'agent'));

      expect(event['source_info'], {
        'source': 'flutter_sdk',
        'version': packageVersion,
      });
    });

    test('is unaffected by the options the application passes', () {
      final event = constructOverrides(
        ConversationConfig(
          agentId: 'agent',
          userId: 'user-123',
          overrides: ConversationOverrides(
            agent: AgentOverrides(firstMessage: 'Hi'),
            tts: TtsOverrides(voiceId: 'voice'),
            conversation: ConversationSettingsOverrides(textOnly: true),
            client: ClientOverrides(
              asrQuality: 'high',
              optimizeStreamingLatency: 2,
            ),
          ),
          customLlmExtraBody: {'source_info': 'ignored'},
          dynamicVariables: {'source': 'app', 'version': '9.9.9'},
        ),
      );

      expect(event['source_info'], {
        'source': 'flutter_sdk',
        'version': packageVersion,
      });
    });
  });

  test('packageVersion matches the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);

    expect(packageVersion, version);
  });
}
