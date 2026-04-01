class Announcement {
  final int id;
  final String title;
  final String message;
  final String category;
  final int priority;
  final bool isActive;
  final int? targetDay;
  final String createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.category = 'general',
    this.priority = 0,
    this.isActive = true,
    this.targetDay,
    this.createdAt = '',
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 0,
      isActive: json['is_active'] ?? true,
      targetDay: json['target_day'],
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isUrgent => priority >= 2;
  bool get isImportant => priority >= 1;
}

class AppNotification {
  final int id;
  final String guestId;
  final String title;
  final String body;
  final String notificationType;
  final String referenceType;
  final int referenceId;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.guestId,
    required this.title,
    required this.body,
    this.notificationType = '',
    this.referenceType = '',
    this.referenceId = 0,
    this.isRead = false,
    this.createdAt = '',
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      guestId: json['guest_id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      notificationType: json['notification_type'] ?? '',
      referenceType: json['reference_type'] ?? '',
      referenceId: json['reference_id'] ?? 0,
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class Blessing {
  final int id;
  final String? guestId;
  final String guestName;
  final String message;
  final String audioUrl;
  final bool isFeatured;
  final String createdAt;

  Blessing({
    required this.id,
    this.guestId,
    required this.guestName,
    required this.message,
    this.audioUrl = '',
    this.isFeatured = false,
    this.createdAt = '',
  });

  factory Blessing.fromJson(Map<String, dynamic> json) {
    return Blessing(
      id: json['id'] ?? 0,
      guestId: json['guest_id'],
      guestName: json['guest_name'] ?? '',
      message: json['message'] ?? '',
      audioUrl: json['audio_url'] ?? '',
      isFeatured: json['is_featured'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}
