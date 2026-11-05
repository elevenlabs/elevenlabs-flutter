import 'package:elevenlabs_agents/src/connection/livekit_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requests microphone publishing during LiveKit connection', () {
    final options = LiveKitManager.fastConnectOptions;

    expect(options.microphone.enabled, isTrue);
    expect(options.microphone.track, isNull);
  });
}
