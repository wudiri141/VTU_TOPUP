// lib/screens/login.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register.dart';
import 'dashboard.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../utils/app_colors.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _identityCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _secureStorage = FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  bool   _passwordVisible = false;
  bool   _loading         = false;
  bool   _biometricReady  = false;
  bool   _biometricLoading = false;
  String _savedIdentity   = ''; // email/phone saved from last login

  @override
  void initState() {
    super.initState();
    _loadSavedIdentity();
  }

  // Load saved identity (email or phone) from local storage
  Future<void> _loadSavedIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_identity') ?? '';
    final token = await _secureStorage.read(key: 'biometric_token');
    final userJson = await _secureStorage.read(key: 'biometric_user');
    final canUseBiometric = await _canUseBiometrics();
    if (mounted) {
      setState(() {
        _savedIdentity = saved;
        _biometricReady =
            saved.isNotEmpty && token != null && userJson != null && canUseBiometric;
      });
      // Pre-fill hidden field value (used when submitting)
      if (saved.isNotEmpty) _identityCtrl.text = saved;
    }
  }

  Future<bool> _canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  bool get _isReturning => _savedIdentity.isNotEmpty;

  // Clear saved identity — switch to different account
  Future<void> _switchUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_identity');
    await _secureStorage.delete(key: 'biometric_token');
    await _secureStorage.delete(key: 'biometric_user');
    setState(() {
      _savedIdentity = '';
      _biometricReady = false;
      _identityCtrl.clear();
      _passwordCtrl.clear();
    });
  }

  Map<String, dynamic> _userToJson(UserModel user) => {
        'id': user.id,
        'fullname': user.fullname,
        'email': user.email,
        'phone': user.phone,
        'wallet': user.wallet,
        'role': user.role,
        'referral_code': user.referralCode,
        'referral_count': user.referralCount,
        'referral_earnings': user.referralEarnings,
      };

  Future<void> _saveBiometricSession(UserModel user, String token) async {
    await _secureStorage.write(key: 'biometric_token', value: token);
    await _secureStorage.write(
        key: 'biometric_user', value: jsonEncode(_userToJson(user)));
    final canUseBiometric = await _canUseBiometrics();
    if (mounted) setState(() => _biometricReady = canUseBiometric);
  }

  Future<void> _loginWithBiometrics() async {
    if (!_biometricReady || _biometricLoading) return;
    setState(() => _biometricLoading = true);

    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Sign in to VTU TOPUP',
        options: AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!ok) {
        setState(() => _biometricLoading = false);
        return;
      }

      final token = await _secureStorage.read(key: 'biometric_token');
      final userJson = await _secureStorage.read(key: 'biometric_user');
      if (token == null || userJson == null) {
        throw Exception('Saved session not found.');
      }

      final user = UserModel.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
        token: token,
      );

      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => DashboardScreen(user: user)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Biometric sign in failed. Use your password.'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final identity = _isReturning
        ? _savedIdentity
        : _identityCtrl.text.trim();

    final res = await ApiService.login(
      identity: identity,
      password: _passwordCtrl.text,
    );

    setState(() => _loading = false);

    if (res['success'] == true) {
      final user = res['user'] as UserModel;

      // Save identity for next time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_identity', identity);
      await _saveBiometricSession(user, user.token);

      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => DashboardScreen(user: user)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Login failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _identityCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Shared input decoration ─────────────────────────────────
  InputDecoration _inputDec(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2)),
      labelStyle: TextStyle(color: AppColors.textMuted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                SizedBox(height: 48),

                // ── Logo centred ────────────────────────────
                Center(
                  child: Image.asset('assets/logo.png',
                      width: 90, height: 90),
                ),
                SizedBox(height: 24),

                // ── Returning user greeting / new user title ─
                if (_isReturning) ...[
                  // Greeting card
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary, width: 1.5),
                    ),
                    child: Row(children: [
                      // Avatar circle
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle),
                        child: Icon(Icons.person,
                            color: AppColors.white, size: 24),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back 👋',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted)),
                            SizedBox(height: 2),
                            Text(_savedIdentity,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      // Switch user button
                      GestureDetector(
                        onTap: _switchUser,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.pageBg,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: AppColors.border),
                          ),
                          child: Icon(Icons.swap_horiz,
                              color: AppColors.primary, size: 20),
                        ),
                      ),
                    ]),
                  ),
                  SizedBox(height: 20),

                  Text('Enter your password',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  SizedBox(height: 6),
                  Text('to continue to VTU TOPUP',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 14)),
                  SizedBox(height: 28),

                ] else ...[
                  // New user — show full title
                  Text('Sign In',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  SizedBox(height: 6),
                  Text('Welcome to VTU TOPUP',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 14)),
                  SizedBox(height: 28),

                  // Identity field — only for new users
                  TextFormField(
                    controller: _identityCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDec(
                        'Email or Phone Number', Icons.person_outline),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Enter your email or phone number'
                        : null,
                  ),
                  SizedBox(height: 16),
                ],

                // Password field — always shown
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: !_passwordVisible,
                  autofocus: _isReturning,
                  decoration: _inputDec(
                    'Password',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.grey,
                      ),
                      onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),

                SizedBox(height: 12),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(
                                initialEmail: _isReturning
                                    ? _savedIdentity
                                    : _identityCtrl.text.trim()))),
                    child: Text('Forgot Password?',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                SizedBox(height: 8),

                if (_isReturning && _biometricReady) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed:
                          _biometricLoading ? null : _loginWithBiometrics,
                      icon: Icon(Icons.fingerprint,
                          color: AppColors.primary, size: 24),
                      label: Text(
                          _biometricLoading
                              ? 'Checking...'
                              : 'Sign in with biometrics',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary, width: 1.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                ],

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                color: AppColors.textDark,
                                strokeWidth: 2))
                        : Text('Sign In',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                  ),
                ),

                SizedBox(height: 20),

                // Register link
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RegisterScreen())),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({this.initialEmail = ''});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail.contains('@') ? widget.initialEmail : '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final res = await ApiService.requestPasswordReset(
        email: _emailCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = res['success'] == true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Request completed'),
      backgroundColor: _sent ? Colors.green : AppColors.error,
    ));
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2)),
      labelStyle: TextStyle(color: AppColors.textMuted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: 28),
              Center(
                child: Image.asset('assets/logo.png', width: 86, height: 86),
              ),
              SizedBox(height: 28),
              Text('Forgot Password',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              SizedBox(height: 8),
              Text(
                  'Enter your email address and we will send you a password reset link.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              SizedBox(height: 28),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDec('Email Address', Icons.email_outlined),
                validator: (v) {
                  final email = v?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email address';
                  if (!email.contains('@')) return 'Enter a valid email address';
                  return null;
                },
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: AppColors.textDark, strokeWidth: 2))
                      : Text(_sent ? 'Send Again' : 'Send Reset Link',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                ),
              ),
              SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Back to Sign In',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
