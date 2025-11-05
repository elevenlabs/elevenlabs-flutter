import 'package:flutter/material.dart';
import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElevenLabs Flutter Example',
      theme: ThemeData.dark(useMaterial3: true),
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
  final _messageController = TextEditingController();
  final _agentIdController = TextEditingController(
    text: 'agent_4901k7fh5jkrecmbn5zsm7d38z3h', // Default agent ID
  );
  final _messages = <ConversationMessage>[];
  final _scrollController = ScrollController();

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
      callbacks: ConversationCallbacks(
        onConnect: ({required conversationId}) {
          debugPrint('✅ Connected: $conversationId');
          _showSnackBar('Connected: $conversationId', Colors.green);
        },
        onDisconnect: (details) {
          debugPrint('❌ Disconnected: ${details.reason}');
          _showSnackBar('Disconnected: ${details.reason}', Colors.orange);
        },
        onMessage: ({required message, required source}) {
          debugPrint('💬 Message: $message');
          setState(() {
            _messages.add(ConversationMessage(
              text: message,
              source: source,
              timestamp: DateTime.now(),
            ));
          });
          _scrollToBottom();
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
        onDebug: (data) {
          debugPrint('🐛 Debug: $data');
        },
      ),
      clientTools: {
        'logMessage': LogMessageTool(),
      },
    );

    _client.addListener(() {
      setState(() {});
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
    _client.dispose();
    _messageController.dispose();
    _agentIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startConversation() async {
    final agentId = _agentIdController.text.trim();
    if (agentId.isEmpty) {
      _showSnackBar('Please enter an agent ID', Colors.red);
      return;
    }

    try {
      await _client.startSession(
        agentId: agentId,
        userId: 'demo-user',
      );
    } catch (e) {
      _showSnackBar('Failed to start: $e', Colors.red);
    }
  }

  Future<void> _endConversation() async {
    try {
      await _client.endSession();
      setState(() {
        _messages.clear();
      });
    } catch (e) {
      _showSnackBar('Failed to end: $e', Colors.red);
    }
  }

  Future<void> _toggleMute() async {
    await _client.toggleMute();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _client.sendUserMessage(text);
    _messageController.clear();
  }

  void _sendContextualUpdate() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _client.sendContextualUpdate(text);
    _messageController.clear();
    _showSnackBar('Contextual update sent', Colors.blue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ElevenLabs Flutter Example'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Status indicator
              StatusIndicator(status: _client.status),
              const SizedBox(height: 16),

              // Conversation ID display
              if (_client.conversationId != null)
                Text(
                  'ID: ${_client.conversationId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

              // Speaking indicator
              if (_client.status == ConversationStatus.connected)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SpeakingIndicator(
                    isSpeaking: _client.isSpeaking,
                    mode: _client.mode,
                  ),
                ),

              const SizedBox(height: 16),

              // Agent ID input (only when disconnected)
              if (_client.status == ConversationStatus.disconnected)
                TextField(
                  controller: _agentIdController,
                  decoration: const InputDecoration(
                    labelText: 'Agent ID',
                    border: OutlineInputBorder(),
                    hintText: 'Enter your agent ID',
                  ),
                ),

              const SizedBox(height: 16),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _client.status == ConversationStatus.disconnected
                        ? _startConversation
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _client.status == ConversationStatus.connected
                        ? _endConversation
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('End'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_client.isMuted ? Icons.mic_off : Icons.mic),
                    onPressed: _client.status == ConversationStatus.connected
                        ? _toggleMute
                        : null,
                    color: _client.isMuted ? Colors.red : Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Feedback buttons
              if (_client.canSendFeedback)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.thumb_up),
                      onPressed: () => _client.sendFeedback(isPositive: true),
                      color: Colors.green,
                    ),
                    IconButton(
                      icon: const Icon(Icons.thumb_down),
                      onPressed: () => _client.sendFeedback(isPositive: false),
                      color: Colors.red,
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Message list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text('No messages yet'),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return MessageBubble(message: msg);
                          },
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Message input
              if (_client.status == ConversationStatus.connected)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _client.sendUserActivity(),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                      tooltip: 'Send message',
                    ),
                    IconButton(
                      icon: const Icon(Icons.note_add),
                      onPressed: _sendContextualUpdate,
                      tooltip: 'Send contextual update',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final ConversationStatus status;

  const StatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case ConversationStatus.connected:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ConversationStatus.connecting:
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case ConversationStatus.disconnecting:
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case ConversationStatus.disconnected:
        color = Colors.red;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class SpeakingIndicator extends StatelessWidget {
  final bool isSpeaking;
  final ConversationMode mode;

  const SpeakingIndicator({
    super.key,
    required this.isSpeaking,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSpeaking ? Icons.record_voice_over : Icons.hearing,
          color: isSpeaking ? Colors.purple : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          isSpeaking ? 'AI Speaking' : 'AI Listening',
          style: TextStyle(
            color: isSpeaking ? Colors.purple : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ConversationMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.source == Role.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser ? 'You' : 'AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isUser ? Colors.white70 : Colors.white60,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.text,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationMessage {
  final String text;
  final Role source;
  final DateTime timestamp;

  ConversationMessage({
    required this.text,
    required this.source,
    required this.timestamp,
  });
}

// Example client tool implementation
class LogMessageTool implements ClientTool {
  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    final message = parameters['message'] as String?;
    if (message == null) {
      return ClientToolResult.failure('Missing message parameter');
    }

    debugPrint('📝 Client Tool Log: $message');

    // Return null for fire-and-forget tools
    return null;
  }
}

