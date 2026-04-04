import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class _RsvpSummaryRow {
  final int eventId;
  final String eventTitle;
  final int attending;
  final int notAttending;
  final int maybe;
  final int pending;
  final int totalGuests;

  _RsvpSummaryRow({
    required this.eventId,
    required this.eventTitle,
    required this.attending,
    required this.notAttending,
    required this.maybe,
    required this.pending,
    required this.totalGuests,
  });

  factory _RsvpSummaryRow.fromJson(Map<String, dynamic> json) {
    return _RsvpSummaryRow(
      eventId: json['event_id'] ?? 0,
      eventTitle: json['event_title'] ?? '',
      attending: (json['attending'] is int) ? json['attending'] as int : int.tryParse('${json['attending']}') ?? 0,
      notAttending:
          (json['not_attending'] is int) ? json['not_attending'] as int : int.tryParse('${json['not_attending']}') ?? 0,
      maybe: (json['maybe'] is int) ? json['maybe'] as int : int.tryParse('${json['maybe']}') ?? 0,
      pending: (json['pending'] is int) ? json['pending'] as int : int.tryParse('${json['pending']}') ?? 0,
      totalGuests:
          (json['total_guests'] is int) ? json['total_guests'] as int : int.tryParse('${json['total_guests']}') ?? 0,
    );
  }
}

class AdminRsvpPanel extends StatefulWidget {
  const AdminRsvpPanel({super.key});

  @override
  State<AdminRsvpPanel> createState() => _AdminRsvpPanelState();
}

class _AdminRsvpPanelState extends State<AdminRsvpPanel> {
  List<_RsvpSummaryRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.get(ApiConfig.adminRsvpSummary);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true && result['data'] != null) {
        _rows = (result['data'] as List)
            .map((e) => _RsvpSummaryRow.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _rows = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: SanskarTheme.saffron));
    }

    if (_rows.isEmpty) {
      return Center(
        child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Load RSVP summary')),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: SanskarTheme.saffron,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(SanskarTheme.peach.withOpacity(0.35)),
            columns: const [
              DataColumn(label: Text('Event')),
              DataColumn(label: Text('Attending'), numeric: true),
              DataColumn(label: Text('Not'), numeric: true),
              DataColumn(label: Text('Maybe'), numeric: true),
              DataColumn(label: Text('Pending'), numeric: true),
              DataColumn(label: Text('Guests Σ'), numeric: true),
            ],
            rows: _rows
                .map(
                  (r) => DataRow(
                    cells: [
                      DataCell(SizedBox(width: 200, child: Text(r.eventTitle, maxLines: 2, overflow: TextOverflow.ellipsis))),
                      DataCell(Text('${r.attending}')),
                      DataCell(Text('${r.notAttending}')),
                      DataCell(Text('${r.maybe}')),
                      DataCell(Text('${r.pending}')),
                      DataCell(Text('${r.totalGuests}')),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
