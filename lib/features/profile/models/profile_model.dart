class Profile {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final String? website;
  final String? email;
  final bool isVerified;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.website,
    this.email,
    this.isVerified = false,
    this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
  });

  Profile copyWith({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? bio,
    String? website,
    String? email,
  }) {
    return Profile(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      email: email ?? this.email,
      isVerified: isVerified,
      lastSeen: lastSeen,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      lastSeen: json['last_seen'] != null 
        ? DateTime.parse(json['last_seen'] as String)
        : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'website': website,
      'email': email,
      'is_verified': isVerified,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
