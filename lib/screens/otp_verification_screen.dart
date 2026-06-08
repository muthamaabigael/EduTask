// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/top_alert.dart';
import 'signup_success_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 6) {
      showTopAlert(
        context,
        'Enter the 6-digit OTP sent to your email.',
        success: false,
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    final isValid = await AuthService.instance.verifyOtp(code);

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
    });

    if (isValid) {
      showTopAlert(
        context,
        'Your account has been created successfully.',
        success: true,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const SignupSuccessScreen(),
        ),
      );
    } else {
      showTopAlert(
        context,
        'OTP verification failed. Please try again.',
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.pendingEmail ?? 'Example@domain.com';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 110,
                  height: 110,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verify OTP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please enter the code we just sent to your Email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(letterSpacing: 16),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: const TextStyle(letterSpacing: 16, fontSize: 24),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF7F9FF),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isVerifying
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final success = await AuthService.instance.resendOtp();
                    if (!mounted) return;
                    final activeContext = context;
                    final message = success
                        ? 'OTP resent to $email.'
                        : 'Unable to resend OTP right now.';
                    showTopAlert(
                      activeContext,
                      message,
                      success: success,
                    );
                  },
                  child: const Text(
                    'Didn’t Receive OTP? Resend Code.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
