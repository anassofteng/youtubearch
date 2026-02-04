import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<File?> pickImage() async {
  final picker = ImagePicker();
  final xFile = await picker.pickImage(source: ImageSource.gallery);
  if (xFile != null) {
    debugPrint('Image path: ${xFile.path}');
    return File(xFile.path);
  } else {
    debugPrint('No image selected');
    return null;
  }
}

Future<File?> pickVideo() async {
   final picker = ImagePicker();
  final xFile = await picker.pickVideo(source: ImageSource.gallery);
  if (xFile != null) {
    debugPrint('Image path: ${xFile.path}');
    return File(xFile.path);
  } else {
    debugPrint('No Video selected');
    return null;
  }
}
