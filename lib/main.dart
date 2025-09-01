import 'package:emergency_map_sy/features/auth/models/user_type.dart';
import 'package:emergency_map_sy/features/users_location/cubit/userslocation_cubit.dart';
import 'package:emergency_map_sy/features/users_location/repo/locationservice.dart';
import 'package:emergency_map_sy/screens/unified_dashboard.dart';
import 'package:emergency_map_sy/utils/urls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'apis/network.dart';
import 'features/reports/cubit/reports_cubit.dart';
import 'features/reports/repo/reportRepoService.dart';
import 'features/chat/cubit/chat_cubit.dart';
import 'features/chat/repo/chat_repo.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'screens/user_type_selector_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Network.init();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => ReportsCubit(ReportService())),
        BlocProvider(create: (_) => ChatCubit(ChatRepository())),
        BlocProvider(
          create: (_) => UsersLocationCubit(
            locationService:
                LocationService(dio: Network.dio, baseUrl: Urls.baseUrl),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
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
      home: FutureBuilder<Widget>(
        future: _getStartScreen(context), // Pass context here
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            print(snapshot.error);
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!;
        },
      ),
    );
  }
}

Future<Widget> _getStartScreen(BuildContext context) async {
  // Accept context
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final userType = prefs.getString('user_type');

  // defensive check — empty string should count as "not logged in"
  if (token == null || token.isEmpty || userType == null || userType.isEmpty) {
    return const UserTypeSelectorScreen();
  }

  // Ensure UsersLocationCubit is available before building UnifiedDashboardScreen
  // This ensures the context used to build UnifiedDashboardScreen has access to UsersLocationCubit
  BlocProvider.of<UsersLocationCubit>(context);

  return UnifiedDashboardScreen(
      userType: UserType.values.firstWhere(
    (e) => e.name == userType,
  ));
}
