import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/apis/network.dart';
import 'core/shared_preferences/shared_preferences_helper.dart';
import 'features/auth/models/user_type.dart';
import 'screens/citizen_dashboard_screen.dart';
import 'screens/coordinator_dashboard_screen.dart';
import 'screens/responder_dashboard_screen.dart';
import 'screens/user_type_selector_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await AppSharedPreferences.init();

  await Network.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafetyConnect',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home:
          AppSharedPreferences.token.isEmpty ? const UserTypeSelectorScreen() : navigateToDashboard,
    );
  }

  Widget get navigateToDashboard {
    final userType = AppSharedPreferences.userType;

    switch (userType) {
      case UserType.responder:
        return const ResponderDashboardScreen();
      case UserType.coordinator:
        return const CoordinatorDashboardScreen();
      default:
        return const CitizenDashboardScreen();
    }
  }
}
