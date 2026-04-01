import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/event.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  List<CeremonyEvent> _events = [];
  bool _loading = true;
  late TabController _tabController;
  int _maxDays = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _maxDays, vsync: this);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final result = await ApiService.get(ApiConfig.events);
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _events = (result['data'] as List)
              .map((e) => CeremonyEvent.fromJson(e))
              .toList();
          // Determine number of days
          if (_events.isNotEmpty) {
            final days = _events.map((e) => e.dayNumber).toSet().length;
            if (days != _maxDays) {
              _maxDays = days.clamp(1, 7);
              _tabController.dispose();
              _tabController = TabController(length: _maxDays, vsync: this);
            }
          }
        }
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Ceremony Schedule'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: _maxDays > 4,
          labelColor: SanskarTheme.saffron,
          unselectedLabelColor: SanskarTheme.darkCharcoal.withAlpha(120),
          indicatorColor: SanskarTheme.saffron,
          indicatorWeight: 3,
          tabs: List.generate(_maxDays, (i) => Tab(text: 'Day ${i + 1}')),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron))
          : TabBarView(
              controller: _tabController,
              children: List.generate(_maxDays, (dayIndex) {
                final dayEvents = _events
                    .where((e) => e.dayNumber == dayIndex + 1)
                    .toList();
                if (dayEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🕉️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'No events scheduled for Day ${dayIndex + 1}',
                          style: TextStyle(
                            color: SanskarTheme.darkCharcoal.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dayEvents.length,
                  itemBuilder: (context, index) {
                    return _TimelineEventCard(
                      event: dayEvents[index],
                      isFirst: index == 0,
                      isLast: index == dayEvents.length - 1,
                    );
                  },
                );
              }),
            ),
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  final CeremonyEvent event;
  final bool isFirst;
  final bool isLast;

  const _TimelineEventCard({
    required this.event,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = SanskarTheme.categoryColor(event.category);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    flex: 1,
                    child: Container(width: 2, color: catColor.withAlpha(60)),
                  ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: catColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: catColor.withAlpha(80),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    flex: 3,
                    child: Container(width: 2, color: catColor.withAlpha(60)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Event card
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/event', arguments: event),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SanskarTheme.softWhite,
                  borderRadius: SanskarTheme.radiusMd,
                  boxShadow: SanskarTheme.cardShadow,
                  border: Border.all(color: catColor.withAlpha(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(event.iconEmoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.hindiTitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          event.hindiTitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: SanskarTheme.darkCharcoal.withAlpha(140),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Time
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: catColor),
                        const SizedBox(width: 4),
                        Text(
                          event.timeRange,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                    if (event.venue.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: catColor.withAlpha(180)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              event.venue,
                              style: TextStyle(
                                fontSize: 12,
                                color: SanskarTheme.darkCharcoal.withAlpha(150),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.dressCode.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.checkroom, size: 14, color: catColor.withAlpha(180)),
                          const SizedBox(width: 4),
                          Text(
                            event.dressCode,
                            style: TextStyle(
                              fontSize: 12,
                              color: SanskarTheme.darkCharcoal.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withAlpha(20),
                        borderRadius: SanskarTheme.radiusSm,
                      ),
                      child: Text(
                        event.categoryLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: catColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
