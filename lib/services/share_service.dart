import 'package:share_plus/share_plus.dart';
import '../features/profile/models/profile_model.dart';

class ShareService {
  void shareProfile(Profile profile) {
    final text = '''
Check out ${profile.username}'s profile on Scompass!
''';
    Share.share(text);
  }
}
