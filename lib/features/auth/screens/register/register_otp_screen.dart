import 'package:emergency_map_sy/features/dashboard/unififed_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';

import '../../../../widgets/loading_ui.dart';
import '../../cubit/auth_cubit.dart';

class RegisterOtpScreen extends StatelessWidget {
  final AuthCubit cubit;

  RegisterOtpScreen({super.key, required this.cubit});

  final formKey = GlobalKey<FormState>();

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
              cubit.register();
            }

            if (state is AuthSuccess) {
              final userType = cubit.userType;
              if (userType != null) {
                Widget dashboard = UnifiedDashboardScreen(userType: userType);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => dashboard),
                  (route) => false,
                );
              }
            }
          },
          builder: (context, state) {
            final cubit = context.read<AuthCubit>();

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
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
                                    'أدخل رمز التحقق',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Subtitle
                                  Text(
                                    'لقد أرسلنا رمزًا إلى ${cubit.phoneController.text}',
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
                                        width:
                                            MediaQuery.of(context).size.width /
                                                6,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(color: Colors.red),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'هذا الحقل مطلوب';
                                        } else if (value.length != 4) {
                                          return 'الرجاء إدخال الرمز المكون من أربعة أرقام';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  state is VerifyCodeLoading
                                      ? const LoadingUi()
                                      : // Button to VERIFY the code and complete registration
                                      SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              final cubit =
                                                  context.read<AuthCubit>();
                                              if (formKey.currentState!
                                                  .validate()) {
                                                cubit.register();
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                            ),
                                            child: const Text('التسجيل بالرمز'),
                                          ),
                                        ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      'تغيير رقم الهاتف',
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
              ),
            );
          },
        ),
      ),
    );
  }
}
