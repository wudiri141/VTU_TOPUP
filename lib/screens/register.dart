// lib/screens/register.dart
import 'package:flutter/material.dart';
import 'login.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  @override _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _firstCtrl         = TextEditingController();
  final _lastCtrl          = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _phoneCtrl         = TextEditingController();
  final _passCtrl          = TextEditingController();
  final _confirmPassCtrl   = TextEditingController();
  final _pinCtrl           = TextEditingController();
  final _referralCtrl      = TextEditingController();
  bool _passVis            = false;
  bool _confirmPassVis     = false;
  bool _pinVis             = false;
  bool _loading            = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await ApiService.register(
      firstName:       _firstCtrl.text.trim(),
      lastName:        _lastCtrl.text.trim(),
      email:           _emailCtrl.text.trim(),
      phone:           _phoneCtrl.text.trim(),
      password:        _passCtrl.text,
      confirmPassword: _confirmPassCtrl.text,
      pin:             _pinCtrl.text,
      referralCode:    _referralCtrl.text.trim(),
    );

    setState(() => _loading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Registration successful!'),
        backgroundColor: Colors.green, duration: Duration(seconds: 5),
      ));
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => LoginScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Registration failed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF1E9BD7)),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF1E9BD7), width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(children: [
              SizedBox(height: sh * 0.10),
              CircleAvatar(radius: sh * 0.08,
                  backgroundImage: AssetImage('assets/logo.png')),
              SizedBox(height: sh * 0.02),
              Text("CREATE YOUR ACCOUNT",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: sh * 0.03),

              // First Name
              TextFormField(controller: _firstCtrl,
                decoration: _dec("First Name", Icons.person_outline),
                validator: (v) => v!.isEmpty ? 'Required' : null),
              SizedBox(height: sh * 0.02),

              // Last Name
              TextFormField(controller: _lastCtrl,
                decoration: _dec("Last Name", Icons.person_outline),
                validator: (v) => v!.isEmpty ? 'Required' : null),
              SizedBox(height: sh * 0.02),

              // Email
              TextFormField(controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec("Email", Icons.email_outlined),
                validator: (v) => !v!.contains('@') ? 'Invalid email' : null),
              SizedBox(height: sh * 0.02),

              // Phone
              TextFormField(controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _dec("Phone Number", Icons.phone_outlined),
                validator: (v) => v!.length < 10 ? 'Invalid phone' : null),
              SizedBox(height: sh * 0.02),

              // Password
              TextFormField(
                controller: _passCtrl,
                obscureText: !_passVis,
                decoration: _dec("Password", Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(_passVis ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey),
                    onPressed: () => setState(() => _passVis = !_passVis),
                  )),
                validator: (v) => v!.length < 6 ? 'Min 6 characters' : null),
              SizedBox(height: sh * 0.02),

              // Confirm Password
              TextFormField(
                controller: _confirmPassCtrl,
                obscureText: !_confirmPassVis,
                decoration: _dec("Confirm Password", Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(_confirmPassVis ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey),
                    onPressed: () => setState(() => _confirmPassVis = !_confirmPassVis),
                  )),
                validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null),
              SizedBox(height: sh * 0.02),

              // Transaction PIN
              TextFormField(
                controller: _pinCtrl,
                obscureText: !_pinVis,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: _dec("Transaction PIN (4 digits)", Icons.pin_outlined,
                  suffix: IconButton(
                    icon: Icon(_pinVis ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey),
                    onPressed: () => setState(() => _pinVis = !_pinVis),
                  )).copyWith(counterText: ''),
                validator: (v) => v!.length != 4 ? 'PIN must be 4 digits' : null),
              SizedBox(height: sh * 0.03),

              TextFormField(controller: _referralCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _dec("Referral Code (Optional)", Icons.card_giftcard_outlined),
                validator: (v) => null),
              SizedBox(height: sh * 0.03),

              // Register button
              SizedBox(
                width: double.infinity, height: sh * 0.07,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1E9BD7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text("Register", style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              SizedBox(height: sh * 0.01),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Already have an account? Login"),
              ),
              SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}
