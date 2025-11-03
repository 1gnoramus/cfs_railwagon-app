import 'package:cfs_railwagon/constants/theme_data.dart';
import 'package:cfs_railwagon/services/providers/wagon_provider.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/welcome_screen.dart';
import 'services/background_task.dart';

// Future<void> requestNotificationPermission() async {
//   final status = await Permission.notification.status;
//   if (!status.isGranted) {
//     await Permission.notification.request();
//   }
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await requestNotificationPermission();
  // await Workmanager().initialize(
  //   // callbackDispatcher,
  //   // isInDebugMode: false,
  // );
  // await Workmanager().registerPeriodicTask(
  //   'checkWagonStatus',
  //   taskName,
  //   frequency: const Duration(hours: 2),
  //   initialDelay: const Duration(seconds: 5),
  //   constraints: Constraints(
  //     networkType: NetworkType.connected,
  //   ),
  // );
  runApp(ChangeNotifierProvider(
    create: (_) => WagonProvider()..loadWagons(),
    child: const WagonApp(),
  ));
}

class WagonApp extends StatelessWidget {
  const WagonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CF&S Kazakhstan - Вагонный контроль',
      debugShowCheckedModeBanner: false,
      theme: cfsTheme,
      home: const WelcomeScreen(),
    );
  }
}
