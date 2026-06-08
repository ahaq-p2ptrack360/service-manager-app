import 'download_service.dart';
import 'download_service_web.dart';

// This will automatically choose the right implementation
// For Flutter web
export 'download_service_web.dart'
if (dart.library.html) 'download_service_web.dart'
// For mobile/desktop
if (dart.library.io) 'download_service_mobile.dart';

// You can also use this approach:
DownloadService getDownloadService() {
  // Detect platform and return appropriate service
  // This is a simplified version
  return WebDownloadService(); // or MobileDownloadService()
}