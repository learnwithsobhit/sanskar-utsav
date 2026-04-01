class MediaItem {
  final int id;
  final String? uploadedBy;
  final String? uploaderName;
  final int? eventId;
  final String? eventTitle;
  final String mediaType;
  final String title;
  final String description;
  final String fileUrl;
  final String thumbnailUrl;
  final int fileSizeBytes;
  final int durationSecs;
  final String mimeType;
  final bool isApproved;
  final bool isFeatured;
  final int likeCount;
  final int viewCount;
  final String createdAt;

  MediaItem({
    required this.id,
    this.uploadedBy,
    this.uploaderName,
    this.eventId,
    this.eventTitle,
    required this.mediaType,
    this.title = '',
    this.description = '',
    required this.fileUrl,
    this.thumbnailUrl = '',
    this.fileSizeBytes = 0,
    this.durationSecs = 0,
    this.mimeType = '',
    this.isApproved = true,
    this.isFeatured = false,
    this.likeCount = 0,
    this.viewCount = 0,
    this.createdAt = '',
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] ?? 0,
      uploadedBy: json['uploaded_by'],
      uploaderName: json['uploader_name'],
      eventId: json['event_id'],
      eventTitle: json['event_title'],
      mediaType: json['media_type'] ?? 'photo',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      fileUrl: json['file_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      durationSecs: json['duration_secs'] ?? 0,
      mimeType: json['mime_type'] ?? '',
      isApproved: json['is_approved'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      likeCount: json['like_count'] ?? 0,
      viewCount: json['view_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isPhoto => mediaType == 'photo';
  bool get isVideo => mediaType == 'video';
  bool get isAudio => mediaType == 'audio';

  String get uploaderDisplayName => uploaderName ?? 'Unknown';

  String get timeAgo {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'now';
    } catch (_) {
      return '';
    }
  }

  MediaItem copyWith({int? likeCount}) {
    return MediaItem(
      id: id,
      uploadedBy: uploadedBy,
      uploaderName: uploaderName,
      eventId: eventId,
      eventTitle: eventTitle,
      mediaType: mediaType,
      title: title,
      description: description,
      fileUrl: fileUrl,
      thumbnailUrl: thumbnailUrl,
      fileSizeBytes: fileSizeBytes,
      durationSecs: durationSecs,
      mimeType: mimeType,
      isApproved: isApproved,
      isFeatured: isFeatured,
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount,
      createdAt: createdAt,
    );
  }
}

class MediaComment {
  final int id;
  final int mediaId;
  final String? guestId;
  final String guestName;
  final String comment;
  final String createdAt;

  MediaComment({
    required this.id,
    required this.mediaId,
    this.guestId,
    required this.guestName,
    required this.comment,
    this.createdAt = '',
  });

  factory MediaComment.fromJson(Map<String, dynamic> json) {
    return MediaComment(
      id: json['id'] ?? 0,
      mediaId: json['media_id'] ?? 0,
      guestId: json['guest_id'],
      guestName: json['guest_name'] ?? '',
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
