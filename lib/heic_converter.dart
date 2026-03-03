@JS()
library heic_converter;

import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'dart:typed_data';

@JS('heic2any')
external JSPromise _heic2any(Heic2anyOptions options);

@JS()
@anonymous
class Heic2anyOptions {
  external factory Heic2anyOptions({
    Object? blob,
    String? toType,
    bool? multiple,
  });
}

@JS()
@anonymous
class JSBlob {
  external JSPromise arrayBuffer();
}

Future<Uint8List> convertHeicToJpg(Uint8List heicData) async {
  try {
    final options = Heic2anyOptions(
      blob: heicData.toJS,
      toType: 'image/jpeg',
      multiple: false,
    );

    final jsResult = await _heic2any(options).toDart;
    final blob = jsResult as JSBlob;
    final arrayBuffer = await blob.arrayBuffer().toDart;

    return arrayBuffer.toDart;
  } catch (e) {
    throw Exception('HEIC Konvertierung fehlgeschlagen: $e');
  }
}
