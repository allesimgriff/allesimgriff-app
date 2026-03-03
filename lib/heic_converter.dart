import 'dart:js_interop';
import 'dart:typed_data';

@JS('heic2any')
external JSPromise _heic2any(Heic2anyOptions options);

@JS()
@anonymous
class Heic2anyOptions {
  external Uint8List get blob;
  external String get toType;
  external bool get multiple;

  factory Heic2anyOptions({
    required Uint8List blob,
    required String toType,
    required bool multiple,
  }) => Heic2anyOptionsImpl(blob: blob, toType: toType, multiple: multiple);
}

@JS()
@anonymous
class Heic2anyOptionsImpl implements Heic2anyOptions {
  external factory Heic2anyOptionsImpl({
    required Uint8List blob,
    required String toType,
    required bool multiple,
  });

  external Uint8List get blob;
  external String get toType;
  external bool get multiple;
}

@JS()
@anonymous
class JSBlob {
  external JSPromise arrayBuffer();
}

@JS()
@anonymous
class JSArray {
  external dynamic operator [](int index);
}

@JS()
@anonymous
class JSPromise {
  external JSPromise then(JSFunction onFulfilled);
  external Future<dynamic> toDart;
}

Future<Uint8List> convertHeicToJpg(Uint8List heicData) async {
  try {
    final options = Heic2anyOptions(
      blob: heicData,
      toType: 'image/jpeg',
      multiple: false,
    );

    final result = await _heic2any(options).toDart;

    if (result is JSArray) {
      final blob = result[0] as JSBlob;
      final arrayBuffer = await blob.arrayBuffer().toDart;
      return arrayBuffer.toUint8List();
    } else if (result is JSBlob) {
      final arrayBuffer = await result.arrayBuffer().toDart;
      return arrayBuffer.toUint8List();
    }

    throw Exception('Unerwartetes HEIC Konvertierungsergebnis');
  } catch (e) {
    throw Exception('HEIC Konvertierung fehlgeschlagen: $e');
  }
}
