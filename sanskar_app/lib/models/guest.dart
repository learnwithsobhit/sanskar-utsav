class Guest {
  final String id;
  final String inviteCode;
  final String name;
  final String phone;
  final String email;
  final String relation;
  final String familySide;
  final int guestCount;
  final String avatarUrl;
  final bool isAdmin;
  final String status;
  final String rsvpMessage;
  final String dietaryPref;
  final String city;
  final bool accommodationNeeded;
  final String createdAt;
  final String updatedAt;

  Guest({
    required this.id,
    required this.inviteCode,
    required this.name,
    this.phone = '',
    this.email = '',
    this.relation = '',
    this.familySide = 'both',
    this.guestCount = 1,
    this.avatarUrl = '',
    this.isAdmin = false,
    this.status = 'invited',
    this.rsvpMessage = '',
    this.dietaryPref = 'veg',
    this.city = '',
    this.accommodationNeeded = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory Guest.fromJson(Map<String, dynamic> json) {
    return Guest(
      id: json['id'] ?? '',
      inviteCode: json['invite_code'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      relation: json['relation'] ?? '',
      familySide: json['family_side'] ?? 'both',
      guestCount: json['guest_count'] ?? 1,
      avatarUrl: json['avatar_url'] ?? '',
      isAdmin: json['is_admin'] ?? false,
      status: json['status'] ?? 'invited',
      rsvpMessage: json['rsvp_message'] ?? '',
      dietaryPref: json['dietary_pref'] ?? 'veg',
      city: json['city'] ?? '',
      accommodationNeeded: json['accommodation_needed'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get familySideLabel {
    switch (familySide) {
      case 'paternal':
        return 'Paternal Side';
      case 'maternal':
        return 'Maternal Side';
      default:
        return '';
    }
  }
}
