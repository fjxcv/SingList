import 'package:flutter/services.dart';

class ScreenAwakeService {
  const ScreenAwakeService();

  static const _channel = MethodChannel('singlist/screen_awake');

  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // Unsupported platforms keep their normal screen timeout behavior.
    } on PlatformException {
      // Keeping the screen awake is best-effort and must not block lyrics.
    }
  }
}
