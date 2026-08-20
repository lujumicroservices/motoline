import 'dart:io';

import 'package:flutter/services.dart';

class ReelEncoderException implements Exception {
  ReelEncoderException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// RGBA frames → H.264 MP4 via Android MediaCodec / iOS AVAssetWriter.
class ReelEncoder {
  ReelEncoder._();

  static const _ch = MethodChannel('com.motoline.motoline/reel_encoder');

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static Future<void> start({
    required String outputPath,
    required int width,
    required int height,
    required int fps,
  }) async {
    try {
      await _ch.invokeMethod<void>('start', {
        'path': outputPath,
        'width': width,
        'height': height,
        'fps': fps,
      });
    } on PlatformException catch (e) {
      throw ReelEncoderException(e.message ?? e.code);
    }
  }

  static Future<void> addRgbaFrame(Uint8List rgba) async {
    try {
      await _ch.invokeMethod<void>('addFrame', {'bytes': rgba});
    } on PlatformException catch (e) {
      throw ReelEncoderException(e.message ?? e.code);
    }
  }

  static Future<void> finish() async {
    try {
      await _ch.invokeMethod<void>('finish');
    } on PlatformException catch (e) {
      throw ReelEncoderException(e.message ?? e.code);
    }
  }
}
