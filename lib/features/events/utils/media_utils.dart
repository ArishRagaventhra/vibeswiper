import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';

class MediaValidationException implements Exception {
  final String message;
  MediaValidationException(this.message);
  @override
  String toString() => message;
}

class MediaUtils {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['image/jpeg', 'image/png', 'image/gif'];
  static const List<String> allowedVideoTypes = ['video/mp4', 'video/quicktime'];
  
  // Compression settings
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;
  static const int defaultQuality = 85;
  static const int smallImageQuality = 70;
  static const int smallImageThreshold = 1024 * 1024; // 1MB

  // Cache settings
  static const Duration cacheExpiry = Duration(hours: 1);
  static final Map<String, _CachedMedia> _processedMediaCache = {};

  // Cache management methods
  static ProcessedMedia? _getCachedMedia(String filePath) {
    final cached = _processedMediaCache[filePath];
    if (cached != null) {
      if (cached.isExpired) {
        _processedMediaCache.remove(filePath);
        return null;
      }
      return cached.processedMedia;
    }
    return null;
  }

  static void _cacheProcessedMedia(String filePath, ProcessedMedia media) {
    _processedMediaCache[filePath] = _CachedMedia(media);
    
    // Clean up expired cache entries periodically
    if (_processedMediaCache.length > 100) {
      _processedMediaCache.removeWhere((_, cached) => cached.isExpired);
    }
  }

  /// Validates and processes a media file
  static Future<ProcessedMedia> processMediaFile(XFile file, {
    int? quality,
    int? maxWidth,
    int? maxHeight,
    bool useCache = true,
  }) async {
    try {
      debugPrint('Processing file: ${file.path}');
      
      // Check cache first
      if (useCache) {
        final cached = _getCachedMedia(file.path);
        if (cached != null) {
          debugPrint('Using cached processed media');
          return cached;
        }
      }

      // Get file size
      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        throw MediaValidationException(
          'File size exceeds maximum limit of ${maxFileSizeBytes ~/ (1024 * 1024)}MB',
        );
      }

      // Determine compression quality based on file size
      quality ??= fileSize > smallImageThreshold ? defaultQuality : smallImageQuality;
      
      // Get file extension and try to determine MIME type
      final extension = path.extension(file.path).toLowerCase().replaceAll('.', '');
      debugPrint('File extension: $extension');
      
      // First try to get MIME type from extension
      String? mimeType = _extensionMimeTypes[extension];
      
      // If not found by extension, try lookupMimeType
      if (mimeType == null) {
        mimeType = lookupMimeType(file.path);
        debugPrint('MIME type from lookup: $mimeType');
        
        // If still null, try to read first few bytes
        if (mimeType == null) {
          final bytes = await file.readAsBytes();
          mimeType = lookupMimeType(file.path, headerBytes: bytes);
          debugPrint('MIME type from header bytes: $mimeType');
        }
      }

      // If still no MIME type but we have a known extension, use default MIME type
      if (mimeType == null && _extensionMimeTypes.containsKey(extension)) {
        mimeType = _extensionMimeTypes[extension];
        debugPrint('Using default MIME type for extension: $mimeType');
      }

      debugPrint('Final MIME type: $mimeType');

      // Final check for MIME type
      if (mimeType == null) {
        throw MediaValidationException('Unable to determine file type');
      }

      // Validate file type
      if (!allowedImageTypes.contains(mimeType) && !allowedVideoTypes.contains(mimeType)) {
        throw MediaValidationException('Unsupported file type: $mimeType');
      }

      // Process image if it's an image file
      if (allowedImageTypes.contains(mimeType)) {
        final processedFile = await _processImage(file, quality: quality, maxWidth: maxWidth, maxHeight: maxHeight);
        final media = ProcessedMedia(
          file: processedFile,
          mimeType: mimeType,
          mediaType: MediaType.image,
        );
        _cacheProcessedMedia(file.path, media);
        return media;
      }

      // For video, just validate and return
      if (allowedVideoTypes.contains(mimeType)) {
        final media = ProcessedMedia(
          file: file,
          mimeType: mimeType,
          mediaType: MediaType.video,
        );
        _cacheProcessedMedia(file.path, media);
        return media;
      }

      throw MediaValidationException('Unexpected error processing media');
    } catch (e) {
      debugPrint('Error in processMediaFile: $e');
      if (e is MediaValidationException) rethrow;
      throw MediaValidationException('Error processing media: $e');
    }
  }

  /// Processes an image file - compresses and optimizes it
  static Future<XFile> _processImage(XFile file, {
    int? quality,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      debugPrint('Processing image: ${file.path}');
      final bytes = await file.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final extension = path.extension(file.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(tempDir.path, 'compressed_$timestamp$extension');

      // Get image dimensions using Flutter's decodeImageFromList
      final decodedImage = await compute(decodeImageFromList, bytes);
      final imageWidth = decodedImage.width;
      final imageHeight = decodedImage.height;

      // Calculate target dimensions while maintaining aspect ratio
      final aspectRatio = imageWidth / imageHeight;
      int targetWidth = maxWidth ?? maxImageWidth;
      int targetHeight = maxHeight ?? maxImageHeight;

      if (aspectRatio > 1) {
        targetHeight = (targetWidth / aspectRatio).round();
      } else {
        targetWidth = (targetHeight * aspectRatio).round();
      }

      // Only compress if the image is larger than target dimensions
      if (imageWidth <= targetWidth && imageHeight <= targetHeight && quality == defaultQuality) {
        debugPrint('Image already optimized, skipping compression');
        return file;
      }

      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: targetHeight,
        minWidth: targetWidth,
        quality: quality ?? defaultQuality,
      );

      // Write compressed image to temporary file
      final compressedFile = File(outputPath);
      await compressedFile.writeAsBytes(compressedBytes);
      debugPrint('Image compressed successfully: $outputPath');

      return XFile(compressedFile.path);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      // If compression fails, return original file
      return file;
    }
  }

  /// Gets the content type for Supabase upload
  static ContentType getMediaContentType(String mimeType) {
    try {
      final parts = mimeType.split('/');
      if (parts.length != 2) {
        throw MediaValidationException('Invalid MIME type format: $mimeType');
      }
      return ContentType(parts[0], parts[1]);
    } catch (e) {
      debugPrint('Error creating ContentType: $e');
      throw MediaValidationException('Invalid MIME type: $mimeType');
    }
  }

  static const Map<String, String> _extensionMimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
  };
}

// Cache management class
class _CachedMedia {
  final ProcessedMedia processedMedia;
  final DateTime timestamp;

  _CachedMedia(this.processedMedia) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > MediaUtils.cacheExpiry;
}

enum MediaType {
  image,
  video;
  
  String get mimePrefix {
    switch (this) {
      case MediaType.image:
        return 'image';
      case MediaType.video:
        return 'video';
    }
  }
}

class ProcessedMedia {
  final XFile file;
  final String mimeType;
  final MediaType mediaType;

  ProcessedMedia({
    required this.file,
    required this.mimeType,
    required this.mediaType,
  });
}
