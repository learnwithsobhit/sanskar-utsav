import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/api_service.dart';

String? _toHhMm(String? t) {
  if (t == null || t.isEmpty) return null;
  final parts = t.split(':');
  if (parts.length >= 2) {
    final h = parts[0].padLeft(2, '0');
    final m = parts[1].padLeft(2, '0');
    return '$h:$m';
  }
  return t;
}

class AdminEventsPanel extends StatefulWidget {
  const AdminEventsPanel({super.key});

  @override
  State<AdminEventsPanel> createState() => _AdminEventsPanelState();
}

class _AdminEventsPanelState extends State<AdminEventsPanel> {
  List<CeremonyEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.events);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true && result['data'] != null) {
        _events = (result['data'] as List)
            .map((e) => CeremonyEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _events = [];
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

  Future<void> _showCreateDialog() async {
    final dayCtrl = TextEditingController(text: '1');
    final titleCtrl = TextEditingController();
    final hindiCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final mapCtrl = TextEditingController();
    final dressCtrl = TextEditingController();
    final bannerCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🕉️');
    final sortCtrl = TextEditingController(text: '0');
    String category = 'ritual';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: dayCtrl, decoration: const InputDecoration(labelText: 'Day number'), keyboardType: TextInputType.number),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *')),
                TextField(controller: hindiCtrl, decoration: const InputDecoration(labelText: 'Hindi title')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date YYYY-MM-DD *')),
                TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start HH:MM')),
                TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End HH:MM')),
                TextField(controller: venueCtrl, decoration: const InputDecoration(labelText: 'Venue')),
                TextField(controller: mapCtrl, decoration: const InputDecoration(labelText: 'Map URL')),
                TextField(controller: dressCtrl, decoration: const InputDecoration(labelText: 'Dress code')),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'ritual', child: Text('ritual')),
                    DropdownMenuItem(value: 'feast', child: Text('feast')),
                    DropdownMenuItem(value: 'celebration', child: Text('celebration')),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                TextField(controller: bannerCtrl, decoration: const InputDecoration(labelText: 'Banner URL')),
                TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Icon emoji')),
                TextField(controller: sortCtrl, decoration: const InputDecoration(labelText: 'Sort order'), keyboardType: TextInputType.number),
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
    final day = int.tryParse(dayCtrl.text.trim()) ?? 1;
    if (titleCtrl.text.trim().isEmpty || dateCtrl.text.trim().isEmpty) {
      _snack('Title and date required');
      return;
    }

    final body = <String, dynamic>{
      'day_number': day,
      'title': titleCtrl.text.trim(),
      'hindi_title': hindiCtrl.text.trim().isEmpty ? null : hindiCtrl.text.trim(),
      'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      'event_date': dateCtrl.text.trim(),
      'start_time': startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
      'end_time': endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
      'venue': venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
      'venue_map_url': mapCtrl.text.trim().isEmpty ? null : mapCtrl.text.trim(),
      'dress_code': dressCtrl.text.trim().isEmpty ? null : dressCtrl.text.trim(),
      'category': category,
      'banner_url': bannerCtrl.text.trim().isEmpty ? null : bannerCtrl.text.trim(),
      'icon_emoji': emojiCtrl.text.trim().isEmpty ? null : emojiCtrl.text.trim(),
      'sort_order': int.tryParse(sortCtrl.text.trim()) ?? 0,
    };

    final result = await ApiService.post(ApiConfig.adminEvents, body);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Event created', error: false);
      await _load();
    } else {
      _snack(result['error']?.toString() ?? 'Failed');
    }
  }

  Future<void> _editEvent(CeremonyEvent e) async {
    final titleCtrl = TextEditingController(text: e.title);
    final hindiCtrl = TextEditingController(text: e.hindiTitle);
    final descCtrl = TextEditingController(text: e.description);
    final dateCtrl = TextEditingController(text: e.eventDate.length >= 10 ? e.eventDate.substring(0, 10) : e.eventDate);
    final startCtrl = TextEditingController(text: _toHhMm(e.startTime) ?? '');
    final endCtrl = TextEditingController(text: _toHhMm(e.endTime) ?? '');
    final venueCtrl = TextEditingController(text: e.venue);
    final mapCtrl = TextEditingController(text: e.venueMapUrl);
    final dressCtrl = TextEditingController(text: e.dressCode);
    final bannerCtrl = TextEditingController(text: e.bannerUrl);
    final emojiCtrl = TextEditingController(text: e.iconEmoji);
    final dayCtrl = TextEditingController(text: '${e.dayNumber}');
    final sortCtrl = TextEditingController(text: '${e.sortOrder}');
    String category = e.category;
    bool isActive = e.isActive;

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
                Text('Edit event', style: Theme.of(ctx).textTheme.titleLarge),
                TextField(controller: dayCtrl, decoration: const InputDecoration(labelText: 'Day number'), keyboardType: TextInputType.number),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: hindiCtrl, decoration: const InputDecoration(labelText: 'Hindi title')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date YYYY-MM-DD')),
                TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start HH:MM')),
                TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End HH:MM')),
                TextField(controller: venueCtrl, decoration: const InputDecoration(labelText: 'Venue')),
                TextField(controller: mapCtrl, decoration: const InputDecoration(labelText: 'Map URL')),
                TextField(controller: dressCtrl, decoration: const InputDecoration(labelText: 'Dress code')),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'ritual', child: Text('ritual')),
                    DropdownMenuItem(value: 'feast', child: Text('feast')),
                    DropdownMenuItem(value: 'celebration', child: Text('celebration')),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? category),
                ),
                TextField(controller: bannerCtrl, decoration: const InputDecoration(labelText: 'Banner URL')),
                TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji')),
                TextField(controller: sortCtrl, decoration: const InputDecoration(labelText: 'Sort order'), keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setLocal(() => isActive = v),
                ),
                FilledButton(
                  onPressed: () async {
                    final result = await ApiService.patch(
                      ApiConfig.adminEventUpdate(e.id),
                      {
                        'day_number': int.tryParse(dayCtrl.text.trim()) ?? e.dayNumber,
                        'title': titleCtrl.text.trim(),
                        'hindi_title': hindiCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'event_date': dateCtrl.text.trim(),
                        'start_time': startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
                        'end_time': endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
                        'venue': venueCtrl.text.trim(),
                        'venue_map_url': mapCtrl.text.trim(),
                        'dress_code': dressCtrl.text.trim(),
                        'category': category,
                        'banner_url': bannerCtrl.text.trim(),
                        'icon_emoji': emojiCtrl.text.trim(),
                        'sort_order': int.tryParse(sortCtrl.text.trim()) ?? e.sortOrder,
                        'is_active': isActive,
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

  Future<void> _confirmDelete(CeremonyEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(e.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await ApiService.delete(ApiConfig.adminEventUpdate(e.id));
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Deleted', error: false);
      await _load();
    } else {
      _snack(result['error']?.toString() ?? 'Delete failed');
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
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('New event'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                style: IconButton.styleFrom(backgroundColor: SanskarTheme.saffron.withOpacity(0.12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _events.isEmpty
              ? const Center(child: Text('No events'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = _events[i];
                    return ListTile(
                      leading: Text(e.iconEmoji, style: const TextStyle(fontSize: 28)),
                      title: Text(e.title),
                      subtitle: Text('${e.eventDate} · Day ${e.dayNumber}${e.isActive ? '' : ' (inactive)'}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _editEvent(e);
                          if (v == 'delete') _confirmDelete(e);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      onTap: () => _editEvent(e),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
