import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Turns whatever the platform camera produces into a JPEG the backend can
/// decode.
///
/// * iOS delivers `ImageFormatGroup.jpeg` directly — zero work.
/// * Android delivers `ImageFormatGroup.yuv420`; the native side
///   (`ai.gesto.app/camera_codec`) converts YUV_420_888 -> NV21 -> JPEG with
///   Android's hardware encoder, off the UI thread.
class FrameEncoder {
  FrameEncoder({this.quality = 80});

  static const MethodChannel _channel = MethodChannel('ai.gesto.app/camera_codec');

  final int quality;

  bool _nativeUnavailable = false;
  bool _warned = false;

  /// True when the platform can hand us JPEG frames with no conversion.
  static bool get platformGivesJpeg => !Platform.isAndroid;

  /// Outcome of one encode attempt.
  Future<EncodedFrame?> encode(CameraImage image) async {
    final ImageFormatGroup group = image.format.group;

    if (group == ImageFormatGroup.jpeg) {
      if (image.planes.isEmpty || image.planes.first.bytes.isEmpty) return null;
      return EncodedFrame(image.planes.first.bytes, converted: false);
    }

    if (!Platform.isAndroid) {
      _reportOnce('Unsupported camera format ${group.name} on this platform');
      return null;
    }
    if (_nativeUnavailable) return null;
    if (image.planes.isEmpty) return null;

    try {
      final Uint8List? jpeg = await _channel.invokeMethod<Uint8List>(
        'encodeJpeg',
        <String, Object>{
          'width': image.width,
          'height': image.height,
          'quality': quality,
          'format': image.planes.length == 1 ? 'nv21' : 'yuv420',
          'planes': <Uint8List>[for (final Plane p in image.planes) p.bytes],
          'rowStrides': <int>[for (final Plane p in image.planes) p.bytesPerRow],
          'pixelStrides': <int>[for (final Plane p in image.planes) p.bytesPerPixel ?? 1],
        },
      );
      if (jpeg == null || jpeg.isEmpty) return null;
      return EncodedFrame(jpeg, converted: true);
    } on MissingPluginException {
      _nativeUnavailable = true;
      _reportOnce('Native frame encoder is not registered in this build');
      return null;
    } on PlatformException catch (error) {
      _reportOnce('Frame encode failed: ${error.message ?? error.code}');
      return null;
    } on Object catch (error) {
      _reportOnce('Frame encode failed: $error');
      return null;
    }
  }

  void _reportOnce(String message) {
    if (_warned) return;
    _warned = true;
    debugPrint('[gesto-ai] $message');
  }
}

class EncodedFrame {
  const EncodedFrame(this.bytes, {required this.converted});

  final Uint8List bytes;

  /// False when the camera already produced JPEG.
  final bool converted;
}
