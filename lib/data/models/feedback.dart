class Feedback {
  final String id;
  final String eventId;
  final String userId;
  final String? performerId;
  final int? rating;
  final String? comment;
  final bool isPublic;
  final DateTime createdAt;

  const Feedback({
    required this.id,
    required this.eventId,
    required this.userId,
    this.performerId,
    this.rating,
    this.comment,
    this.isPublic = false,
    required this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      performerId: json['performer_id'] as String?,
      rating: json['rating'] as int?,
      comment: json['comment'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'performer_id': performerId,
      'rating': rating,
      'comment': comment,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Feedback copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? performerId,
    int? rating,
    String? comment,
    bool? isPublic,
    DateTime? createdAt,
  }) {
    return Feedback(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      performerId: performerId ?? this.performerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
