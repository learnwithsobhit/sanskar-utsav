import 'package:flutter/foundation.dart';

/// API configuration for Sanskar Utsav.
///
/// In development, uses localhost:8080.
/// In production, reads from --dart-define=API_URL=https://your-railway-url.
class ApiConfig {
  // Production URL — set via: flutter build web --dart-define=API_URL=https://your-api.railway.app
  static const String _prodUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://sanskar-api-production.up.railway.app',
  );

  // Dev URL for local development
  static const String _devUrl = 'http://localhost:8080';

  // Auto-detect: use dev URL in debug mode, production URL otherwise
  static String get baseUrl => kDebugMode ? _devUrl : _prodUrl;
  static const String apiPrefix = '/api';

  static String get apiUrl => '$baseUrl$apiPrefix';

  // Endpoints
  static String get authLogin => '$apiUrl/auth/login';
  static String get authMe => '$apiUrl/auth/me';
  static String get authLogout => '$apiUrl/auth/logout';

  static String get events => '$apiUrl/events';
  static String eventsDay(int day) => '$apiUrl/events/day/$day';
  static String eventsToday() => '$apiUrl/events/today';
  static String eventDetail(int id) => '$apiUrl/events/$id';

  static String get guests => '$apiUrl/guests';
  static String guestDetail(String id) => '$apiUrl/guests/$id';
  static String get updateProfile => '$apiUrl/guests/profile';

  static String rsvp(int eventId) => '$apiUrl/rsvp/$eventId';
  static String get myRsvps => '$apiUrl/rsvp/my';
  static String get bulkRsvp => '$apiUrl/rsvp/bulk';

  static String get media => '$apiUrl/media';
  static String get mediaPresign => '$apiUrl/media/presign';
  static String mediaLike(int id) => '$apiUrl/media/$id/like';
  static String mediaComments(int id) => '$apiUrl/media/$id/comments';

  static String get announcements => '$apiUrl/announcements';
  static String get urgentAnnouncements => '$apiUrl/announcements/urgent';

  static String get notifications => '$apiUrl/notifications';
  static String notificationRead(int id) => '$apiUrl/notifications/$id/read';
  static String get notificationsReadAll => '$apiUrl/notifications/read-all';
  static String get fcmToken => '$apiUrl/notifications/fcm-token';

  static String get blessings => '$apiUrl/blessings';

  // Admin
  static String get adminGuests => '$apiUrl/admin/guests';
  static String adminGuestUpdate(String id) => '$apiUrl/admin/guests/$id';
  static String get adminEvents => '$apiUrl/admin/events';
  static String adminEventUpdate(int id) => '$apiUrl/admin/events/$id';
  static String get adminAnnouncements => '$apiUrl/admin/announcements';
  static String adminAnnouncementUpdate(int id) => '$apiUrl/admin/announcements/$id';
  static String get adminRsvpSummary => '$apiUrl/admin/rsvp-summary';
  static String get adminNotify => '$apiUrl/admin/notify';
  static String get adminPendingMedia => '$apiUrl/admin/media/pending';

  /// All media (default) or moderation queue only (`pendingOnly: true`).
  static String adminMediaList({int page = 1, int perPage = 100, bool pendingOnly = false}) {
    final p = pendingOnly ? 'true' : 'false';
    return '$apiUrl/admin/media?page=$page&per_page=$perPage&pending_only=$p';
  }

  static String adminMediaUpdate(int id) => '$apiUrl/admin/media/$id';

  static String get adminChatBroadcast => '$apiUrl/admin/chat/broadcast';
  static String get adminChatEventGroup => '$apiUrl/admin/chat/event-group';
  static String get adminChatEnrollAll => '$apiUrl/admin/chat/enroll-all';
}
