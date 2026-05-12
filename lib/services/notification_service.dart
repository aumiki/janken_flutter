import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/game_state.dart';

/// Notification handling without Firebase/FCM.
///
/// Per requirements, notifications should be delivered via Socket.IO only.
/// This service keeps the same public API used across the app.
class NotificationService {
  /// Callback saat user tap notifikasi challenge
  static Function(ChallengeData)? onChallengeReceived;

  /// Init stub (no Firebase/FCM).
  static Future<void> init() async {
    // No-op. If the project later reintroduces local notifications,
    // this is the place to initialize them.
    debugPrint('[NotificationService] init (socket.io only)');
  }

  /// Show a challenge notification.
  ///
  /// Currently this is a lightweight in-app trigger.
  /// UI apps can optionally connect this to dialogs/snackbars.
  static Future<void> showChallengeNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('[NotificationService] $title - $body');

    // If the payload contains challenger's info and the app wants
    // to handle it immediately, trigger callback.
    if (payload != null &&
        payload.isNotEmpty &&
        payload.contains('challengerId') &&
        onChallengeReceived != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        if (data['challengerId'] != null) {
          onChallengeReceived!(ChallengeData.fromJson(data));
        }
      } catch (_) {
        // ignore parse errors
      }
    }
  }

  /// Show notif when challenged via Socket.IO
  static Future<void> notifyChallenge(ChallengeData data) async {
    await showChallengeNotification(
      title: '⚔️ Challenge dari ${data.challengerName}!',
      body:
          '${data.challengerName} (${data.challengerPoints} pts) menantangmu di Janken! Ketuk untuk merespons.',
      payload: jsonEncode({
        'challengerId': data.challengerId,
        'challengerName': data.challengerName,
        'challengerPoints': data.challengerPoints,
        // ensure consumer can detect payload
        'channelId': AppConfig.notifChannelId,
      }),
    );
  }
}
