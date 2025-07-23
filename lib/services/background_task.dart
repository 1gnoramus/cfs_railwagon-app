import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const taskName = "checkWagonStatusTask";

void callbackDispatcher() {
  print('>>> Вызвано задание: $taskName');

  Workmanager().executeTask((task, inputData) async {
    print('TASK STARTED');
    try {
      // Уведомления
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Получаем отмеченные вагоны
      final prefs = await SharedPreferences.getInstance();
      final trackedWagonsJson = prefs.getString('trackedWagons');
      if (trackedWagonsJson == null) return true;

      final trackedWagonNumbers =
          List<String>.from(jsonDecode(trackedWagonsJson));

      // Загружаем новую таблицу
      final response = await http
          .get(Uri.parse('https://railwagon-server.vercel.app/download-excel'));

      if (response.statusCode != 200) throw 'Ошибка загрузки таблицы';

      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.tables.values.first;

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final number = row[0]?.value?.toString() ?? 'Н/Д';
        if (!trackedWagonNumbers.contains(number)) continue;

        final currentStation = row[5]?.value?.toString() ?? '';
        final destination = row[3]?.value?.toString() ?? '';
        final leftDistanceStr = row[8]?.value?.toString() ?? '';
        final leftDistance =
            double.tryParse(leftDistanceStr.replaceAll(',', '.')) ?? 100000;

        // Проверка условий
        if (leftDistance < 300) {
          await showNotification(
            flutterLocalNotificationsPlugin,
            'Вагон $number почти доехал',
            'Осталось меньше 300 км до станции назначения: $destination',
          );
        }

        if (currentStation == destination) {
          await showNotification(
            flutterLocalNotificationsPlugin,
            'Вагон $number прибыл',
            'Вагон доехал до станции назначения: $destination',
          );
        }
      }
    } catch (e) {
      print("Ошибка в фоновой задаче: $e");
    }
    print('destination');

    return true;
  });
  print('TASK STARTED');
}

Future<void> showNotification(
    FlutterLocalNotificationsPlugin plugin, String title, String body) async {
  const androidDetails = AndroidNotificationDetails(
    'wagon_channel_id',
    'Слежение по вагонам',
    channelDescription: 'Уведомления об изменении местонахождения вагонов',
    importance: Importance.max,
    priority: Priority.high,
  );

  const notificationDetails = NotificationDetails(android: androidDetails);

  await plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body,
      notificationDetails);
}
