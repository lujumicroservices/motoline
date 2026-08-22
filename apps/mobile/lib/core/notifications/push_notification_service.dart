import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/rodadas/rodada_detail_screen.dart';
import '../../features/rodadas/rodada_repository.dart';
import '../supabase/supabase_bootstrap.dart';
import 'device_token_repository.dart';

const _inviteChannelId = 'riderlab_rodada_invites';
const _acceptAction = 'rodada_accept';
const _declineAction = 'rodada_decline';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

String? _pendingRodadaId;
String? _cachedFcmToken;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  final _tokens = DeviceTokenRepository();
  bool _ready = false;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase.init: $e');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalResponse,
    );
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _inviteChannelId,
        'Invitaciones a rodada',
        description: 'Invites to group rides',
        importance: Importance.high,
      ),
    );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _queueRodada(initial.data['rodada_id']?.toString());
    }
    final launch = await _local.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true && payload != null) {
      _handlePayload(payload, launch!.notificationResponse?.actionId);
    }

    messaging.onTokenRefresh.listen(_storeToken);
    await syncToken();
    _ready = true;
  }

  Future<void> syncToken() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (Firebase.apps.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _cachedFcmToken = token;
      await _tokens.upsert(token: token, platform: pushPlatformName());
    } catch (e) {
      debugPrint('FCM token: $e');
    }
  }

  Future<void> clearToken() async {
    final token = _cachedFcmToken;
    if (token != null) {
      try {
        await _tokens.deleteToken(token);
      } catch (e) {
        debugPrint('FCM delete token: $e');
      }
    }
    _cachedFcmToken = null;
  }

  static void openPendingRodadaIfAny() {
    final id = _pendingRodadaId;
    if (id == null) return;
    _pendingRodadaId = null;
    _pushRodada(id);
  }

  Future<void> _storeToken(String token) async {
    _cachedFcmToken = token;
    try {
      await _tokens.upsert(token: token, platform: pushPlatformName());
    } catch (e) {
      debugPrint('FCM refresh: $e');
    }
  }

  void _onForeground(RemoteMessage message) {
    final n = message.notification;
    final rodadaId = message.data['rodada_id']?.toString();
    final title = n?.title ?? 'Invitación a rodada';
    final body = n?.body ?? '';
    _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _inviteChannelId,
          'Invitaciones a rodada',
          channelDescription: 'Invites to group rides',
          importance: Importance.high,
          priority: Priority.high,
          actions: const [
            AndroidNotificationAction(_acceptAction, 'Aceptar'),
            AndroidNotificationAction(_declineAction, 'Rechazar'),
          ],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _payload(rodadaId),
    );
  }

  void _onOpened(RemoteMessage message) {
    _queueRodada(message.data['rodada_id']?.toString());
  }

  void _onLocalResponse(NotificationResponse response) {
    _handlePayload(response.payload, response.actionId);
  }

  void _handlePayload(String? payload, String? actionId) {
    final rodadaId = _rodadaIdFrom(payload);
    if (rodadaId == null) return;
    if (actionId == _acceptAction || actionId == _declineAction) {
      final rsvp = actionId == _acceptAction ? 'going' : 'declined';
      _applyRsvp(rodadaId, rsvp);
      return;
    }
    _queueRodada(rodadaId);
  }

  void _applyRsvp(String rodadaId, String rsvp) {
    Future(() async {
      try {
        if (!SupabaseBootstrap.isReady) return;
        await SupabaseBootstrap.ensureSession();
        await RodadaRepository().updateMySharing(rodadaId: rodadaId, rsvp: rsvp);
      } catch (e) {
        debugPrint('RSVP from notification: $e');
        _queueRodada(rodadaId);
      }
    });
  }

  static String _payload(String? rodadaId) =>
      rodadaId == null ? '' : 'rodada_invite:$rodadaId';

  static String? _rodadaIdFrom(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    const prefix = 'rodada_invite:';
    if (payload.startsWith(prefix)) return payload.substring(prefix.length);
    return payload;
  }

  static void _queueRodada(String? id) {
    if (id == null || id.isEmpty) return;
    if (!_pushRodada(id)) {
      _pendingRodadaId = id;
    }
  }

  static bool _pushRodada(String id) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return false;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => RodadaDetailScreen(rodadaId: id),
      ),
    );
    return true;
  }
}
