import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static Future<String> pickImage(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024, // Resize to lower resolution
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      if (image.path.endsWith('.png') ||
          image.path.endsWith('.jpg') ||
          image.path.endsWith('.jpeg')) {
        return image.path;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Only PNG, JPG, and JPEG formats are supported'),
          ),
        );
        return '';
      }
    } else {
      return '';
    }
  }

  // Future<void> pickImage(int index) async {
  //   final XFile? image = await _picker.pickImage(source: ImageSource.camera);
  //   if (image != null) {
  //     if (image.path.endsWith('.png') || image.path.endsWith('.jpg')
  //     // image.path.endsWith('.jpeg')
  //     ) {
  //
  //         _selectedImages[index] = File(image.path);
  //
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Only PNG and JPG formats are supported')),
  //       );
  //     }
  //   }
  // }
}
