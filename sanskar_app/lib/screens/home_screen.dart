import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/event.dart';
import '../models/announcement.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CeremonyEvent> _events = [];
  List<Announcement> _announcements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final eventsResult = await ApiService.get(ApiConfig.events);
    final annResult = await ApiService.get(ApiConfig.announcements);

    if (mounted) {
      setState(() {
        if (eventsResult['success'] == true) {
          _events = (eventsResult['data'] as List)
              .map((e) => CeremonyEvent.fromJson(e))
              .toList();
        }
        if (annResult['success'] == true) {
          _announcements = (annResult['data'] as List)
              .map((a) => Announcement.fromJson(a))
              .toList();
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final guest = auth.currentGuest;

    // Calculate days until ceremony (Day 3 = Main event)
    final mainEvent = _events.where((e) => e.dayNumber == 3).toList();
    final ceremonyDate = mainEvent.isNotEmpty
        ? DateTime.tryParse(mainEvent.first.eventDate)
        : null;
    final daysUntil = ceremonyDate != null
        ? ceremonyDate.difference(DateTime.now()).inDays
        : null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: SanskarTheme.saffron,
        child: CustomScrollView(
          slivers: [
            // ─── Hero Header ───
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  right: 20,
                  bottom: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: SanskarTheme.saffronGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🙏 Namaste${guest != null ? ', ${guest.name.split(" ").first}' : ''}!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Sanskar Utsav',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/notifications'),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Countdown card
                    if (daysUntil != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: SanskarTheme.radiusMd,
                          border: Border.all(
                            color: SanskarTheme.gold.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: SanskarTheme.gold.withAlpha(40),
                                borderRadius: SanskarTheme.radiusSm,
                              ),
                              child: Center(
                                child: Text(
                                  daysUntil <= 0 ? '🎉' : '$daysUntil',
                                  style: TextStyle(
                                    fontSize: daysUntil <= 0 ? 28 : 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    daysUntil <= 0
                                        ? '🕉️ Ceremony is here!'
                                        : daysUntil == 1
                                            ? 'Tomorrow is the day!'
                                            : '$daysUntil days to go!',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Shrihan\'s Yogyopaveet Sanskar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(180),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ─── Quick Actions ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Access',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _QuickAction(
                          icon: '📅',
                          label: 'Schedule',
                          onTap: () => Navigator.pushNamed(context, '/schedule'),
                        ),
                        _QuickAction(
                          icon: '📸',
                          label: 'Gallery',
                          onTap: () => Navigator.pushNamed(context, '/media'),
                        ),
                        _QuickAction(
                          icon: '👥',
                          label: 'Guests',
                          onTap: () => Navigator.pushNamed(context, '/guests'),
                        ),
                        _QuickAction(
                          icon: '🙏',
                          label: 'Blessings',
                          onTap: () => Navigator.pushNamed(context, '/blessings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ─── Announcements ───
            if (_announcements.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Announcements',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/announcements'),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._announcements.take(2).map((a) => _AnnouncementCard(announcement: a)),
                    ],
                  ),
                ),
              ),

            // ─── Upcoming Events ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Event Schedule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/schedule'),
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_loading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: SanskarTheme.saffron),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = _events[index];
                    return _EventCard(event: event);
                  },
                  childCount: _events.length.clamp(0, 5),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: SanskarTheme.softWhite,
            borderRadius: SanskarTheme.radiusMd,
            boxShadow: SanskarTheme.cardShadow,
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SanskarTheme.darkCharcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final isUrgent = announcement.isUrgent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUrgent
            ? SanskarTheme.vermillion.withAlpha(15)
            : SanskarTheme.softWhite,
        borderRadius: SanskarTheme.radiusMd,
        border: Border.all(
          color: isUrgent
              ? SanskarTheme.vermillion.withAlpha(50)
              : SanskarTheme.saffron.withAlpha(30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isUrgent ? SanskarTheme.vermillion : SanskarTheme.saffron)
                  .withAlpha(20),
              borderRadius: SanskarTheme.radiusSm,
            ),
            child: Icon(
              isUrgent ? Icons.priority_high : Icons.campaign_outlined,
              size: 18,
              color: isUrgent ? SanskarTheme.vermillion : SanskarTheme.saffron,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isUrgent ? SanskarTheme.vermillion : SanskarTheme.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  announcement.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: SanskarTheme.darkCharcoal.withAlpha(160),
                    height: 1.4,
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

class _EventCard extends StatelessWidget {
  final CeremonyEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final catColor = SanskarTheme.categoryColor(event.category);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/event', arguments: event),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SanskarTheme.softWhite,
          borderRadius: SanskarTheme.radiusMd,
          boxShadow: SanskarTheme.cardShadow,
        ),
        child: Row(
          children: [
            // Day indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [catColor, catColor.withAlpha(180)],
                ),
                borderRadius: SanskarTheme.radiusSm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Day',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withAlpha(220),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${event.dayNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${event.iconEmoji} ${event.title}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.hindiTitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.hindiTitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: SanskarTheme.darkCharcoal.withAlpha(140),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 13, color: catColor.withAlpha(180)),
                      const SizedBox(width: 4),
                      Text(
                        event.timeRange,
                        style: TextStyle(
                          fontSize: 11,
                          color: SanskarTheme.darkCharcoal.withAlpha(150),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (event.venue.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.location_on, size: 13, color: catColor.withAlpha(180)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            event.venue,
                            style: TextStyle(
                              fontSize: 11,
                              color: SanskarTheme.darkCharcoal.withAlpha(150),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: SanskarTheme.darkCharcoal.withAlpha(80),
            ),
          ],
        ),
      ),
    );
  }
}
