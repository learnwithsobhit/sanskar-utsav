import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/api_service.dart';

class AdminCommsPanel extends StatefulWidget {
  const AdminCommsPanel({super.key});

  @override
  State<AdminCommsPanel> createState() => _AdminCommsPanelState();
}

class _AdminCommsPanelState extends State<AdminCommsPanel> {
  List<CeremonyEvent> _events = [];
  bool _loadingEvents = true;

  final _notifyTitle = TextEditingController();
  final _notifyBody = TextEditingController();
  String _notifyType = 'announcement';
  bool _notifyAll = true;
  final _notifyGuestIds = TextEditingController();

  final _broadcastMsg = TextEditingController();

  int? _eventGroupId;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _notifyTitle.dispose();
    _notifyBody.dispose();
    _notifyGuestIds.dispose();
    _broadcastMsg.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    final result = await ApiService.get(ApiConfig.events);
    if (!mounted) return;
    setState(() {
      _loadingEvents = false;
      if (result['success'] == true && result['data'] != null) {
        _events = (result['data'] as List)
            .map((e) => CeremonyEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        _eventGroupId = _events.isNotEmpty ? _events.first.id : null;
      }
    });
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? SanskarTheme.vermillion : SanskarTheme.lotusGreen,
      ),
    );
  }

  List<String>? _parseGuestIds() {
    final raw = _notifyGuestIds.text.trim();
    if (raw.isEmpty) return [];
    final parts = raw.split(RegExp(r'[\s,;]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return parts;
  }

  Future<void> _sendNotify() async {
    if (_notifyTitle.text.trim().isEmpty || _notifyBody.text.trim().isEmpty) {
      _snack('Title and body required');
      return;
    }

    final body = <String, dynamic>{
      'title': _notifyTitle.text.trim(),
      'body': _notifyBody.text.trim(),
      'notification_type': _notifyType,
    };

    if (!_notifyAll) {
      final ids = _parseGuestIds();
      if (ids == null || ids.isEmpty) {
        _snack('Enter at least one guest UUID or enable "All guests"');
        return;
      }
      body['guest_ids'] = ids;
    }

    final result = await ApiService.post(ApiConfig.adminNotify, body);
    if (!mounted) return;
    if (result['success'] == true) {
      final n = result['notifications_sent'] ?? 0;
      _snack('Sent $n notification(s)', error: false);
    } else {
      _snack(result['error']?.toString() ?? 'Failed');
    }
  }

  Future<void> _sendBroadcast() async {
    if (_broadcastMsg.text.trim().isEmpty) {
      _snack('Message required');
      return;
    }
    final result = await ApiService.post(ApiConfig.adminChatBroadcast, {
      'message': _broadcastMsg.text.trim(),
      'message_type': 'text',
    });
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Broadcast sent', error: false);
      _broadcastMsg.clear();
    } else {
      _snack(result['error']?.toString() ?? 'Failed');
    }
  }

  Future<void> _createEventGroup() async {
    if (_eventGroupId == null) {
      _snack('Select an event');
      return;
    }
    final result = await ApiService.post(ApiConfig.adminChatEventGroup, {
      'event_id': _eventGroupId,
    });
    if (!mounted) return;
    if (result['success'] == true) {
      final enrolled = result['members_enrolled'] ?? 0;
      _snack('Room created. Members: $enrolled', error: false);
    } else {
      _snack(result['error']?.toString() ?? 'Failed');
    }
  }

  Future<void> _enrollAllFamily() async {
    final result = await ApiService.post(ApiConfig.adminChatEnrollAll, {});
    if (!mounted) return;
    if (result['success'] == true) {
      final e = result['enrolled'] ?? 0;
      _snack('Enrolled $e guest(s) into family group', error: false);
    } else {
      _snack(result['error']?.toString() ?? 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Push notifications', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _notifyTitle,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notifyBody,
            decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _notifyType,
            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'announcement', child: Text('announcement')),
              DropdownMenuItem(value: 'reminder', child: Text('reminder')),
              DropdownMenuItem(value: 'urgent', child: Text('urgent')),
            ],
            onChanged: (v) => setState(() => _notifyType = v ?? _notifyType),
          ),
          SwitchListTile(
            title: const Text('Send to all guests'),
            value: _notifyAll,
            onChanged: (v) => setState(() => _notifyAll = v),
          ),
          if (!_notifyAll) ...[
            TextField(
              controller: _notifyGuestIds,
              decoration: const InputDecoration(
                labelText: 'Guest UUIDs (comma or newline separated)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
          FilledButton(onPressed: _sendNotify, child: const Text('Send notifications')),
          const SizedBox(height: 32),
          Text('Family chat broadcast', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _broadcastMsg,
            decoration: const InputDecoration(
              labelText: 'Message to family group',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          FilledButton.tonal(onPressed: _sendBroadcast, child: const Text('Broadcast')),
          const SizedBox(height: 32),
          Text('Chat setup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingEvents)
            const LinearProgressIndicator()
          else if (_events.isEmpty)
            const Text('No events — refresh Events tab or check API')
          else
            DropdownButtonFormField<int>(
              value: _eventGroupId,
              decoration: const InputDecoration(
                labelText: 'Event for new group chat',
                border: OutlineInputBorder(),
              ),
              items: _events
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text('${e.iconEmoji} ${e.title}', overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _eventGroupId = v),
            ),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: _createEventGroup, child: const Text('Create event group chat')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _enrollAllFamily,
            icon: const Icon(Icons.group_add),
            label: const Text('Enroll all guests into family group'),
          ),
        ],
      ),
    );
  }
}
