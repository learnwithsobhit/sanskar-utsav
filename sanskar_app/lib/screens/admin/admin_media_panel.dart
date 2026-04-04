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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.adminPendingMedia);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron));
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No pending media'),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: SanskarTheme.saffron,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
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
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 100,
                              height: 100,
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          width: 100,
                          height: 100,
                          child: Center(child: Icon(Icons.videocam, size: 40)),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title.isEmpty ? m.mediaType : m.title,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(m.mimeType, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            Text('ID ${m.id}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _patch(m.id, {'is_approved': true}),
                        child: const Text('Approve'),
                      ),
                      OutlinedButton(
                        onPressed: () => _patch(m.id, {'is_approved': false}),
                        child: const Text('Reject'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _patch(m.id, {'is_featured': true, 'is_approved': true}),
                        child: const Text('Feature'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
