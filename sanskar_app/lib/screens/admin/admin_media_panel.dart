import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/media_item.dart';
import '../../services/api_service.dart';

class AdminMediaPanel extends StatefulWidget {
  const AdminMediaPanel({super.key});

  @override
  State<AdminMediaPanel> createState() => _AdminMediaPanelState();
}

class _AdminMediaPanelState extends State<AdminMediaPanel> {
  List<MediaItem> _items = [];
  bool _loading = true;
  /// `false` = all media; `true` = only items awaiting approval (legacy pending API behavior).
  bool _pendingOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final url = ApiConfig.adminMediaList(page: 1, perPage: 100, pendingOnly: _pendingOnly);
    final result = await ApiService.get(url);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true && result['data'] != null) {
        _items = (result['data'] as List)
            .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
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

  Future<void> _patch(int id, Map<String, dynamic> body) async {
    final result = await ApiService.patch(ApiConfig.adminMediaUpdate(id), body);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Updated', error: false);
      await _load();
    } else {
      _snack(result['error']?.toString() ?? 'Failed');
    }
  }

  Future<void> _showEditSheet(MediaItem m) async {
    final titleCtrl = TextEditingController(text: m.title);
    final descCtrl = TextEditingController(text: m.description);
    final eventCtrl = TextEditingController(text: m.eventId?.toString() ?? '');
    bool removeEventLink = false;

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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit media', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                TextField(
                  controller: eventCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Event ID (optional)',
                    hintText: 'Ceremony event id',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !removeEventLink,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remove event link'),
                  value: removeEventLink,
                  onChanged: (v) => setLocal(() {
                    removeEventLink = v ?? false;
                    if (removeEventLink) eventCtrl.clear();
                  }),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    final body = <String, dynamic>{
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                    };
                    if (removeEventLink) {
                      body['event_id'] = null;
                    } else {
                      final t = eventCtrl.text.trim();
                      if (t.isNotEmpty) {
                        final eid = int.tryParse(t);
                        if (eid == null) {
                          _snack('Invalid event ID');
                          return;
                        }
                        if (eid != m.eventId) body['event_id'] = eid;
                      }
                    }
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    await _patch(m.id, body);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('All media'), icon: Icon(Icons.photo_library_outlined)),
                  ButtonSegment<bool>(value: true, label: Text('Pending'), icon: Icon(Icons.pending_outlined)),
                ],
                selected: {_pendingOnly},
                onSelectionChanged: (set) {
                  setState(() {
                    _pendingOnly = set.first;
                  });
                  _load();
                },
              ),
              const SizedBox(height: 8),
              Text(
                _pendingOnly
                    ? 'Items waiting for approval (is_approved = false).'
                    : 'Every upload, approved or not. Use Pending to moderate new items.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _pendingOnly
                          ? 'No pending media. Try “All media” or approve items from the full list.'
                          : 'No media uploaded yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: SanskarTheme.saffron,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final m = _items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.isPhoto && m.fileUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        m.fileUrl,
                                        width: 88,
                                        height: 88,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox(
                                          width: 88,
                                          height: 88,
                                          child: Icon(Icons.broken_image),
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(
                                      width: 88,
                                      height: 88,
                                      child: Center(child: Icon(Icons.videocam, size: 36)),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.title.isEmpty ? m.mediaType : m.title,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Chip(
                                              label: Text(
                                                m.isApproved ? 'Approved' : 'Pending',
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: m.isApproved
                                                  ? SanskarTheme.lotusGreen.withAlpha(40)
                                                  : SanskarTheme.turmeric.withAlpha(60),
                                            ),
                                            if (m.isFeatured)
                                              Chip(
                                                label: const Text('Featured', style: TextStyle(fontSize: 11)),
                                                visualDensity: VisualDensity.compact,
                                                backgroundColor: SanskarTheme.saffron.withAlpha(40),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          m.mimeType,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                        if (m.uploaderDisplayName.isNotEmpty)
                                          Text(
                                            'By ${m.uploaderDisplayName}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        if (m.eventTitle != null && m.eventTitle!.isNotEmpty)
                                          Text(
                                            'Event: ${m.eventTitle}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                        Text('ID ${m.id}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _showEditSheet(m);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit details')),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!m.isApproved)
                                    FilledButton(
                                      onPressed: () => _patch(m.id, {'is_approved': true}),
                                      child: const Text('Approve'),
                                    ),
                                  if (m.isApproved)
                                    OutlinedButton(
                                      onPressed: () => _patch(m.id, {'is_approved': false}),
                                      child: const Text('Unapprove'),
                                    ),
                                  if (!m.isFeatured)
                                    FilledButton.tonal(
                                      onPressed: () => _patch(m.id, {'is_featured': true, 'is_approved': true}),
                                      child: const Text('Feature'),
                                    ),
                                  if (m.isFeatured)
                                    OutlinedButton(
                                      onPressed: () => _patch(m.id, {'is_featured': false}),
                                      child: const Text('Unfeature'),
                                    ),
                                  TextButton.icon(
                                    onPressed: () => _showEditSheet(m),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('Edit'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
