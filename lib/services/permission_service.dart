import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

class PermissionService {
  static final ImagePicker _picker = ImagePicker();

  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request gallery/photo permission
  static Future<bool> requestPhotoPermission() async {
    final status = await Permission.photos.request();
    if (status.isDenied) {
      return false;
    }
    if (status.isPermanentlyDenied) {
      openAppSettings();
      return false;
    }
    return status.isGranted;
  }

  /// Pick image dari camera
  static Future<XFile?> pickImageFromCamera() async {
    final hasPermission = await requestCameraPermission();
    if (!hasPermission) return null;

    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      return image;
    } catch (e) {
      print('[PermissionService] Camera error: $e');
      return null;
    }
  }

  /// Pick image dari gallery
  static Future<XFile?> pickImageFromGallery() async {
    final hasPermission = await requestPhotoPermission();
    if (!hasPermission) return null;

    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      return image;
    } catch (e) {
      print('[PermissionService] Gallery error: $e');
      return null;
    }
  }

  /// Show dialog untuk pilih sumber
  static Future<XFile?> pickImageFromSourceDialog() async {
    XFile? image;
    
    // Show bottom sheet / dialog untuk pilih
    // Bisa diimplement sesuai UI kamu
    // Untuk sekarang, default ke gallery
    image = await pickImageFromGallery();
    
    return image;
  }

  /// Check multiple permissions
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'camera': (await Permission.camera.status).isGranted,
      'photos': (await Permission.photos.status).isGranted,
      'storage': (await Permission.storage.status).isGranted,
    };
  }
}
