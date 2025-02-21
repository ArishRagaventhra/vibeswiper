import 'dart:convert';
import '../utils/image_url_helper.dart';

class Forum {
  final String id;
  final String name;
  final String? description;
  final String? _profileImageUrl;
  final String? _bannerImageUrl;
  final bool isPrivate;
  final String? accessCode;
  final int memberCount;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final Map<String, dynamic> settings;

  Forum({
    required this.id,
    required this.name,
    this.description,
    String? profileImageUrl,
    String? bannerImageUrl,
    required this.isPrivate,
    this.accessCode,
    required this.memberCount,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.settings,
  }) : _profileImageUrl = profileImageUrl,
       _bannerImageUrl = bannerImageUrl;

  String? get profileImageUrl => _profileImageUrl != null && _profileImageUrl!.isNotEmpty 
      ? ImageUrlHelper.getProfileImageUrl(id, _profileImageUrl)
      : null;

  String? get bannerImageUrl => _bannerImageUrl != null && _bannerImageUrl!.isNotEmpty
      ? ImageUrlHelper.getBannerImageUrl(id, _bannerImageUrl)
      : null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'profile_image_url': _profileImageUrl,
      'banner_image_url': _bannerImageUrl,
      'is_private': isPrivate,
      'access_code': accessCode,
      'member_count': memberCount,
      'message_count': messageCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'settings': settings,
    };
  }

  factory Forum.fromJson(Map<String, dynamic> json) {
    try {
      return Forum(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        profileImageUrl: json['profile_image_url'] as String?,
        bannerImageUrl: json['banner_image_url'] as String?,
        isPrivate: json['is_private'] as bool? ?? false,
        accessCode: json['access_code'] as String?,
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        createdBy: json['created_by'] as String,
        settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      );
    } catch (e) {
      throw FormatException('Failed to parse Forum from JSON: $e\nJSON: $json');
    }
  }

  Forum copyWith({
    String? id,
    String? name,
    String? description,
    String? profileImageUrl,
    String? bannerImageUrl,
    bool? isPrivate,
    String? accessCode,
    int? memberCount,
    int? messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? settings,
  }) {
    return Forum(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      profileImageUrl: profileImageUrl ?? this._profileImageUrl,
      bannerImageUrl: bannerImageUrl ?? this._bannerImageUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      accessCode: accessCode ?? this.accessCode,
      memberCount: memberCount ?? this.memberCount,
      messageCount: messageCount ?? this.messageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      settings: settings ?? this.settings,
    );
  }
}
