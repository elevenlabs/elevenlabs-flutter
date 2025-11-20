import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for fetching conversation tokens from the ElevenLabs API
class TokenService {
  /// API endpoint for token requests
  final String apiEndpoint;

  TokenService({String? apiEndpoint})
      : apiEndpoint = apiEndpoint ?? 'https://api.elevenlabs.io';

  /// Fetches a LiveKit token for public agents
  Future<({String token})> fetchToken({required String agentId}) async {
    final uri = Uri.parse(
      '$apiEndpoint/v1/convai/conversation/token?agent_id=$agentId',
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (token: data['token'] as String);
      }

      throw Exception(
        'Failed to fetch token (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      rethrow;
    }
  }
}
