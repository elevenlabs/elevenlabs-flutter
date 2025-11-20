import 'package:flutter/material.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

/// Simple client tool that logs a message to the console
class LogMessageTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    final message = parameters['message'] as String?;

    if (message == null || message.isEmpty) {
      return ClientToolResult.failure('Missing or empty message parameter');
    }

    // Log the message to console
    debugPrint('📢 Agent Tool Call - Log Message: $message');

    // Fire-and-forget tool - no response needed
    return null;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElevenLabs Flutter Example',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const ConversationScreen(),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late ConversationClient _client;
  final _agentIdController = TextEditingController(
    text: dotenv.env['AGENT_ID'] ?? '',
  );
  final _messageController = TextEditingController();

  void Function()? _clientListener;

  @override
  void initState() {
    super.initState();
    _requestMicrophonePermission();
    _initializeClient();
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeClient() {
    _client = ConversationClient(
      clientTools: {'logMessage': LogMessageTool()},
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) {
          debugPrint('✅ Connected: $conversationId');
          _showSnackBar('Connected: $conversationId', Colors.green);
        },
        onDisconnect: (details) {
          debugPrint('❌ Disconnected: ${details.reason}');
        },
        onMessage: ({required message, required source}) {
          debugPrint('💬 ${source.name}: $message');
        },
        onModeChange: ({required mode}) {
          debugPrint('🔊 Mode: ${mode.name}');
        },
        onStatusChange: ({required status}) {
          debugPrint('📡 Status: ${status.name}');
        },
        onError: (message, [context]) {
          debugPrint('❌ Error: $message');
          _showSnackBar('Error: $message', Colors.red);
        },
        onVadScore: ({required vadScore}) {
          // Voice activity detection score
          // Can be used for visualization
        },
        onInterruption: (event) {
          debugPrint('⚡ Interruption detected');
        },
        onCanSendFeedbackChange: ({required canSendFeedback}) {
          setState(() {});
        },
        onTentativeUserTranscript: ({required transcript, required eventId}) {
          debugPrint('🎤 User speaking (live): "$transcript" [#$eventId]');
        },
        onUserTranscript: ({required transcript, required eventId}) {
          debugPrint('✅ User said: "$transcript" [#$eventId]');
        },
        onTentativeAgentResponse: ({required response}) {
          debugPrint('💭 Agent composing: "$response"');
        },
        onAgentResponseCorrection: (correction) {
          debugPrint('🔧 Agent correction: $correction');
        },
        onAgentChatResponsePart: (part) {
          debugPrint('📝 Agent text part [${part.type}]: "${part.text}"');
        },
        onDebug: (data) {
          debugPrint('🐛 Debug: $data');
        },
        onUnhandledClientToolCall: (toolCall) {
          debugPrint('⚠️ Unhandled tool call: ${toolCall.toolName}');
          _showSnackBar(
            'Tool not implemented: ${toolCall.toolName}',
            Colors.orange,
          );
        },
      ),
    );

    _clientListener = () {
      setState(() {});
    };
    _client.addListener(_clientListener!);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    if (_clientListener != null) {
      _client.removeListener(_clientListener!);
    }
    _client.dispose();
    _agentIdController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _startConversation() async {
    final agentId = _agentIdController.text.trim();
    if (agentId.isEmpty) {
      _showSnackBar('Please enter an agent ID', Colors.red);
      return;
    }

    try {
      await _client.startSession(agentId: agentId, userId: 'demo-user');
    } catch (e) {
      _showSnackBar('Failed to start: $e', Colors.red);
    }
  }

  Future<void> _endConversation() async {
    try {
      await _client.endSession();
    } catch (e) {
      _showSnackBar('Failed to end: $e', Colors.red);
    }
  }

  Future<void> _toggleMute() async {
    await _client.toggleMute();
    setState(() {});
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Please enter a message', Colors.orange);
      return;
    }

    _client.sendUserMessage(text);
    _messageController.clear();
    _showSnackBar('Message sent', Colors.green);
  }

  void _sendContextualMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Please enter a contextual message', Colors.orange);
      return;
    }

    _client.sendContextualUpdate(text);
    _messageController.clear();
    _showSnackBar('Contextual message sent', Colors.blue);
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _client.status == ConversationStatus.connected;
    final isDisconnected = _client.status == ConversationStatus.disconnected;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ElevenLabs Logo
                Image.asset(
                  'assets/elevenlabs_logo.png',
                  height: 40,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  'Flutter Example App',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 60),

                // Agent ID Input (only when disconnected)
                if (isDisconnected) ...[
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TextField(
                      controller: _agentIdController,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Agent ID',
                        hintText: 'Enter your agent ID',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.black,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Speaking Indicator
                if (isConnected) ...[
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (_client.isSpeaking
                                  ? Colors.black
                                  : Colors.grey[400]!)
                              .withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _client.isSpeaking
                            ? Colors.black
                            : Colors.grey[300],
                      ),
                      child: Icon(
                        _client.isSpeaking ? Icons.graphic_eq : Icons.mic,
                        size: 43,
                        color: _client.isSpeaking
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _client.isSpeaking ? 'Agent Speaking...' : 'Listening...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Main Action Button
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isDisconnected
                        ? _startConversation
                        : isConnected
                            ? _endConversation
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isConnected ? Colors.red[600] : Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      isConnected
                          ? 'Disconnect'
                          : isDisconnected
                              ? 'Connect'
                              : 'Connecting...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Mute Button (only when connected)
                if (isConnected) ...[
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    height: 56,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _toggleMute,
                      icon: Icon(_client.isMuted ? Icons.mic_off : Icons.mic),
                      label: Text(_client.isMuted ? 'Unmute' : 'Mute'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _client.isMuted
                            ? Colors.red[600]
                            : Colors.grey[700],
                        side: BorderSide(
                          color: (_client.isMuted
                              ? Colors.red[600]
                              : Colors.grey[400])!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Feedback Buttons (only when feedback can be sent)
                  if (_client.canSendFeedback) ...[
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        children: [
                          Text(
                            'Rate the last response',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _client.sendFeedback(isPositive: true),
                                  icon: const Icon(
                                    Icons.thumb_up_outlined,
                                    size: 20,
                                  ),
                                  label: const Text('Good'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green[700],
                                    side: BorderSide(color: Colors.green[400]!),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _client.sendFeedback(isPositive: false),
                                  icon: const Icon(
                                    Icons.thumb_down_outlined,
                                    size: 20,
                                  ),
                                  label: const Text('Bad'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red[700],
                                    side: BorderSide(color: Colors.red[400]!),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Message Input Section (only when connected)
                  const SizedBox(height: 32),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      children: [
                        // Text Input Field
                        TextField(
                          controller: _messageController,
                          maxLines: 3,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          onChanged: (_) => _client.sendUserActivity(),
                          onSubmitted: (_) => _sendMessage(),
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: 'Type your message here...',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Action Buttons Row
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _sendMessage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Send',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _sendContextualMessage,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[400]!),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Send contextual',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Status Indicator
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      _client.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(
                        _client.status,
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(_client.status),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _client.status.name.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(_client.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                // Conversation ID
                if (_client.conversationId != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ID: ${_client.conversationId}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ConversationStatus status) {
    switch (status) {
      case ConversationStatus.connected:
        return Colors.green;
      case ConversationStatus.connecting:
        return Colors.orange;
      case ConversationStatus.disconnecting:
        return Colors.orange;
      case ConversationStatus.disconnected:
        return Colors.grey;
    }
  }
}
