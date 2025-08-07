import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_type.dart';
import 'citizen_dashboard_screen.dart';
import 'responder_dashboard_screen.dart';
import 'coordinator_dashboard_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  final UserType userType;

  const PhoneAuthScreen({super.key, required this.userType});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  bool _isPhoneStep = true;
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _handleSendOTP() {
    if (_phoneController.text.length >= 10) {
      setState(() {
        _isPhoneStep = false;
      });
    }
  }

  void _handleVerifyOTP() {
    String otp = _otpControllers.map((controller) => controller.text).join();
    if (otp.length == 6) {
      // Accept any 6-digit code for demo
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    Widget dashboard;
    switch (widget.userType) {
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF5F5), Color(0xFFFFEBEE)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Back Button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.red),
                  ),
                ),
                
                Expanded(
                  child: Center(
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
                            Text(
                              _isPhoneStep ? 'Enter Phone Number' : 'Enter Verification Code',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Subtitle
                            Text(
                              _isPhoneStep
                                  ? 'Verify your identity as a ${widget.userType.name}'
                                  : 'We sent a code to ${_phoneController.text}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            
                            // Input Fields
                            if (_isPhoneStep) ...[
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  hintText: '+1 (555) 123-4567',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  autofocus: true,

                                  
                                  onPressed: _phoneController.text.length >= 0
                                      ? _handleSendOTP
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    
                                    
                                  ),
                                  child: const Text('Send Verification Code'),
                                ),
                              ),
                            ] else ...[
                              // OTP Input
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(6, (index) {
                                  return SizedBox(
                                    width: 45,
                                    child: TextField(
                                      controller: _otpControllers[index],
                                      focusNode: _otpFocusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (value) {
                                        if (value.isNotEmpty && index < 5) {
                                          _otpFocusNodes[index + 1].requestFocus();
                                        }
                                      },
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _otpControllers
                                          .map((controller) => controller.text)
                                          .join()
                                          .length ==
                                      0
                                      ? _handleVerifyOTP
                                      : null,
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
                                  setState(() {
                                    _isPhoneStep = true;
                                  });
                                },
                                child: const Text(
                                  'Change Phone Number',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Demo mode: Use any 6-digit code for testing',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
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
  }
} 