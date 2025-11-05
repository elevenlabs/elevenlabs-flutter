import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/conversation_config.dart';

/// Service for fetching conversation tokens from the ElevenLabs API
class TokenService {
  /// API endpoint for token requests
  final String apiEndpoint;

  TokenService({
    String? apiEndpoint,
  }) : apiEndpoint = apiEndpoint ?? 'https://api.elevenlabs.io';

  /// Fetches a LiveKit token for public agents
  ///
  /// Returns both the token and the WebSocket URL for the LiveKit connection
  Future<({String token})> fetchToken({
    required String agentId,
  }) async {
    final uri = Uri.parse('$apiEndpoint/v1/convai/conversation/token?agent_id=$agentId');


    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Token fetched successfully for agent: $agentId');
        return (
          token: data['token'] as String,
        );
      }

      final errorMessage =
          'Failed to fetch token: ${response.statusCode} - ${response.body}';
      debugPrint('❌ TokenService Error: $errorMessage');
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('❌ TokenService Exception: $e');
      rethrow;
    }
  }
}

