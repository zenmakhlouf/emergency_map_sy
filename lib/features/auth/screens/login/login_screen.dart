import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/auth_cubit.dart';
import '../../../../widgets/loading_ui.dart';
import '../register/register_screen.dart';
import 'login_otp_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final formKey = GlobalKey<FormFieldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          final cubit = context.read<AuthCubit>();

          if (state is SendCodeSuccess) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LoginOtpScreen(
                  cubit: cubit,
                ),
              ),
            );
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
                                  'أدخل رقم هاتفك',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle
                                const Text(
                                  'أدخل رقم هاتفك لتسجيل الدخول',
                                  style: TextStyle(
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
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                    suffixText: ' ٩٦٣+',
                                    suffixStyle: TextStyle(color: Colors.black),
                                    labelText: '٩٩٩٩٩٩٩٩٩ ٩٦٣+',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'هذا الحقل مطلوب';
                                    } else if (value.length != 9) {
                                      return 'الرجاء إدخال رقم هاتف صحيح بدون الصفر';
                                    } else {
                                      return null;
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                state is SendCodeLoading
                                    ? const LoadingUi()
                                    : // Button to SEND the login confirmation code
                                    SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          autofocus: true,
                                          onPressed: () {
                                            final cubit =
                                                context.read<AuthCubit>();
                                            if (formKey.currentState!
                                                .validate()) {
                                              cubit.sendOtp(
                                                  'phone_number_login');
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                          ),
                                          child: const Text('إرسال رمز الدخول'),
                                        ),
                                      ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen(),
                                    ),
                                  ),
                                  child: const Text(
                                    'ليس لديك حساب بعد؟ سجل الآن',
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
            ),
          );
        },
      ),
    );
  }
}
