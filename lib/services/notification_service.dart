import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/food_item.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Imposta fuso orario Europa/Roma
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static tz.TZDateTime _toTZ(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }

  /// Pianifica notifica di scadenza per un alimento
  static Future<void> scheduleExpiryNotification(FoodItem item) async {
    await cancelItemNotifications(item);

    final targetDate = item.isOpened ? item.postOpeningExpiry : item.expirationDate;
    if (targetDate == null) return;

    final tzTarget = _toTZ(targetDate);

    // Notifica il giorno della scadenza alle 9:00
    if (tzTarget.isAfter(tz.TZDateTime.now(tz.local))) {
      final scheduledDate = tz.TZDateTime(
        tz.local,
        tzTarget.year,
        tzTarget.month,
        tzTarget.day,
        9,
      );

      await _plugin.zonedSchedule(
        _expiryId(item),
        '${item.name} scade oggi!',
        item.isOpened
            ? 'Aperto il ${_formatDate(item.openedDate!)}, non consumare oltre oggi.'
            : 'Controlla se \u00e8 ancora buono.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'food_expiry',
            'Scadenze Alimenti',
            channelDescription: 'Notifiche di scadenza alimenti',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(sound: 'default'),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }

    // Notifica 1 giorno prima alle 18:00
    final dayBefore = tzTarget.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(tz.TZDateTime.now(tz.local))) {
      final scheduledDate = tz.TZDateTime(
        tz.local,
        dayBefore.year,
        dayBefore.month,
        dayBefore.day,
        18,
      );

      await _plugin.zonedSchedule(
        _expiryDayBeforeId(item),
        '${item.name} scade domani!',
        'Pianifica di consumarlo entro domani.',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'food_expiry_warning',
            'Avvisi Scadenza',
            channelDescription: 'Avvisi un giorno prima della scadenza',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(sound: 'default'),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  static Future<void> cancelItemNotifications(FoodItem item) async {
    await _plugin.cancel(_expiryId(item));
    await _plugin.cancel(_expiryDayBeforeId(item));
  }

  static Future<void> showOpenedNotification(FoodItem item) async {
    final postExpiry = item.postOpeningExpiry;
    final message = postExpiry != null
        ? 'Da consumare entro il ${_formatDate(postExpiry)} (${item.daysAfterOpening} giorni)'
        : 'Data di scadenza post-apertura non specificata';

    await _plugin.show(
      item.id.hashCode,
      'Aperto: ${item.name}',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'food_opened',
          'Aperture',
          channelDescription: 'Conferma apertura alimenti',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(sound: 'default'),
      ),
    );
  }

  static int _expiryId(FoodItem item) => '${item.id}_exp'.hashCode.abs();
  static int _expiryDayBeforeId(FoodItem item) =>
      '${item.id}_warn'.hashCode.abs();

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}