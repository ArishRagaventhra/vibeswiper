// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_media.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatMedia _$ChatMediaFromJson(Map<String, dynamic> json) {
  return _ChatMedia.fromJson(json);
}

/// @nodoc
mixin _$ChatMedia {
  String get url => throw _privateConstructorUsedError;
  MediaType get type => throw _privateConstructorUsedError;
  String? get thumbnailUrl => throw _privateConstructorUsedError;
  String? get fileName => throw _privateConstructorUsedError;
  String? get mimeType => throw _privateConstructorUsedError;

  /// Serializes this ChatMedia to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatMedia
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatMediaCopyWith<ChatMedia> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMediaCopyWith<$Res> {
  factory $ChatMediaCopyWith(ChatMedia value, $Res Function(ChatMedia) then) =
      _$ChatMediaCopyWithImpl<$Res, ChatMedia>;
  @useResult
  $Res call(
      {String url,
      MediaType type,
      String? thumbnailUrl,
      String? fileName,
      String? mimeType});
}

/// @nodoc
class _$ChatMediaCopyWithImpl<$Res, $Val extends ChatMedia>
    implements $ChatMediaCopyWith<$Res> {
  _$ChatMediaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatMedia
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? type = null,
    Object? thumbnailUrl = freezed,
    Object? fileName = freezed,
    Object? mimeType = freezed,
  }) {
    return _then(_value.copyWith(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MediaType,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      fileName: freezed == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String?,
      mimeType: freezed == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatMediaImplCopyWith<$Res>
    implements $ChatMediaCopyWith<$Res> {
  factory _$$ChatMediaImplCopyWith(
          _$ChatMediaImpl value, $Res Function(_$ChatMediaImpl) then) =
      __$$ChatMediaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String url,
      MediaType type,
      String? thumbnailUrl,
      String? fileName,
      String? mimeType});
}

/// @nodoc
class __$$ChatMediaImplCopyWithImpl<$Res>
    extends _$ChatMediaCopyWithImpl<$Res, _$ChatMediaImpl>
    implements _$$ChatMediaImplCopyWith<$Res> {
  __$$ChatMediaImplCopyWithImpl(
      _$ChatMediaImpl _value, $Res Function(_$ChatMediaImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatMedia
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? type = null,
    Object? thumbnailUrl = freezed,
    Object? fileName = freezed,
    Object? mimeType = freezed,
  }) {
    return _then(_$ChatMediaImpl(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MediaType,
      thumbnailUrl: freezed == thumbnailUrl
          ? _value.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      fileName: freezed == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String?,
      mimeType: freezed == mimeType
          ? _value.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMediaImpl extends _ChatMedia {
  const _$ChatMediaImpl(
      {required this.url,
      required this.type,
      this.thumbnailUrl,
      this.fileName,
      this.mimeType})
      : super._();

  factory _$ChatMediaImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMediaImplFromJson(json);

  @override
  final String url;
  @override
  final MediaType type;
  @override
  final String? thumbnailUrl;
  @override
  final String? fileName;
  @override
  final String? mimeType;

  @override
  String toString() {
    return 'ChatMedia(url: $url, type: $type, thumbnailUrl: $thumbnailUrl, fileName: $fileName, mimeType: $mimeType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMediaImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, url, type, thumbnailUrl, fileName, mimeType);

  /// Create a copy of ChatMedia
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMediaImplCopyWith<_$ChatMediaImpl> get copyWith =>
      __$$ChatMediaImplCopyWithImpl<_$ChatMediaImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMediaImplToJson(
      this,
    );
  }
}

abstract class _ChatMedia extends ChatMedia {
  const factory _ChatMedia(
      {required final String url,
      required final MediaType type,
      final String? thumbnailUrl,
      final String? fileName,
      final String? mimeType}) = _$ChatMediaImpl;
  const _ChatMedia._() : super._();

  factory _ChatMedia.fromJson(Map<String, dynamic> json) =
      _$ChatMediaImpl.fromJson;

  @override
  String get url;
  @override
  MediaType get type;
  @override
  String? get thumbnailUrl;
  @override
  String? get fileName;
  @override
  String? get mimeType;

  /// Create a copy of ChatMedia
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatMediaImplCopyWith<_$ChatMediaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
