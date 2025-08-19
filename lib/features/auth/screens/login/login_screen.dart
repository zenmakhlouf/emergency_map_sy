import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/auth_cubit.dart';
import '../../models/user_type.dart';
import '../../../../widgets/loading_ui.dart';
import '../../../../screens/citizen_dashboard_screen.dart';
import '../../../../screens/responder_dashboard_screen.dart';
import '../../../../screens/coordinator_dashboard_screen.dart';
import '../register/register_screen.dart';
import 'login_otp_screen.dart';

class LoginScreen extends StatelessWidget {
  final UserType userType;

  LoginScreen({super.key, required this.userType});

  final formKey = GlobalKey<FormFieldState>();

  void _navigateToDashboard(BuildContext context) {
    Widget dashboard;
    switch (userType) {
      case UserType.citizen:
        dashboard = const CitizenDashboardScreen();
        break;
      case UserType.responder:
        dashboard = const ResponderDashboardScreen();
        break;
      case UserType.coordinator:
        dashboard = const CoordinatorDashboardScreen();
        break;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => dashboard),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.red),
        ),
      ),
      body: BlocProvider(
        create: (context) => AuthCubit(),
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            final cubit = context.read<AuthCubit>();

            if (state is SendCodeSuccess) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LoginOtpScreen(
                    userType: userType,
                    cubit: cubit,
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<AuthCubit>();

            return Container(
              height: double.infinity,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF5F5), Color(0xFFFFEBEE)],
                ),
              ),
              alignment: Alignment.center,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Back Button

                      Center(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Icon
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.phone,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Title
                                const Text(
                                  'Enter Phone Number',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle
                                Text(
                                  'Verify your identity as a ${userType.name}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),

                                TextFormField(
                                  key: formKey,
                                  controller: cubit.phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    prefixText: '+963 ',
                                    prefixStyle: TextStyle(color: Colors.black),
                                    labelText: '+963 999999999',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'This field is required';
                                    } else if (value.length != 9) {
                                      return 'Please enter a valid phone number without 0';
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                state is SendCodeLoading
                                    ? const LoadingUi()
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          autofocus: true,
                                          onPressed: () {
                                            if (formKey.currentState!.validate()) {
                                              cubit.sendOtp('phone_number_login');
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                          ),
                                          child: const Text('Send Verification Code'),
                                        ),
                                      ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => RegisterScreen(
                                        userType: userType,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Don\'t have an account yet? register',
                                    style: TextStyle(
                                      color: Colors.red,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
