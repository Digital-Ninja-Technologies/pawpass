import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/models.dart';
import 'repositories.dart';

/// Gallery and camera through the official image_picker plugin. Photos are shrunk before upload.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> fromGallery() => _pick(ImageSource.gallery);

  @override
  Future<PickedPhoto?> fromCamera() => _pick(ImageSource.camera);

  Future<PickedPhoto?> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final ext = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      return PickedPhoto(bytes, extension: ext);
    } catch (_) {
      throw const AppFailure(
        'We could not open your photos. Check that PawPass is allowed to use the camera and photos.',
      );
    }
  }
}

/// Opens the inbox: the Mail app on iPhone, the default email app on Android.
class DeviceEmailAppLauncher implements EmailAppLauncher {
  @override
  Future<bool> open() async {
    try {
      if (Platform.isAndroid) {
        await const AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.APP_EMAIL',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        ).launch();
        return true;
      }
      if (Platform.isIOS) {
        return await launchUrl(Uri.parse('message://'));
      }
    } catch (_) {
      // Fall through: nothing to open.
    }
    return false;
  }
}
