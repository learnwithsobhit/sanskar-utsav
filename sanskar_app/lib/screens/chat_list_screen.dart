import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/guest.dart';

/// Chat room list screen
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    final result = await ApiService.get('${ApiConfig.apiUrl}/chat/rooms');
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _rooms = result['data'] ?? [];
        }
        _loading = false;
      });
    }
  }

  IconData _roomIcon(String type) {
    switch (type) {
      case 'direct':
        return Icons.person;
      case 'group':
        return Icons.group;
      case 'event':
        return Icons.event;
      default:
        return Icons.chat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💬 Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            onPressed: () => Navigator.pushNamed(context, '/calls'),
            tooltip: 'Call History',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
          : _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: SanskarTheme.darkCharcoal.withAlpha(130),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting with guests!',
                        style: TextStyle(
                          fontSize: 13,
                          color: SanskarTheme.darkCharcoal.withAlpha(100),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRooms,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) {
                      final room = _rooms[index];
                      final unread = room['unread_count'] ?? 0;
                      final name = room['name'] ?? 'Chat';
                      final lastMsg = room['last_message'];
                      final lastSender = room['last_sender_name'];
                      final roomType = room['room_type'] ?? '';

                      return GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/chat/conversation',
                          arguments: {
                            'room_id': room['id'],
                            'name': name,
                          },
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: unread > 0
                                ? SanskarTheme.saffron.withAlpha(8)
                                : SanskarTheme.softWhite,
                            borderRadius: SanskarTheme.radiusMd,
                            boxShadow: SanskarTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: roomType == 'group'
                                      ? SanskarTheme.saffronGradient
                                      : SanskarTheme.goldGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    _roomIcon(roomType),
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: unread > 0
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (lastMsg != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        lastSender != null
                                            ? '$lastSender: $lastMsg'
                                            : lastMsg,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: SanskarTheme.darkCharcoal.withAlpha(140),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (unread > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: SanskarTheme.saffron,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'new_chat_fab',
        onPressed: () => _showNewChatDialog(context),
        backgroundColor: SanskarTheme.saffron,
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewChatSheet(),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  List<Guest> _guests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    final result = await ApiService.get(ApiConfig.guests);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _guests = (result['data'] as List)
              .map((g) => Guest.fromJson(g))
              .toList();
        }
        _loading = false;
      });
    }
  }

  Future<void> _startDirectChat(Guest guest) async {
    final result = await ApiService.post(
      '${ApiConfig.apiUrl}/chat/rooms/direct',
      {'guest_id': guest.id},
    );
    if (result['success'] == true && mounted) {
      Navigator.pop(context); // close sheet
      Navigator.pushNamed(context, '/chat/conversation', arguments: {
        'room_id': result['room_id'],
        'name': guest.name,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Start a Conversation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
                : ListView.builder(
                    itemCount: _guests.length,
                    itemBuilder: (context, index) {
                      final g = _guests[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: SanskarTheme.saffron,
                          child: Text(g.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: g.relation.isNotEmpty ? Text(g.relation) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, size: 20),
                              onPressed: () => _startDirectChat(g),
                            ),
                            IconButton(
                              icon: const Icon(Icons.call, size: 20, color: SanskarTheme.lotusGreen),
                              onPressed: () {
                                // Will trigger call via WebRTC
                                Navigator.pop(context);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.videocam, size: 20, color: SanskarTheme.saffron),
                              onPressed: () {
                                // Will trigger video call
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
