import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Robust service managing profile picture picking, compression, persistent storage, and deletion.
class ProfileImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from either camera or gallery, compresses/resizes it,
  /// and saves it into the app's persistent documents directory.
  /// Returns the absolute path of the persistent image file, or null if cancelled/failed.
  static Future<String?> pickAndSaveImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        // User cancelled selection: preserve existing without error
        return null;
      }

      // Verify the temp file exists
      final tempFile = File(pickedFile.path);
      if (!await tempFile.exists()) {
        return null;
      }

      // Copy to application documents directory so it survives cache cleanup and restarts
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(appDir.path, 'profile_images'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final ext = p.extension(pickedFile.path).isNotEmpty
          ? p.extension(pickedFile.path)
          : '.jpg';
      final fileName = 'profile_avatar_${DateTime.now().millisecondsSinceEpoch}$ext';
      final persistentFile = File(p.join(targetDir.path, fileName));

      await tempFile.copy(persistentFile.path);

      return persistentFile.path;
    } catch (e) {
      debugPrint('Error picking/saving profile image: $e');
      return null;
    }
  }

  /// Removes an old profile image file from disk to avoid disk clutter.
  static Future<void> deleteImageFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting old profile image: $e');
    }
  }
}
