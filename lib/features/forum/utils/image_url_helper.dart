import '../constants/forum_constants.dart';

class ImageUrlHelper {
  static String getImageUrl(String forumId, String imagePath, String? originalUrl) {
    if (originalUrl == null) return '';
    
    // Extract the timestamp from the URL if it exists
    final uri = Uri.parse(originalUrl);
    final timestamp = uri.queryParameters['v'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // Construct the path
    final path = '$forumId/$imagePath/$timestamp.jpg';
    
    return originalUrl.split('?')[0] + '?v=$timestamp';
  }

  static String getProfileImageUrl(String forumId, String? originalUrl) {
    return getImageUrl(forumId, ForumConstants.forumProfileImagePath, originalUrl);
  }

  static String getBannerImageUrl(String forumId, String? originalUrl) {
    return getImageUrl(forumId, ForumConstants.forumBannerImagePath, originalUrl);
  }
}
