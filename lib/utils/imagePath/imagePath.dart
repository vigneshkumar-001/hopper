import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  static Future<String> pickImage(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();

    // Show bottom sheet for source selection
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return ''; // user cancelled

    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (image != null) {
      final path = image.path.toLowerCase();
      if (path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg')) {
        return image.path;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only PNG, JPG, and JPEG formats are supported')),
        );
      }
    }

    return '';
  }
}
/*class ImageUtils {
  static Future<String> pickImage(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
      preferredCameraDevice: CameraDevice.rear,
      source: ImageSource.camera,
      maxWidth: 1024,
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
}*/
