import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class EventDetailScreen extends StatelessWidget {
  final CeremonyEvent event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final catColor = SanskarTheme.categoryColor(event.category);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [catColor, catColor.withAlpha(180)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(event.iconEmoji, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        'Day ${event.dayNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(200),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              title: Text(
                event.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hindi title
                  if (event.hindiTitle.isNotEmpty) ...[
                    Text(
                      event.hindiTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: catColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Info cards
                  _InfoRow(icon: Icons.schedule, label: 'Time', value: event.timeRange, color: catColor),
                  _InfoRow(icon: Icons.calendar_today, label: 'Date', value: event.eventDate, color: catColor),
                  if (event.venue.isNotEmpty)
                    _InfoRow(icon: Icons.location_on, label: 'Venue', value: event.venue, color: catColor),
                  if (event.dressCode.isNotEmpty)
                    _InfoRow(icon: Icons.checkroom, label: 'Dress Code', value: event.dressCode, color: catColor),

                  const SizedBox(height: 20),

                  // Description
                  if (event.description.isNotEmpty) ...[
                    const Text(
                      'About this Event',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SanskarTheme.softWhite,
                        borderRadius: SanskarTheme.radiusMd,
                        border: Border.all(color: catColor.withAlpha(20)),
                      ),
                      child: Text(
                        event.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: SanskarTheme.darkCharcoal.withAlpha(180),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // RSVP Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRsvpDialog(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('RSVP for this Event'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: catColor,
                      ),
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

  void _showRsvpDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RsvpBottomSheet(event: event),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: SanskarTheme.radiusSm,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: SanskarTheme.darkCharcoal.withAlpha(120),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RsvpBottomSheet extends StatefulWidget {
  final CeremonyEvent event;
  const _RsvpBottomSheet({required this.event});

  @override
  State<_RsvpBottomSheet> createState() => _RsvpBottomSheetState();
}

class _RsvpBottomSheetState extends State<_RsvpBottomSheet> {
  String _status = 'attending';
  int _guestCount = 1;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    final result = await ApiService.post(
      ApiConfig.rsvp(widget.event.id),
      {
        'status': _status,
        'guest_count': _guestCount,
      },
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success'] == true ? '✅ RSVP submitted!' : '❌ Failed to submit RSVP',
          ),
          backgroundColor: result['success'] == true ? SanskarTheme.lotusGreen : SanskarTheme.vermillion,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'RSVP: ${widget.event.title}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          const Text('Will you attend?', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _rsvpChip('attending', '✅ Attending'),
              _rsvpChip('maybe', '🤔 Maybe'),
              _rsvpChip('not_attending', '❌ Cannot Attend'),
            ],
          ),
          const SizedBox(height: 20),
          if (_status == 'attending') ...[
            const Text('Number of guests', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _guestCount = (_guestCount - 1).clamp(1, 20)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_guestCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: () => setState(() => _guestCount = (_guestCount + 1).clamp(1, 20)),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit RSVP 🙏'),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
        ],
      ),
    );
  }

  Widget _rsvpChip(String value, String label) {
    final selected = _status == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: SanskarTheme.saffron.withAlpha(40),
      onSelected: (s) => setState(() => _status = value),
    );
  }
}
