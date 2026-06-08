import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  // When running on an emulator, 10.0.2.2 maps to the host PC.
  // When running on a physical Android device, replace this with your PC's LAN IP.
  // Example: http://192.168.1.100:3000
  //static const String _backendBaseUrl = 'http://10.0.2.2:3000';
  static const String _backendBaseUrl = 'http://10.1.1.51:3000';

  String? _pendingEmail;
  String? _pendingFirstName;
  String? _pendingLastName;
  String? _pendingPassword;
  DateTime? _pendingDob;

  Future<void> sendOtp({
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    required DateTime dob,
  }) async {
    final uri = Uri.parse('$_backendBaseUrl/api/send-otp');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'password': password,
        'dob': dob.toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      String message = 'OTP send failed';
      try {
        final body = jsonDecode(response.body);
        message = body['message']?.toString() ?? message;
      } catch (_) {
        if (response.body.isNotEmpty) {
          message = response.body;
        }
      }
      throw Exception('$message (${response.statusCode})');
    }

    _pendingEmail = email.trim();
    _pendingFirstName = firstName.trim();
    _pendingLastName = lastName.trim();
    _pendingPassword = password;
    _pendingDob = dob;
  }

  Future<bool> verifyOtp(String code) async {
    if (_pendingEmail == null) {
      return false;
    }

    final uri = Uri.parse('$_backendBaseUrl/api/verify-otp');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': _pendingEmail,
        'code': code,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', _pendingEmail ?? '');
    await prefs.setString('user_first_name', _pendingFirstName ?? '');
    await prefs.setString('user_last_name', _pendingLastName ?? '');
    await prefs.setString('user_dob', _pendingDob?.toIso8601String() ?? '');
    await prefs.setString('user_registered_at', DateTime.now().toIso8601String());

    _clearPending();
    return true;
  }

  Future<bool> login(String email, String password) async {
    final uri = Uri.parse('$_backendBaseUrl/api/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final body = jsonDecode(response.body);
    if (body['success'] != true) {
      return false;
    }

    final user = body['user'] as Map<String, dynamic>?;
    if (user == null) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', user['email'] ?? email);
    await prefs.setString('user_first_name', user['firstName'] ?? '');
    await prefs.setString('user_last_name', user['lastName'] ?? '');
    await prefs.setString('user_dob', user['dob'] ?? '');
    await prefs.setString('user_registered_at', user['registeredAt'] ?? '');
    await prefs.setString('user_phone_number', user['phoneNumber'] ?? '');

    return true;
  }

  Future<bool> requestPasswordReset(String email) async {
    final uri = Uri.parse('$_backendBaseUrl/api/password-reset-request');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return response.statusCode == 200;
  }

  Future<bool> confirmPasswordReset(String email, String code, String password) async {
    final uri = Uri.parse('$_backendBaseUrl/api/password-reset-confirm');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'password': password,
      }),
    );
    return response.statusCode == 200;
  }

  Future<bool> updateProfile(String firstName, String lastName, String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email == null || email.isEmpty) {
      return false;
    }

    final uri = Uri.parse('$_backendBaseUrl/api/update-profile');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final body = jsonDecode(response.body);
    if (body['success'] != true) {
      return false;
    }

    final user = body['user'] as Map<String, dynamic>?;
    if (user == null) {
      return false;
    }

    final prefs2 = await SharedPreferences.getInstance();
    await prefs2.setString('user_first_name', user['firstName'] ?? '');
    await prefs2.setString('user_last_name', user['lastName'] ?? '');
    final phoneKey = _phoneKeyFor(email);
    await prefs2.setString(phoneKey, user['phoneNumber'] ?? '');
    return true;
  }

  Future<bool> hasRegisteredUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user_email');
  }

  Future<Map<String, String>> getRegisteredUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('user_email') ?? '',
      'firstName': prefs.getString('user_first_name') ?? '',
      'lastName': prefs.getString('user_last_name') ?? '',
      'dob': prefs.getString('user_dob') ?? '',
      'registeredAt': prefs.getString('user_registered_at') ?? '',
      'phoneNumber': prefs.getString(_phoneKeyFor(prefs.getString('user_email') ?? '')) ?? '',
      'profileImagePath': prefs.getString(_profileKeyFor(prefs.getString('user_email') ?? '')) ?? '',
    };
  }

  Future<String?> getProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    return prefs.getString(_profileKeyFor(email));
  }

  Future<void> saveProfileImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    await prefs.setString(_profileKeyFor(email), path);
  }

  Future<void> clearStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_first_name');
    await prefs.remove('user_last_name');
    await prefs.remove('user_dob');
    await prefs.remove('user_registered_at');
    await prefs.remove('user_phone_number');
    final email = prefs.getString('user_email') ?? '';
    await prefs.remove(_profileKeyFor(email));
    await prefs.remove(_phoneKeyFor(email));
  }

  String _profileKeyFor(String email) {
    if (email.isEmpty) return 'user_profile_path';
    final safe = email.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
    return 'user_profile_path_$safe';
  }

  String _phoneKeyFor(String email) {
    if (email.isEmpty) return 'user_phone_number';
    final safe = email.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
    return 'user_phone_number_$safe';
  }

  String? get pendingEmail => _pendingEmail;
  String? get pendingFirstName => _pendingFirstName;
  String? get pendingLastName => _pendingLastName;
  DateTime? get pendingDob => _pendingDob;

  void _clearPending() {
    _pendingEmail = null;
    _pendingFirstName = null;
    _pendingLastName = null;
    _pendingPassword = null;
    _pendingDob = null;
  }

  Future<bool> resendOtp() async {
    if (_pendingEmail == null || _pendingFirstName == null || _pendingLastName == null || _pendingPassword == null || _pendingDob == null) {
      return false;
    }

    try {
      await sendOtp(
        email: _pendingEmail!,
        firstName: _pendingFirstName!,
        lastName: _pendingLastName!,
        password: _pendingPassword!,
        dob: _pendingDob!,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
