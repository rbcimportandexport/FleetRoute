import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap_service.dart';

class AuthenticatedFleetUser {
  const AuthenticatedFleetUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.assignedVehicle = '',
  });

  final String uid;
  final String email;
  final String name;
  final String role;
  final String assignedVehicle;
}

class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();
  String? _phoneVerificationId;
  int? _phoneResendToken;

  /// Optional test handler for unit tests
  @visibleForTesting
  Future<AuthenticatedFleetUser> Function(String email, String password)?
      testAuthHandler;
  @visibleForTesting
  Future<AuthenticatedFleetUser> Function(String email, String password,
      String name, String role, String phone)? testSignUpHandler;
  @visibleForTesting
  Future<void> Function(String phoneNumber)? testSendPhoneOtpHandler;
  @visibleForTesting
  Future<AuthenticatedFleetUser> Function(String smsCode)?
      testVerifyPhoneOtpHandler;

  bool get isConfigured =>
      testAuthHandler != null || FirebaseBootstrapService.isInitialized;

  Future<AuthenticatedFleetUser> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'driver',
    String phone = '',
    String assignedVehicle = '',
  }) async {
    if (testSignUpHandler != null) {
      return testSignUpHandler!(email, password, name, role, phone);
    }
    if (!isConfigured) {
      throw StateError(
        'Authentication backend is not configured. Configure Firebase first.',
      );
    }
    final rawIdentifier = email.trim().toLowerCase();
    final normalizedEmail = rawIdentifier.contains('@')
        ? rawIdentifier
        : '$rawIdentifier@transport.one';
    UserCredential credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      if (name.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(name.trim());
      }
    } on FirebaseAuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
    // A newly self-created account has no trusted fleet role. Authorization
    // must come from server-side custom claims set by the admin backend.
    return _authorizedUser(credential.user, fallbackEmail: normalizedEmail);
  }

  Future<AuthenticatedFleetUser> signIn({
    required String email,
    required String password,
  }) async {
    if (testAuthHandler != null) {
      return testAuthHandler!(email, password);
    }
    if (!isConfigured) {
      throw StateError(
        'Secure login backend is not configured. Configure Firebase first.',
      );
    }
    final rawIdentifier = email.trim().toLowerCase();
    final normalizedEmail = rawIdentifier.contains('@')
        ? rawIdentifier
        : '$rawIdentifier@transport.one';
    UserCredential credential;
    try {
      credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
    return _authorizedUser(credential.user, fallbackEmail: normalizedEmail);
  }

  Future<void> sendPhoneOtp(String phoneNumber) async {
    if (testSendPhoneOtpHandler != null) {
      return testSendPhoneOtpHandler!(phoneNumber);
    }
    if (!isConfigured) {
      throw StateError('Firebase Phone Auth configured nahi hai.');
    }
    final completer = Completer<void>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: _phoneResendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(StateError(_friendlyAuthError(error)));
        }
      },
      codeSent: (verificationId, resendToken) {
        _phoneVerificationId = verificationId;
        _phoneResendToken = resendToken;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _phoneVerificationId = verificationId;
      },
    );
    return completer.future;
  }

  Future<AuthenticatedFleetUser> verifyPhoneOtp(String smsCode) async {
    if (testVerifyPhoneOtpHandler != null) {
      return testVerifyPhoneOtpHandler!(smsCode);
    }
    final verificationId = _phoneVerificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw StateError('Pehle SMS OTP bhejein.');
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      return await _authorizedUser(result.user);
    } on FirebaseAuthException catch (error) {
      throw StateError(_friendlyAuthError(error));
    }
  }

  Future<AuthenticatedFleetUser> _authorizedUser(
    User? user, {
    String fallbackEmail = '',
  }) async {
    if (user == null) {
      throw StateError('Authentication completed without a user account.');
    }
    final token = await user.getIdTokenResult(true);
    final claims = token.claims ?? const <String, dynamic>{};
    final rawRole = claims['role']?.toString().trim().toLowerCase() ?? '';
    final role = rawRole == 'super_admin' ? 'admin' : rawRole;
    if (role != 'admin' && role != 'driver') {
      await FirebaseAuth.instance.signOut();
      throw StateError(
        'Account fleet ke liye authorized nahi hai. Admin se role assign karwayein.',
      );
    }
    final assignedVehicle = claims['assignedVehicle']?.toString().trim() ?? '';

    return AuthenticatedFleetUser(
      uid: user.uid,
      email: user.email ?? fallbackEmail,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (claims['name']?.toString().trim().isNotEmpty == true
              ? claims['name'].toString().trim()
              : (fallbackEmail.contains('@')
                  ? fallbackEmail.split('@').first
                  : (user.phoneNumber ?? 'Fleet User'))),
      role: role,
      assignedVehicle: assignedVehicle,
    );
  }

  static String _friendlyAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' =>
        'Wrong password. Kripya sahi password dalein.',
      'user-not-found' =>
        'Account nahi mila. Phone/Email check karein.',
      'email-already-in-use' =>
        'Yeh email / account pehle se registered hai. Kripya login karein.',
      'weak-password' => 'Password kam se kam 6-8 characters ka hona chahiye.',
      'invalid-email' => 'Email address valid nahi hai.',
      'user-disabled' => 'Yeh account Firebase me disabled hai.',
      'network-request-failed' =>
        'Network connection failed. Internet check karke dobara try karein.',
      'too-many-requests' =>
        'Bahut zyada attempts hue. Thodi der baad dobara try karein.',
      'operation-not-allowed' =>
        'Firebase Console me yeh sign-in method enable nahi hai.',
      'invalid-verification-code' => 'SMS OTP galat ya expire ho gaya hai.',
      'quota-exceeded' => 'Firebase SMS quota khatam ho gaya hai.',
      'configuration-not-found' =>
        'Wrong password ya account not found. Credentials check karein.',
      _ => error.message?.contains('CONFIGURATION_NOT_FOUND') == true
          ? 'Wrong password ya account not found. Credentials check karein.'
          : (error.message ??
              'Firebase authentication failed (${error.code}).'),
    };
  }

  Future<AuthenticatedFleetUser?> restoreSession() async {
    if (!FirebaseBootstrapService.isInitialized) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdTokenResult();
    final claims = token.claims ?? const <String, dynamic>{};
    final rawRole = claims['role']?.toString().trim().toLowerCase() ?? '';
    final role = rawRole == 'super_admin' ? 'admin' : rawRole;
    if (role != 'admin' && role != 'driver') {
      await FirebaseAuth.instance.signOut();
      return null;
    }
    final assignedVehicle = claims['assignedVehicle']?.toString().trim() ?? '';

    return AuthenticatedFleetUser(
      uid: user.uid,
      email: user.email ??
          (user.phoneNumber != null ? '${user.phoneNumber}@transport.one' : ''),
      name: user.displayName ??
          claims['name']?.toString() ??
          (role == 'admin' ? 'Fleet Admin' : 'Fleet Driver'),
      role: role,
      assignedVehicle: assignedVehicle,
    );
  }

  Future<String?> idToken() async {
    if (testAuthHandler != null) {
      return 'test_jwt_token_for_tests';
    }
    if (!FirebaseBootstrapService.isInitialized) return null;
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<void> signOut() async {
    if (testAuthHandler != null) return;
    if (FirebaseBootstrapService.isInitialized) {
      await FirebaseAuth.instance.signOut();
    }
  }
}
