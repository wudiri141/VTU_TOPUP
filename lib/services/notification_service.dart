import 'package:flutter/services.dart';

class NotificationService {
  static const MethodChannel _channel = MethodChannel('vtu_topup/notifications');

  static Future<void> init() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  static Future<void> transaction({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('notifyTransaction', {
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }
}
