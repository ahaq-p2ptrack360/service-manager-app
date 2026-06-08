import 'dart:html' as html;
import 'download_service.dart';

class WebDownloadService implements DownloadService {
  @override
  Future<void> downloadFile(String url, String fileName) async {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }
}