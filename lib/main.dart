import 'package:emergency_map_sy/features/assignments/cubit/assignments_cubit.dart';
import 'package:emergency_map_sy/features/auth/models/user_type.dart';
import 'package:emergency_map_sy/features/dashboard/unififed_dashboard.dart';
import 'package:emergency_map_sy/features/users_location/cubit/userslocation_cubit.dart';
import 'package:emergency_map_sy/features/users_location/repo/locationservice.dart';
//import 'package:emergency_map_sy/screens/unified_dashboard.dart';
import 'package:emergency_map_sy/utils/urls.dart';
import 'package:emergency_map_sy/widgets/persistent_emergency_fab.dart';
import 'package:emergency_map_sy/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'apis/network.dart';
import 'features/reports/cubit/reports_cubit.dart';
import 'features/reports/repo/reportRepoService.dart';
import 'features/chat/cubit/chat_cubit.dart';
import 'features/chat/repo/chat_repo.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/screens/login/login_screen.dart';

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
                LocationService( baseUrl: Urls.baseUrl),
          ),
        ),
        BlocProvider(create: (_) => AssignmentsCubit()),

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
      title: 'رجال الإنقاذ',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          // Handle any auth state changes if needed
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Scaffold(
              body: Center(child: SplashScreen()),
            );
          }
          
          if (state is AuthSuccess) {
            final authCubit = context.read<AuthCubit>();
            final userType = authCubit.userType;
            
            if (userType != null) {
              return PersistentEmergencyFAB(
                userType: userType,
                child: UnifiedDashboardScreen(userType: userType),
              );
            }
          }
          
          // If not authenticated, go to login screen
          return LoginScreen();
        },
      ),
    );
  }
}

