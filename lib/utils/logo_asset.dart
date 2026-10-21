import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

const String _logoAsset = 'assets/images/logo.png';

Uint8List? _cached;
bool _tried = false;

/// The TUGHE logo bytes for PDFs (payslips, reports); null when the asset is missing,
/// in which case the PDF is simply produced without the logo.
Future<Uint8List?> loadTugheLogoBytes() async {
  if (_tried) return _cached;
  _tried = true;
  try {
    final data = await rootBundle.load(_logoAsset);
    _cached = data.buffer.asUint8List();
  } catch (_) {
    _cached = null;
  }
  return _cached;
}
