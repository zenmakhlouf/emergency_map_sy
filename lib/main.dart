import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      home: const UserTypeSelectorScreen(),
    );
  }
}
