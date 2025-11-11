import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';

Future<File?> cropImage(String path, BuildContext context) async {
  final croppedFile = await ImageCropper().cropImage(
    sourcePath: path,
    aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop Profile Image',
        toolbarColor: Theme.of(context).colorScheme.primary,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
      ),
      IOSUiSettings(
        title: 'Crop Profile Image',
        aspectRatioLockEnabled: true,
        aspectRatioPresets: [CropAspectRatioPreset.square],
      ),
    ],
  );

  return croppedFile != null ? File(croppedFile.path) : null;
}