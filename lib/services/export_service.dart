import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

import 'export_stub.dart' if (dart.library.html) 'export_web.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Saves the rendered collage image as a file.
  /// Returns the saved file path on success, or message on Web.
  Future<String?> downloadCollage({
    required Uint8List bytes,
    required String format, // 'png' or 'jpeg'
  }) async {
    final filename = 'media_mate_${DateTime.now().millisecondsSinceEpoch}.$format';

    if (kIsWeb) {
      try {
        downloadBytesWeb(bytes, filename);
        return 'Downloaded $filename successfully';
      } catch (e) {
        debugPrint('Web download error: $e');
        return null;
      }
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Request gallery access with album permission
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          final granted = await Gal.requestAccess(toAlbum: true);
          if (!granted) {
            debugPrint('Gallery access permission denied');
            return null;
          }
        }

        // Save to temporary directory first
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$filename');
        await tempFile.writeAsBytes(bytes);

        // Save to the system gallery album "Media Mate"
        await Gal.putImage(tempFile.path, album: 'Media Mate');
        return 'Downloaded to Gallery (Media Mate album)';
      }

      Directory? baseDir;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        baseDir = await getDownloadsDirectory();
      }
      
      baseDir ??= await getApplicationDocumentsDirectory();

      // Create "Media Mate/Collages" subfolder
      final collageStudioDir = Directory('${baseDir.path}/Media Mate/Collages');
      if (!await collageStudioDir.exists()) {
        await collageStudioDir.create(recursive: true);
      }

      final filePath = '${collageStudioDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      debugPrint('Native download error: $e');
      return null;
    }
  }

  /// Shares the collage image using the native share sheet.
  Future<bool> shareCollage({
    required Uint8List bytes,
    required String format,
  }) async {
    final filename = 'media_mate_share_${DateTime.now().millisecondsSinceEpoch}.$format';

    try {
      if (kIsWeb) {
        // Web sharing fallback (since native shares are limited on some browsers)
        // We trigger download first, then show instructions
        downloadBytesWeb(bytes, filename);
        return true;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      final xFile = XFile(filePath, mimeType: format == 'png' ? 'image/png' : 'image/jpeg');
      final result = await Share.shareXFiles([xFile], text: 'Created with Collage Studio');
      
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Share collage error: $e');
      return false;
    }
  }
}
