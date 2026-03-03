@JS()
library heic_converter;

import 'package:js/js.dart';
import 'package:js/js_util.dart' show promiseToFuture;
import 'dart:typed_data';

@JS('heic2any')
external dynamic _heic2any(dynamic options);

@JS()
@anonymous
class Heic2anyOptions {
  external factory Heic2anyOptions({
    dynamic blob,
    String? toType,
    bool? multiple,
  });
}

Future<Uint8List> convertHeicToJpg(Uint8List heicData) async {
  try {
    final options = Heic2anyOptions(
      blob: heicData,
      toType: 'image/jpeg',
      multiple: false,
    );

    final result = await promiseToFuture(_heic2any(options));

    // heic2any returns a Blob, convert to Uint8List
    final arrayBuffer = await promiseToFuture(
      callMethod(result, 'arrayBuffer', []),
    );

    return allowInterop(() => arrayBuffer) as Uint8List;
  } catch (e) {
    throw Exception('HEIC Konvertierung fehlgeschlagen: $e');
  }
}
