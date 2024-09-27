import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<String?> capturePhotoFromCameraAndSend() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, imageQuality: 50);
    if (photo != null) {
      File photoFile = File(photo.path);
      Uint8List imageBytes = photoFile.readAsBytesSync();
      final stringBytes = String.fromCharCodes(imageBytes);
      return stringBytes;
    }
    return null;
  }
