// Conditional export - wählt Implementation basierend auf Plattform
export 'heic_converter_stub.dart'
    if (dart.library.html) 'heic_converter_web.dart';
