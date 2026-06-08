import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'download_service.dart';

class MobileDownloadService implements DownloadService {
  @override
  Future<void> downloadFile(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Share or save the file
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }
}