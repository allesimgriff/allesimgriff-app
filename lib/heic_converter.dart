import 'dart:typed_data';

/// HEIC Konvertierung ist nicht verfügbar
/// Diese Funktion wirft immer einen Fehler
Future<Uint8List> convertHeicToJpg(Uint8List heicData) {
  throw UnsupportedError('HEIC Konvertierung ist nicht verfügbar');
}
