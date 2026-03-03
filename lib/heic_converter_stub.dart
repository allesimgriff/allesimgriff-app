import 'dart:typed_data';

/// Web-Stub: HEIC Konvertierung ist im Browser nicht unterstützt
/// Nutzer sollten JPG oder PNG verwenden
Future<Uint8List> convertHeicToJpg(Uint8List heicData) {
  throw UnsupportedError(
    'HEIC Konvertierung ist im Browser nicht verfügbar. '
    'Bitte verwenden Sie JPG oder PNG Bilder.',
  );
}
