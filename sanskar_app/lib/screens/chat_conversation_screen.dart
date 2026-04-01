import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

class ChatConversationScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatConversationScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final result = await ApiService.get(
      '${ApiConfig.apiUrl}/chat/rooms/${widget.roomId}/messages',
    );
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _messages = (result['data'] as List).reversed.toList();
        }
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgController.clear();

    final result = await ApiService.post(
      '${ApiConfig.apiUrl}/chat/rooms/${widget.roomId}/messages',
      {'content': text, 'message_type': 'text'},
    );

    if (mounted) {
      setState(() => _sending = false);
      if (result['success'] == true) {
        _loadMessages();
      }
    }
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

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final myId = auth.currentGuest?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: SanskarTheme.goldGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.roomName.isNotEmpty ? widget.roomName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.roomName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: SanskarTheme.lotusGreen),
            onPressed: () {
              // Future: initiate audio call
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: SanskarTheme.saffron),
            onPressed: () {
              // Future: initiate video call
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Say hello! 🙏',
                          style: TextStyle(
                            fontSize: 16,
                            color: SanskarTheme.darkCharcoal.withAlpha(120),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] == myId;
                          final senderName = msg['sender_name'] ?? '';
                          final content = msg['content'] ?? '';
                          final msgType = msg['message_type'] ?? 'text';
                          final isDeleted = msg['is_deleted'] ?? false;

                          return _MessageBubble(
                            content: isDeleted ? '🚫 Message deleted' : content,
                            senderName: senderName,
                            isMe: isMe,
                            messageType: msgType,
                            mediaUrl: msg['media_url'] ?? '',
                            isDeleted: isDeleted,
                          );
                        },
                      ),
          ),
          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewPadding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: SanskarTheme.softWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Attachment
                GestureDetector(
                  onTap: () {
                    // Future: media picker
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: SanskarTheme.saffron.withAlpha(15),
                      borderRadius: SanskarTheme.radiusSm,
                    ),
                    child: const Icon(Icons.add, size: 20, color: SanskarTheme.saffron),
                  ),
                ),
                const SizedBox(width: 8),
                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: SanskarTheme.radiusXl,
                      border: Border.all(color: SanskarTheme.saffron.withAlpha(40)),
                    ),
                    child: TextField(
                      controller: _msgController,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: SanskarTheme.darkCharcoal.withAlpha(100),
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: SanskarTheme.saffronGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: SanskarTheme.saffron.withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final String senderName;
  final bool isMe;
  final String messageType;
  final String mediaUrl;
  final bool isDeleted;

  const _MessageBubble({
    required this.content,
    required this.senderName,
    required this.isMe,
    this.messageType = 'text',
    this.mediaUrl = '',
    this.isDeleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: SanskarTheme.gold.withAlpha(60),
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? SanskarTheme.saffron
                    : SanskarTheme.softWhite,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SanskarTheme.saffron,
                      ),
                    ),
                  if (!isMe) const SizedBox(height: 3),
                  if (messageType == 'image' && mediaUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        mediaUrl,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : SanskarTheme.darkCharcoal,
                      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
