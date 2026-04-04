import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/announcement.dart';
import '../../services/api_service.dart';

class AdminAnnouncementsPanel extends StatefulWidget {
  const AdminAnnouncementsPanel({super.key});

  @override
  State<AdminAnnouncementsPanel> createState() => _AdminAnnouncementsPanelState();
}

class _AdminAnnouncementsPanelState extends State<AdminAnnouncementsPanel> {
  List<Announcement> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.announcements);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true && result['data'] != null) {
        _items = (result['data'] as List)
            .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _items = [];
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

  Future<void> _showCreate() async {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final priorityCtrl = TextEditingController(text: '0');
    final dayCtrl = TextEditingController();
    String category = 'general';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *')),
                TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Message *'), maxLines: 4),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('general')),
                    DropdownMenuItem(value: 'urgent', child: Text('urgent')),
                    DropdownMenuItem(value: 'logistics', child: Text('logistics')),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                TextField(
                  controller: priorityCtrl,
                  decoration: const InputDecoration(labelText: 'Priority (0–2)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: dayCtrl,
                  decoration: const InputDecoration(labelText: 'Target day (optional)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    if (titleCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) {
      _snack('Title and message required');
      return;
    }

    final body = <String, dynamic>{
      'title': titleCtrl.text.trim(),
      'message': msgCtrl.text.trim(),
      'category': category,
      'priority': int.tryParse(priorityCtrl.text.trim()) ?? 0,
      if (dayCtrl.text.trim().isNotEmpty) 'target_day': int.tryParse(dayCtrl.text.trim()),
    };

    final result = await ApiService.post(ApiConfig.adminAnnouncements, body);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Created', error: false);
      await _load();
    } else {
      _snack(result['error']?.toString() ?? 'Failed');
    }
  }

  Future<void> _edit(Announcement a) async {
    final titleCtrl = TextEditingController(text: a.title);
    final msgCtrl = TextEditingController(text: a.message);
    final priorityCtrl = TextEditingController(text: '${a.priority}');
    final dayCtrl = TextEditingController(text: a.targetDay?.toString() ?? '');
    String category = a.category;
    bool active = a.isActive;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit announcement', style: Theme.of(ctx).textTheme.titleLarge),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Message'), maxLines: 4),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('general')),
                    DropdownMenuItem(value: 'urgent', child: Text('urgent')),
                    DropdownMenuItem(value: 'logistics', child: Text('logistics')),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                TextField(controller: priorityCtrl, decoration: const InputDecoration(labelText: 'Priority'), keyboardType: TextInputType.number),
                TextField(controller: dayCtrl, decoration: const InputDecoration(labelText: 'Target day'), keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
                FilledButton(
                  onPressed: () async {
                    final result = await ApiService.patch(
                      ApiConfig.adminAnnouncementUpdate(a.id),
                      {
                        'title': titleCtrl.text.trim(),
                        'message': msgCtrl.text.trim(),
                        'category': category,
                        'priority': int.tryParse(priorityCtrl.text.trim()) ?? a.priority,
                        'is_active': active,
                        'target_day': dayCtrl.text.trim().isEmpty
                            ? null
                            : int.tryParse(dayCtrl.text.trim()),
                      },
                    );
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    if (result['success'] == true) {
                      _snack('Saved', error: false);
                      await _load();
                    } else {
                      _snack(result['error']?.toString() ?? 'Failed');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: Text(a.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await ApiService.delete(ApiConfig.adminAnnouncementUpdate(a.id));
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Deleted', error: false);
      await _load();
    } else {
      _snack(result['error']?.toString() ?? 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _showCreate,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(backgroundColor: SanskarTheme.saffron.withOpacity(0.12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Showing active announcements from public API',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('None'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = _items[i];
                    return ListTile(
                      title: Text(a.title),
                      subtitle: Text(
                        a.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _edit(a);
                          if (v == 'delete') _delete(a);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      onTap: () => _edit(a),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
