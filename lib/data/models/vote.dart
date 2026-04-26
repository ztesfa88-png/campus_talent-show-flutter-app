class Vote {
  final String id;
  final String eventId;
  final String userId;
  final String performerId;
  final int score;
  final DateTime votedAt;

  const Vote({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.performerId,
    required this.score,
    required this.votedAt,
  });

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      performerId: json['performer_id'] as String,
      score: json['score'] as int,
      votedAt: DateTime.parse(json['voted_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'performer_id': performerId,
      'score': score,
      'voted_at': votedAt.toIso8601String(),
    };
  }

  Vote copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? performerId,
    int? score,
    DateTime? votedAt,
  }) {
    return Vote(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      performerId: performerId ?? this.performerId,
      score: score ?? this.score,
      votedAt: votedAt ?? this.votedAt,
    );
  }
}
