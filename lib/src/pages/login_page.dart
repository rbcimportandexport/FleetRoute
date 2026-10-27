import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/planner_controller.dart';
import '../services/app_localization_service.dart';
import '../services/whatsapp_otp_service.dart';
import '../theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.controller,
    this.onLoginSuccess,
    this.initialUseOtpMode = false,
    super.key,
  });

  final PlannerController controller;
  final VoidCallback? onLoginSuccess;
  final bool initialUseOtpMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  // Registration controllers
  final _nameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regVehicleController = TextEditingController();
  String _selectedRole = 'driver'; // 'driver' or 'admin'

  bool _isSignUp = false; // toggle between Sign In and Sign Up
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  // Firebase email/password is the production authentication path.
  late bool _useOtpMode = widget.initialUseOtpMode;
  bool _otpSent = false;
  bool _isSendingOtp = false;

  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendCountdown = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _regPhoneController.dispose();
    _regVehicleController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _regPhoneController.text.trim();
    final vehicle = _regVehicleController.text.trim().toUpperCase();

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Kripya apna Pura Naam (Full Name) enter karein.';
      });
      return;
    }

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Kripya apna Email ID ya Username enter karein.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password kam se kam 6 characters ka hona chahiye.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final error = await widget.controller.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        role: _selectedRole,
        assignedVehicle: vehicle,
      );

      if (!mounted) return;

      if (error != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isSignUp = false;
          _useOtpMode = false;
          _selectedRole = 'driver';
          _errorMessage = null;
          _infoMessage = 'Account ban gaya! Kripya Login karein.';
        });
        _phoneController.text = email;
        _passwordController.text = password;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Registration failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSendSmsOtp() async {
    final rawPhone = _phoneController.text.trim();
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(() {
        _errorMessage = 'Kripya apna 10-digit Phone Number enter karein.';
      });
      return;
    }

    final tenDigits = digits.substring(digits.length - 10);
    _phoneController.text = tenDigits;

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final result = await WhatsAppOtpService.instance.sendOtp(
      phoneNumber: tenDigits,
    );
    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
      if (result['success'] == true) {
        _otpSent = true;
        _infoMessage = result['message']?.toString() ??
            'WhatsApp OTP +91$tenDigits par bheja gaya.';
        _startResendTimer();
      } else {
        _errorMessage =
            result['message']?.toString() ?? 'WhatsApp OTP send nahi hua.';
      }
    });
  }

  Future<void> _handleVerifySmsOtp() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() {
        _errorMessage = 'Kripya SMS me aaya OTP enter karein.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await WhatsAppOtpService.instance.verifyOtpRemote(
        phoneNumber: _phoneController.text,
        enteredOtp: otp,
      );
      final error = result['success'] == true
          ? await widget.controller.loginWithTrustedWhatsAppOtp(result)
          : (result['message']?.toString() ??
              'WhatsApp OTP verification failed.');
      if (!mounted) return;

      if (error != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_useOtpMode) {
      if (!_otpSent) {
        await _handleSendSmsOtp();
      } else {
        await _handleVerifySmsOtp();
      }
      return;
    }

    final email = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your Firebase account email.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final error = await widget.controller.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (error != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalizationService.instance.currentLanguage,
      builder: (context, currentLang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: SafeArea(
            child: Column(
              children: [
                // Top Header Bar with Language Switcher (Full Upper Side)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AppLanguage>(
                          value: currentLang,
                          isDense: true,
                          items: AppLanguage.values.map((lang) {
                            return DropdownMenuItem(
                              value: lang,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.language_rounded,
                                      size: 15, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${lang.code} (${lang.label})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newLang) {
                            if (newLang != null) {
                              AppLocalizationService.instance
                                  .setLanguage(newLang);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // App Brand Header
                            Center(
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF16A34A),
                                      Color(0xFF15803D)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x3316A34A),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Center(
                              child: Text(
                                'TRANSPORT ONE',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Center(
                              child: Text(
                                'Fleet Operations & Route Intelligence',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Login Card (Light Theme)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x120F2440),
                                    blurRadius: 24,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Error Banner if present
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFFFCA5A5),
                                            width: 1),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.error_outline_rounded,
                                              color: Color(0xFFDC2626),
                                              size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(
                                                color: Color(0xFFDC2626),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Info / Success Banner if present
                                  if (_infoMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFF86EFAC),
                                            width: 1),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              color: Color(0xFF16A34A),
                                              size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _infoMessage!,
                                              style: const TextStyle(
                                                color: Color(0xFF16A34A),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  if (!_isSignUp) ...[
                                    // Mode Selector Tab (WhatsApp OTP vs Password / PIN)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _useOtpMode = true;
                                                  _errorMessage = null;
                                                  if (_phoneController.text
                                                      .contains('@')) {
                                                    _phoneController.clear();
                                                  } else {
                                                    // Keep digits only
                                                    final digits =
                                                        _phoneController.text
                                                            .replaceAll(
                                                                RegExp(r'\D'),
                                                                '');
                                                    if (digits.length >= 10) {
                                                      _phoneController.text =
                                                          digits.substring(
                                                              digits.length -
                                                                  10);
                                                    }
                                                  }
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: _useOtpMode
                                                      ? Colors.white
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(9),
                                                  boxShadow: _useOtpMode
                                                      ? const [
                                                          BoxShadow(
                                                            color: Color(
                                                                0x14000000),
                                                            blurRadius: 4,
                                                            offset:
                                                                Offset(0, 1),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .chat_bubble_outline_rounded,
                                                        size: 14,
                                                        color: _useOtpMode
                                                            ? const Color(
                                                                0xFF25D366)
                                                            : const Color(
                                                                0xFF64748B),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          AppLocalizationService
                                                              .instance
                                                              .tr('whatsapp_otp'),
                                                          style: TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight:
                                                                _useOtpMode
                                                                    ? FontWeight
                                                                        .w700
                                                                    : FontWeight
                                                                        .w500,
                                                            color: _useOtpMode
                                                                ? AppColors.navy
                                                                : const Color(
                                                                    0xFF64748B),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _useOtpMode = false;
                                                  _errorMessage = null;
                                                  _phoneController.clear();
                                                  _passwordController.clear();
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: !_useOtpMode
                                                      ? Colors.white
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(9),
                                                  boxShadow: !_useOtpMode
                                                      ? const [
                                                          BoxShadow(
                                                            color: Color(
                                                                0x14000000),
                                                            blurRadius: 4,
                                                            offset:
                                                                Offset(0, 1),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .lock_outline_rounded,
                                                        size: 14,
                                                        color: !_useOtpMode
                                                            ? AppColors.blue
                                                            : const Color(
                                                                0xFF64748B),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          AppLocalizationService
                                                              .instance
                                                              .tr('password_pin'),
                                                          style: TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight:
                                                                !_useOtpMode
                                                                    ? FontWeight
                                                                        .w700
                                                                    : FontWeight
                                                                        .w500,
                                                            color: !_useOtpMode
                                                                ? AppColors.navy
                                                                : const Color(
                                                                    0xFF64748B),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],

                                  // Registration Fields
                                  if (_isSignUp) ...[
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.arrow_back_rounded,
                                              color: AppColors.navy,
                                              size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _isSignUp = false;
                                              _errorMessage = null;
                                              _infoMessage = null;
                                            });
                                          },
                                          tooltip: 'Back to Login',
                                        ),
                                        const SizedBox(width: 4),
                                        const Expanded(
                                          child: Text(
                                            'Naya Account Banayein',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.navy,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Full Name
                                    const Text(
                                      'Full Name (पूरा नाम)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _nameController,
                                      keyboardType: TextInputType.name,
                                      style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. Ramesh Kumar',
                                        hintStyle: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13),
                                        prefixIcon: const Icon(
                                          Icons.badge_outlined,
                                          color: Color(0xFF64748B),
                                          size: 18,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF16A34A),
                                              width: 1.5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // Phone Number
                                    const Text(
                                      'Mobile Number (मोबाइल नंबर)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _regPhoneController,
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                      decoration: InputDecoration(
                                        hintText: '10-digit Mobile',
                                        hintStyle: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13),
                                        prefixIcon: const Icon(
                                          Icons.phone_android_rounded,
                                          color: Color(0xFF64748B),
                                          size: 18,
                                        ),
                                        prefixText: '+91 ',
                                        prefixStyle: const TextStyle(
                                          color: AppColors.navy,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF16A34A),
                                              width: 1.5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // Assigned Vehicle (for driver role)
                                    if (_selectedRole == 'driver') ...[
                                      const Text(
                                        'Assigned Vehicle / Truck (गाड़ी नंबर - Optional)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _regVehicleController,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        style: const TextStyle(
                                            color: AppColors.navy,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. MH-12-RN-8841',
                                          hintStyle: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13),
                                          prefixIcon: const Icon(
                                            Icons.directions_bus_outlined,
                                            color: Color(0xFF64748B),
                                            size: 18,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: Color(0xFFE2E8F0)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: Color(0xFFE2E8F0)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: Color(0xFF16A34A),
                                                width: 1.5),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  ],

                                  // Phone Number / Login ID / Email Input
                                  Text(
                                    _isSignUp
                                        ? 'Email ID / Account ID (लॉग इन आईडी)'
                                        : (_useOtpMode
                                            ? AppLocalizationService.instance
                                                .tr('phone_number')
                                            : AppLocalizationService.instance
                                                .tr('driver_id_or_email')),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _phoneController,
                                    autofillHints: const <String>[],
                                    keyboardType: (!_isSignUp && _useOtpMode)
                                        ? TextInputType.phone
                                        : TextInputType.emailAddress,
                                    style: const TextStyle(
                                        color: AppColors.navy,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      hintText: _isSignUp
                                          ? 'driver@transport.com or user@gmail.com'
                                          : (_useOtpMode
                                              ? AppLocalizationService.instance
                                                  .tr('enter_mobile_hint')
                                              : 'Mobile / Driver Name / Admin ID'),
                                      hintStyle: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13),
                                      prefixIcon: Icon(
                                        (!_isSignUp && _useOtpMode)
                                            ? Icons.phone_android_rounded
                                            : Icons.alternate_email_rounded,
                                        color: const Color(0xFF64748B),
                                        size: 18,
                                      ),
                                      prefixText: (!_isSignUp && _useOtpMode)
                                          ? '+91 '
                                          : null,
                                      prefixStyle: const TextStyle(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: _isSignUp
                                                ? const Color(0xFF16A34A)
                                                : AppColors.blue,
                                            width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // WhatsApp OTP Field (When in OTP mode and sent)
                                  if (!_isSignUp &&
                                      _useOtpMode &&
                                      _otpSent) ...[
                                    const Text(
                                      'WhatsApp OTP Code',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _otpController,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      style: const TextStyle(
                                        color: AppColors.navy,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 4,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: '6-digit OTP',
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13,
                                          letterSpacing: 0,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.verified_user_outlined,
                                          color: Color(0xFF25D366),
                                          size: 18,
                                        ),
                                        suffixIcon: TextButton(
                                          onPressed: (_isSendingOtp ||
                                                  _resendCountdown > 0)
                                              ? null
                                              : _handleSendSmsOtp,
                                          child: Text(
                                            _resendCountdown > 0
                                                ? 'Resend in ${_resendCountdown}s'
                                                : 'Resend',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: (_isSendingOtp ||
                                                      _resendCountdown > 0)
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF25D366),
                                              width: 1.5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Firebase password input
                                  if (_isSignUp || !_useOtpMode) ...[
                                    Text(
                                      _isSignUp
                                          ? 'Create Password (नया पासवर्ड)'
                                          : AppLocalizationService.instance
                                              .tr('password_label'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _passwordController,
                                      autofillHints: const <String>[],
                                      obscureText: _obscurePassword,
                                      style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                      onSubmitted: (_) => _isSignUp
                                          ? _handleRegister()
                                          : _handleLogin(),
                                      decoration: InputDecoration(
                                        hintText: _isSignUp
                                            ? 'Min. 6 characters'
                                            : AppLocalizationService.instance
                                                .tr('enter_password_hint'),
                                        hintStyle: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13),
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                          color: Color(0xFF64748B),
                                          size: 18,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: const Color(0xFF64748B),
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: _isSignUp
                                                  ? const Color(0xFF16A34A)
                                                  : AppColors.blue,
                                              width: 1.5),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  const SizedBox(height: 6),

                                  // Action Button (Sign In OR Create Account)
                                  SizedBox(
                                    height: 48,
                                    child: FilledButton(
                                      onPressed: (_isLoading || _isSendingOtp)
                                          ? null
                                          : (_isSignUp
                                              ? _handleRegister
                                              : _handleLogin),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _isSignUp
                                            ? const Color(0xFF16A34A)
                                            : (_useOtpMode
                                                ? const Color(0xFF059669)
                                                : AppColors.blue),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: (_isLoading || _isSendingOtp)
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _isSignUp
                                                      ? Icons
                                                          .check_circle_outline_rounded
                                                      : (_useOtpMode
                                                          ? (_otpSent
                                                              ? Icons
                                                                  .verified_rounded
                                                              : Icons
                                                                  .chat_rounded)
                                                          : Icons
                                                              .arrow_forward_rounded),
                                                  size: 17,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    _isSignUp
                                                        ? 'Register & Sign In'
                                                        : (_useOtpMode
                                                            ? (_otpSent
                                                                ? AppLocalizationService
                                                                    .instance
                                                                    .tr(
                                                                        'verify_and_sign_in')
                                                                : AppLocalizationService
                                                                    .instance
                                                                    .tr(
                                                                        'send_otp'))
                                                            : AppLocalizationService
                                                                .instance
                                                                .tr('sign_in')),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  const SizedBox(height: 6),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.verified_user_rounded,
                                        size: 13,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          AppLocalizationService.instance
                                              .tr('auto_login_enabled'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ── Register / Login Toggle ──────────────────────
                            if (!_isSignUp)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Account nahi hai? ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isSignUp = true;
                                        _errorMessage = null;
                                        _infoMessage = null;
                                        _nameController.clear();
                                        _regPhoneController.clear();
                                        _regVehicleController.clear();
                                        _phoneController.clear();
                                        _passwordController.clear();
                                        _selectedRole = 'driver';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFF86EFAC)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.person_add_outlined,
                                              size: 14,
                                              color: Color(0xFF16A34A)),
                                          SizedBox(width: 5),
                                          Text(
                                            'Naya Account Banayein',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF16A34A),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Pehle se account hai? ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isSignUp = false;
                                        _errorMessage = null;
                                        _infoMessage = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFF93C5FD)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.login_rounded,
                                              size: 14,
                                              color: Color(0xFF2563EB)),
                                          SizedBox(width: 5),
                                          Text(
                                            'Login Karein',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF2563EB),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 20),
                            // App Version Footer
                            const Center(
                              child: Text(
                                'Transport One Fleet Security & Management Console',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
