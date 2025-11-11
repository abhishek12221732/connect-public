import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:saver_gallery/saver_gallery.dart';

class LocalStorageHelper {

  static Future<bool> saveImageToGallery(File imageFile) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final result = await SaverGallery.saveImage(
        bytes,
        fileName: 'memory_${DateTime.now().millisecondsSinceEpoch}.jpg', // Give it a unique name
        skipIfExists: false, // Overwrite if a file with the same name exists
      );
      debugPrint("Image saved to gallery: ${result.isSuccess}");
      return result.isSuccess;
    } catch (e) {
      debugPrint("Error saving image to gallery: $e");
      return false;
    }
  }


  static Future<File?> getLocalImage(String imageId) async {
    try {
      // Web platform doesn't support path_provider
      if (kIsWeb) {
        print("📱 LocalStorageHelper: Web platform detected, skipping local storage check");
        return null;
      }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/$imageId.jpg";
    final file = File(filePath);

    if (await file.exists()) {
      return file; // Return the local file if it exists
    }
    return null; // Return null if the file is not found locally
    } catch (e) {
      print("❌ LocalStorageHelper: Error getting local image: $e");
      return null;
    }
  }

  static Future<File?> downloadAndSaveImage(String imageId) async {
    try {
      print("📥 LocalStorageHelper: Starting download for imageId: $imageId");
      
      // Web platform doesn't support local file storage
      if (kIsWeb) {
        print("📥 LocalStorageHelper: Web platform detected, skipping download");
        return null;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/$imageId.jpg";
      final file = File(filePath);

      final imageUrl = "https://drive.google.com/uc?export=view&id=$imageId";
      print("📥 LocalStorageHelper: Downloading from URL: $imageUrl");
      Response response = await Dio().download(imageUrl, filePath);

      if (response.statusCode == 200) {
        print("📥 LocalStorageHelper: Successfully downloaded image to: $filePath");
        return file;
      } else {
        print("📥 LocalStorageHelper: Download failed with status code: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ LocalStorageHelper: Error downloading image $imageId: $e");
      return null;
    }
  }
  
   static Future<void> saveImageLocally(File imageFile, String imageId) async {
    try {
      // Web platform doesn't support local file storage
      if (kIsWeb) {
        print("📱 LocalStorageHelper: Web platform detected, skipping local save");
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$imageId.jpg');
      await file.writeAsBytes(await imageFile.readAsBytes());
    } catch (e) {
      print("❌ Error saving image locally: $e");
      throw Exception('Failed to save image locally');
    }
  }
}
