import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:torch_light/torch_light.dart';

class TorchNotificationService {
  static final TorchNotificationService _instance =
      TorchNotificationService._internal();
  factory TorchNotificationService() => _instance;
  TorchNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 42;
  static const String _channelId = 'torch_channel';
  static const String _channelName = 'Torche active';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.actionId == 'close_action') {
      TorchLight.disableTorch().catchError((_) {});
      cancelNotification();
    }
  }

  Future<void> showTorchNotification({required bool isOn}) async {
    await init();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Contrôle de la torche en arrière-plan',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFFD700),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'close_action',
          '⏻  Fermer la torche',
          cancelNotification: true,
          showsUserInterface: false,
        ),
      ],
    );

    await _plugin.show(
      _notificationId,
      isOn ? '🔦 Torche allumée' : '🔦 Torche en veille',
      isOn
          ? 'Appuyez sur "Fermer la torche" pour éteindre.'
          : 'La torche est éteinte. Rouvrez l\'app pour la rallumer.',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelNotification() async {
    await _plugin.cancel(_notificationId);
  }
}