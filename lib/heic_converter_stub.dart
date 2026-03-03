import 'dart:typed_data';

/// Web-Stub: HEIC Konvertierung ist im Browser nicht unterstützt
Future<Uint8List> convertHeicToJpg(Uint8List heicData) {
  throw UnsupportedError('HEIC nicht unterstützt');
}

/// Prüft ob Datei-Format unterstützt wird
bool isSupportedFormat(String? extension) {
  if (extension == null) return false;
  final ext = extension.toLowerCase();
  return ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';
}

/// Gibt unterstützte Formate als Text aus
String getSupportedFormatsText() {
  return 'JPG, PNG, WebP';
}
