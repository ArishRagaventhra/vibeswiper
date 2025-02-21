import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/event_controller.dart';
import '../repositories/event_repository.dart';
import 'media_utils.dart';
import '../../../config/supabase_config.dart';

class MediaUploadTest {
  static Future<void> testMediaUpload(XFile file) async {
    try {
      debugPrint('=== Starting Media Upload Test ===');
      debugPrint('File path: ${file.path}');
      debugPrint('File size: ${await file.length()} bytes');

      // Step 1: Process the media file
      debugPrint('\n1. Testing Media Processing...');
      final processedMedia = await MediaUtils.processMediaFile(file);
      debugPrint('✓ Media processed successfully');
      debugPrint('MIME Type: ${processedMedia.mimeType}');
      debugPrint('Media Type: ${processedMedia.mediaType}');

      // Step 2: Test content type creation
      debugPrint('\n2. Testing Content Type Creation...');
      final contentType = MediaUtils.getMediaContentType(processedMedia.mimeType);
      debugPrint('✓ Content type created successfully: ${contentType.toString()}');

      // Step 3: Test storage bucket access
      debugPrint('\n3. Testing Storage Bucket Access...');
      final bucket = SupabaseConfig.client.storage.from('event-media');
      debugPrint('✓ Storage bucket accessed successfully');

      // Step 4: Test file upload
      debugPrint('\n4. Testing File Upload...');
      final eventId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final repository = EventRepository(supabase: SupabaseConfig.client);
      final controller = EventController(repository: repository);
      
      final url = await controller.uploadEventMedia(
        processedMedia.file,
        eventId,
        processedMedia.mimeType,
      );

      if (url != null) {
        debugPrint('✓ File uploaded successfully');
        debugPrint('Public URL: $url');
      } else {
        throw Exception('Upload failed - no URL returned');
      }

      debugPrint('\n=== Media Upload Test Completed Successfully ===');
    } catch (e, stackTrace) {
      debugPrint('\n❌ Test Failed:');
      debugPrint('Error: $e');
      debugPrint('Stack trace:\n$stackTrace');
    }
  }
}
