import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/rodadas/rodada_detail_screen.dart';
import '../../features/rodadas/rodada_repository.dart';
import '../auth/impersonation_store.dart';
import '../supabase/supabase_bootstrap.dart';
import 'device_token_repository.dart';
import 'push_diagnostics.dart';

const _inviteChannelId = 'riderlab_rodada_invites';
const _radioChannelId = 'riderlab_rodada_radio';
const _alertChannelId = 'riderlab_rodada_alerts';
const _acceptAction = 'rodada_accept';
const _declineAction = 'rodada_decline';
const _radioTabIndex = 4;

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

String? _pendingRodadaId;
int _pendingTab = 0;
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
    await PushDiagnostics.hydrate();
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase.init: $e');
      PushDiagnostics.recordError('firebase_init', e);
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
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _radioChannelId,
        'Radio de rodada',
        description: 'Mensajes de radio del grupo',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        'Alertas de radio',
        description: 'Pedidos de ayuda en la rodada',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _queueRodada(
        initial.data['rodada_id']?.toString(),
        tab: _tabFromData(initial.data),
      );
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
    if (ImpersonationStore.isActive) {
      PushDiagnostics.record(fn: 'fcm_token', skipped: 'impersonating');
      return;
    }
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (Firebase.apps.isEmpty) {
      PushDiagnostics.record(fn: 'fcm_token', error: 'firebase_not_ready');
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        PushDiagnostics.record(fn: 'fcm_token', skipped: 'no_token');
        return;
      }
      _cachedFcmToken = token;
      await _tokens.upsert(token: token, platform: pushPlatformName());
    } catch (e) {
      debugPrint('FCM token: $e');
      PushDiagnostics.recordError('fcm_token', e);
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
    final tab = _pendingTab;
    _pendingRodadaId = null;
    _pendingTab = 0;
    _pushRodada(id, tab: tab);
  }

  Future<void> _storeToken(String token) async {
    if (ImpersonationStore.isActive) return;
    _cachedFcmToken = token;
    try {
      await _tokens.upsert(token: token, platform: pushPlatformName());
    } catch (e) {
      debugPrint('FCM refresh: $e');
      PushDiagnostics.recordError('fcm_token_refresh', e);
    }
  }

  void _onForeground(RemoteMessage message) {
    final n = message.notification;
    final type = _typeFromData(message.data);
    final rodadaId = message.data['rodada_id']?.toString();
    final isAlert = type == 'rodada_alert';
    final isRadio = type == 'rodada_radio' || isAlert;
    final title = n?.title ??
        (isAlert
            ? 'ALERTA de radio'
            : isRadio
                ? 'Radio'
                : 'Invitación a rodada');
    final body = n?.body ?? '';
    final channelId = isAlert
        ? _alertChannelId
        : isRadio
            ? _radioChannelId
            : _inviteChannelId;
    final channelName = isAlert
        ? 'Alertas de radio'
        : isRadio
            ? 'Radio de rodada'
            : 'Invitaciones a rodada';
    _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: isAlert
              ? 'Pedidos de ayuda en la rodada'
              : isRadio
                  ? 'Mensajes de radio del grupo'
                  : 'Invites to group rides',
          importance: isAlert ? Importance.max : Importance.high,
          priority: isAlert ? Priority.max : Priority.high,
          playSound: true,
          enableVibration: true,
          actions: isRadio
              ? const []
              : const [
                  AndroidNotificationAction(_acceptAction, 'Aceptar'),
                  AndroidNotificationAction(_declineAction, 'Rechazar'),
                ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: isAlert
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      payload: _payload(rodadaId, type: type),
    );
  }

  void _onOpened(RemoteMessage message) {
    _queueRodada(
      message.data['rodada_id']?.toString(),
      tab: _tabFromData(message.data),
    );
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
    _queueRodada(rodadaId, tab: _tabFromPayload(payload));
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

  static String _typeFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    if (type == 'rodada_alert' || data['kind']?.toString() == 'safety') {
      return 'rodada_alert';
    }
    if (type == 'rodada_radio' || data['tab']?.toString() == 'radio') {
      return 'rodada_radio';
    }
    return type.isEmpty ? 'rodada_invite' : type;
  }

  static int _tabFromData(Map<String, dynamic> data) {
    final type = _typeFromData(data);
    if (type == 'rodada_radio' || type == 'rodada_alert') return _radioTabIndex;
    return 0;
  }

  static String _payload(String? rodadaId, {String type = 'rodada_invite'}) {
    if (rodadaId == null || rodadaId.isEmpty) return '';
    switch (type) {
      case 'rodada_alert':
        return 'rodada_alert:$rodadaId';
      case 'rodada_radio':
        return 'rodada_radio:$rodadaId';
      default:
        return 'rodada_invite:$rodadaId';
    }
  }

  static String? _rodadaIdFrom(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    for (final prefix in ['rodada_invite:', 'rodada_radio:', 'rodada_alert:']) {
      if (payload.startsWith(prefix)) return payload.substring(prefix.length);
    }
    return payload;
  }

  static int _tabFromPayload(String? payload) {
    if (payload == null) return 0;
    if (payload.startsWith('rodada_radio:') ||
        payload.startsWith('rodada_alert:')) {
      return _radioTabIndex;
    }
    return 0;
  }

  static void _queueRodada(String? id, {int tab = 0}) {
    if (id == null || id.isEmpty) return;
    if (!_pushRodada(id, tab: tab)) {
      _pendingRodadaId = id;
      _pendingTab = tab;
    }
  }

  static bool _pushRodada(String id, {int tab = 0}) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return false;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => RodadaDetailScreen(rodadaId: id, initialTab: tab),
      ),
    );
    return true;
  }
}
