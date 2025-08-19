import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

import '../../../../screens/citizen_dashboard_screen.dart';
import '../../../../screens/coordinator_dashboard_screen.dart';
import '../../../../screens/responder_dashboard_screen.dart';
import '../../../../widgets/loading_ui.dart';
import '../../cubit/auth_cubit.dart';
import '../../models/user_type.dart';

class LoginOtpScreen extends StatelessWidget {
  final UserType userType;
  final AuthCubit cubit;

  LoginOtpScreen({super.key, required this.userType, required this.cubit});

  final formKey = GlobalKey<FormState>();

  // void _navigateToDashboard(BuildContext context) {
  //   Widget dashboard;
  //   switch (userType) {
  //     case UserType.citizen:
  //       dashboard = const CitizenDashboardScreen();
  //       break;
  //     case UserType.responder:
  //       dashboard = const ResponderDashboardScreen();
  //       break;
  //     case UserType.coordinator:
  //       dashboard = const CoordinatorDashboardScreen();
  //       break;
  //   }
  //
  //   Navigator.pushAndRemoveUntil(
  //     context,
  //     MaterialPageRoute(builder: (context) => dashboard),
  //     (route) => false,
  //   );
  // }

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
      body: BlocProvider.value(
        value: cubit,
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            final cubit = context.read<AuthCubit>();

            if (state is VerifyCodeSuccess) {
              cubit.login();
            }

            if (state is AuthSuccess) {
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
                                  'Enter Verification Code',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle
                                Text(
                                  'We sent a code to ${cubit.phoneController.text}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),

                                // OTP Input
                                Form(
                                  key: formKey,
                                  child: Pinput(
                                    length: 4,
                                    controller: cubit.otpController,
                                    defaultPinTheme: PinTheme(
                                      width: MediaQuery.of(context).size.width / 6,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'This field is required';
                                      } else if (value.length != 4) {
                                        return 'Please enter the four digit otp';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                state is VerifyCodeLoading
                                    ? const LoadingUi()
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            if (formKey.currentState!.validate()) {
                                              cubit.checkOtp('phone_number_login');
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                          ),
                                          child: const Text('Verify Code'),
                                        ),
                                      ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    'Change Phone Number',
                                    style: TextStyle(color: Colors.red),
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
