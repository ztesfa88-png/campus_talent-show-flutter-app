enum RegistrationStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const RegistrationStatus(this.value);
  final String value;

  static RegistrationStatus fromString(String value) {
    return RegistrationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => RegistrationStatus.pending,
    );
  }
}

class EventRegistration {
  final String id;
  final String eventId;
  final String performerId;
  final String performanceTitle;
  final String? performanceDescription;
  final int durationMinutes;
  final RegistrationStatus status;
  final DateTime submissionDate;

  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.performerId,
    required this.performanceTitle,
    this.performanceDescription,
    this.durationMinutes = 5,
    this.status = RegistrationStatus.pending,
    required this.submissionDate,
  });

  factory EventRegistration.fromJson(Map<String, dynamic> json) {
    return EventRegistration(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      performerId: json['performer_id'] as String,
      performanceTitle: json['performance_title'] as String,
      performanceDescription: json['performance_description'] as String?,
      durationMinutes: json['duration_minutes'] as int? ?? 5,
      status: RegistrationStatus.fromString(json['status'] as String? ?? 'pending'),
      submissionDate: DateTime.parse(json['submission_date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'performer_id': performerId,
      'performance_title': performanceTitle,
      'performance_description': performanceDescription,
      'duration_minutes': durationMinutes,
      'status': status.value,
      'submission_date': submissionDate.toIso8601String(),
    };
  }

  EventRegistration copyWith({
    String? id,
    String? eventId,
    String? performerId,
    String? performanceTitle,
    String? performanceDescription,
    int? durationMinutes,
    RegistrationStatus? status,
    DateTime? submissionDate,
  }) {
    return EventRegistration(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      performerId: performerId ?? this.performerId,
      performanceTitle: performanceTitle ?? this.performanceTitle,
      performanceDescription: performanceDescription ?? this.performanceDescription,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      submissionDate: submissionDate ?? this.submissionDate,
    );
  }

  bool get isPending => status == RegistrationStatus.pending;
  bool get isApproved => status == RegistrationStatus.approved;
  bool get isRejected => status == RegistrationStatus.rejected;
}
