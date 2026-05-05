import 'user.dart';

enum TalentType {
  music('music'),
  dance('dance'),
  comedy('comedy'),
  drama('drama'),
  magic('magic'),
  other('other');

  const TalentType(this.value);
  final String value;

  static TalentType fromString(String value) {
    return TalentType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TalentType.other,
    );
  }
}

enum ExperienceLevel {
  beginner('beginner'),
  intermediate('intermediate'),
  advanced('advanced');

  const ExperienceLevel(this.value);
  final String value;

  static ExperienceLevel fromString(String value) {
    return ExperienceLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () => ExperienceLevel.beginner,
    );
  }
}

class Performer {
  final String id;
  final String email;
  final String? name;
  final UserRole role;
  final String? bio;
  final String? avatarUrl;
  final TalentType talentType;
  final ExperienceLevel experienceLevel;
  final Map<String, dynamic> socialLinks;
  final DateTime createdAt;
  final DateTime? updatedAt;
  // Transient — populated by the provider from the votes table
  final double averageScore;
  final int voteCount;

  const Performer({
    required this.id,
    required this.email,
    this.name,
    required this.role,
    this.bio,
    this.avatarUrl,
    required this.talentType,
    this.experienceLevel = ExperienceLevel.beginner,
    this.socialLinks = const {},
    required this.createdAt,
    this.updatedAt,
    this.averageScore = 0.0,
    this.voteCount = 0,
  });

  factory Performer.fromJson(Map<String, dynamic> json) {
    return Performer(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'performer'),
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      talentType: TalentType.fromString(json['talent_type'] as String? ?? 'other'),
      experienceLevel: ExperienceLevel.fromString(json['experience_level'] as String? ?? 'beginner'),
      socialLinks: Map<String, dynamic>.from(json['social_links'] ?? {}),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.value,
      'bio': bio,
      'avatar_url': avatarUrl,
      'talent_type': talentType.value,
      'experience_level': experienceLevel.value,
      'social_links': socialLinks,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'average_score': averageScore,
      'vote_count': voteCount,
    };
  }

  Performer copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? bio,
    String? avatarUrl,
    TalentType? talentType,
    ExperienceLevel? experienceLevel,
    Map<String, dynamic>? socialLinks,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? averageScore,
    int? voteCount,
  }) {
    return Performer(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      talentType: talentType ?? this.talentType,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      socialLinks: socialLinks ?? this.socialLinks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      averageScore: averageScore ?? this.averageScore,
      voteCount: voteCount ?? this.voteCount,
    );
  }
}
