import 'dart:typed_data';

class WebFileSaver {
  Future<void> saveFile(Uint8List bytes, String fileName, String mimeType) async {
    // No-op for non-web platforms
    return;
  }
}
