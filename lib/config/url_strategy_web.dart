// Web-specific implementation for URL strategy
// This file will only be imported on web platforms

import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void setUrlStrategy() {
  // Set URL strategy to path-based (no hash)
  usePathUrlStrategy();
}
