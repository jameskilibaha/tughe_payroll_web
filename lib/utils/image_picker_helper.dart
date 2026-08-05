import 'dart:convert';

import 'package:image_picker/image_picker.dart';

/// Opens the platform's image picker and returns a base64 data URL (e.g.
/// "data:image/jpeg;base64,...") for the chosen image, or null if the
/// person cancelled. Images are downscaled to keep the payload small
/// since they're stored as text in the database.
Future<String?> pickImageAsBase64() async {
  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final base64Str = base64Encode(bytes);
  final mime = file.mimeType ?? 'image/jpeg';
  return 'data:$mime;base64,$base64Str';
}
