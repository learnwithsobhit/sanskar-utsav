/// API configuration for Sanskar Utsav.
class ApiConfig {
  // Change this to your deployed backend URL
  static const String baseUrl = 'http://localhost:8080';
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
  static String adminMediaUpdate(int id) => '$apiUrl/admin/media/$id';
}
