import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/announcement.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement> _announcements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.announcements);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _announcements = (result['data'] as List)
              .map((a) => Announcement.fromJson(a))
              .toList();
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📢 Announcements')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
          : _announcements.isEmpty
              ? const Center(child: Text('No announcements yet'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _announcements.length,
                    itemBuilder: (context, index) {
                      final a = _announcements[index];
                      return _AnnouncementTile(announcement: a);
                    },
                  ),
                ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementTile({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final isUrgent = announcement.isUrgent;
    final isImportant = announcement.isImportant;
    final accent = isUrgent
        ? SanskarTheme.vermillion
        : isImportant
            ? SanskarTheme.deepSaffron
            : SanskarTheme.saffron;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SanskarTheme.softWhite,
        borderRadius: SanskarTheme.radiusMd,
        boxShadow: SanskarTheme.cardShadow,
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: SanskarTheme.vermillion,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'URGENT',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              Expanded(
                child: Text(
                  announcement.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            announcement.message,
            style: TextStyle(
              fontSize: 14,
              color: SanskarTheme.darkCharcoal.withAlpha(180),
              height: 1.5,
            ),
          ),
          if (announcement.targetDay != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withAlpha(15),
                borderRadius: SanskarTheme.radiusSm,
              ),
              child: Text(
                'Day ${announcement.targetDay}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
