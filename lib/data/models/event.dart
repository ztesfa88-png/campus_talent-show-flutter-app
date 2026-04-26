enum EventStatus {
  upcoming('upcoming'),
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  const EventStatus(this.value);
  final String value;

  static EventStatus fromString(String value) {
    return EventStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => EventStatus.upcoming,
    );
  }
}

class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime eventDate;           // start date + time
  final DateTime? endDate;            // end date + time (optional)
  final DateTime? registrationDeadline;
  final DateTime? votingDeadline;     // when voting closes
  final DateTime? expiresAt;          // when the event expires / is archived
  final String? location;
  final int maxPerformers;
  final int votesPerUser;             // how many votes each student can cast
  final EventStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Event({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.endDate,
    this.registrationDeadline,
    this.votingDeadline,
    this.expiresAt,
    this.location,
    this.maxPerformers = 50,
    this.votesPerUser = 1,
    this.status = EventStatus.upcoming,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.tryParse(json['registration_deadline'] as String)
          : null,
      votingDeadline: json['voting_deadline'] != null
          ? DateTime.tryParse(json['voting_deadline'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      location: json['location'] as String?,
      maxPerformers: json['max_performers'] as int? ?? 50,
      votesPerUser: json['votes_per_user'] as int? ?? 1,
      status: EventStatus.fromString(json['status'] as String? ?? 'upcoming'),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'registration_deadline': registrationDeadline?.toIso8601String(),
      'voting_deadline': votingDeadline?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'location': location,
      'max_performers': maxPerformers,
      'votes_per_user': votesPerUser,
      'status': status.value,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? eventDate,
    DateTime? endDate,
    DateTime? registrationDeadline,
    DateTime? votingDeadline,
    DateTime? expiresAt,
    String? location,
    int? maxPerformers,
    int? votesPerUser,
    EventStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      endDate: endDate ?? this.endDate,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      votingDeadline: votingDeadline ?? this.votingDeadline,
      expiresAt: expiresAt ?? this.expiresAt,
      location: location ?? this.location,
      maxPerformers: maxPerformers ?? this.maxPerformers,
      votesPerUser: votesPerUser ?? this.votesPerUser,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helpers
  bool get isRegistrationOpen {
    if (registrationDeadline == null) return true;
    return DateTime.now().isBefore(registrationDeadline!);
  }

  bool get isVotingOpen {
    if (votingDeadline == null) return status == EventStatus.active;
    return status == EventStatus.active && DateTime.now().isBefore(votingDeadline!);
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isUpcoming   => status == EventStatus.upcoming;
  bool get isActive     => status == EventStatus.active;
  bool get isCompleted  => status == EventStatus.completed;
  bool get isCancelled  => status == EventStatus.cancelled;

  /// Formatted start: "Mon, 21 Apr 2026 · 10:00 AM"
  String get formattedStart {
    return _fmt(eventDate);
  }

  /// Formatted end: "Mon, 21 Apr 2026 · 06:00 PM" or null
  String? get formattedEnd {
    if (endDate == null) return null;
    return _fmt(endDate!);
  }

  /// Formatted voting deadline
  String? get formattedVotingDeadline {
    if (votingDeadline == null) return null;
    return _fmt(votingDeadline!);
  }

  /// Formatted expiry
  String? get formattedExpiresAt {
    if (expiresAt == null) return null;
    return _fmt(expiresAt!);
  }

  /// Formatted registration deadline
  String? get formattedRegistrationDeadline {
    if (registrationDeadline == null) return null;
    return _fmt(registrationDeadline!);
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  String _fmt(DateTime dt) {
    final day  = _days[dt.weekday - 1];
    final mon  = _months[dt.month - 1];
    final h    = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min  = dt.minute.toString().padLeft(2, '0');
    return '$day, ${dt.day} $mon ${dt.year} · $h:$min $ampm';
  }
}
