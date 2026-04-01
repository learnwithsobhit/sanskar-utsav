class CeremonyEvent {
  final int id;
  final int dayNumber;
  final String title;
  final String hindiTitle;
  final String description;
  final String eventDate;
  final String? startTime;
  final String? endTime;
  final String venue;
  final String venueMapUrl;
  final String dressCode;
  final String category;
  final String bannerUrl;
  final String iconEmoji;
  final int sortOrder;
  final bool isActive;

  CeremonyEvent({
    required this.id,
    required this.dayNumber,
    required this.title,
    this.hindiTitle = '',
    this.description = '',
    required this.eventDate,
    this.startTime,
    this.endTime,
    this.venue = '',
    this.venueMapUrl = '',
    this.dressCode = '',
    this.category = 'ritual',
    this.bannerUrl = '',
    this.iconEmoji = '🕉️',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CeremonyEvent.fromJson(Map<String, dynamic> json) {
    return CeremonyEvent(
      id: json['id'] ?? 0,
      dayNumber: json['day_number'] ?? 1,
      title: json['title'] ?? '',
      hindiTitle: json['hindi_title'] ?? '',
      description: json['description'] ?? '',
      eventDate: json['event_date'] ?? '',
      startTime: json['start_time'],
      endTime: json['end_time'],
      venue: json['venue'] ?? '',
      venueMapUrl: json['venue_map_url'] ?? '',
      dressCode: json['dress_code'] ?? '',
      category: json['category'] ?? 'ritual',
      bannerUrl: json['banner_url'] ?? '',
      iconEmoji: json['icon_emoji'] ?? '🕉️',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  String get timeRange {
    if (startTime == null) return '';
    final start = _formatTime(startTime!);
    if (endTime == null) return start;
    return '$start – ${_formatTime(endTime!)}';
  }

  String _formatTime(String time) {
    // Convert "HH:MM:SS" to "HH:MM AM/PM"
    final parts = time.split(':');
    if (parts.length < 2) return time;
    int hour = int.tryParse(parts[0]) ?? 0;
    final min = parts[1];
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '$hour:$min $ampm';
  }

  String get categoryLabel {
    switch (category) {
      case 'ritual':
        return 'Sacred Ritual';
      case 'feast':
        return 'Feast';
      case 'celebration':
        return 'Celebration';
      default:
        return category;
    }
  }
}
