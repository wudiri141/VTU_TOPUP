// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'screens/login.dart';
import 'screens/register.dart';
import 'services/notification_service.dart';
import 'utils/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VTU TOPUP',
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.pageBg,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textDark,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
      home: SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SPLASH — checks if first-time user
// ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await Future.delayed(Duration(seconds: 2));

    // Check if user has seen onboarding before
    final prefs = await SharedPreferences.getInstance();
    final seen  = prefs.getBool('onboarding_done') ?? false;

    if (!mounted) return;

    if (seen) {
      // Returning user — go straight to login (no onboarding, no welcome)
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => LoginScreen()));
    } else {
      // First-time user — show onboarding
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => OnboardingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Image.asset('assets/logo.png', width: 180, height: 180),
            SizedBox(height: 16),
            Text('VTU TOPUP',
                style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            Spacer(),
            Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation(AppColors.textDark),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ONBOARDING — shown ONLY on first install
// ─────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page   = 0;

  final _pages = [
    {
      'title': 'Buy Airtime',
      'sub':   'Recharge any network instantly',
      'icon':  Icons.phone_iphone,
    },
    {
      'title': 'Buy Data',
      'sub':   'Affordable data in seconds',
      'icon':  Icons.sim_card,
    },
    {
      'title': 'Pay Bills',
      'sub':   'Electricity & subscription',
      'icon':  Icons.receipt_long,
    },
    {
      'title': 'Cable TV',
      'sub':   'Pay your cable TV subscription',
      'icon':  Icons.tv,
    },
  ];

  Future<void> _done() async {
    // Mark onboarding as seen so it never shows again
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => WelcomeScreen()));
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      _done();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onboardBg,
      body: SafeArea(
        child: Column(children: [
          // SKIP
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(top: 16, right: 20),
              child: TextButton(
                onPressed: _done,
                child: Text('SKIP',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        fontSize: 15)),
              ),
            ),
          ),

          // Pages
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final p = _pages[i];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 160, height: 160,
                          decoration: BoxDecoration(
                              color: AppColors.iconBg,
                              shape: BoxShape.circle),
                          child: Icon(p['icon'] as IconData,
                              size: 80, color: AppColors.primary),
                        ),
                        SizedBox(height: 36),
                        Text(p['title'] as String,
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                        SizedBox(height: 12),
                        Text(p['sub'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textMuted,
                                height: 1.5)),
                      ]),
                );
              },
            ),
          ),

          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              return AnimatedContainer(
                duration: Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i
                      ? AppColors.primary
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          SizedBox(height: 32),

          // Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  _page == _pages.length - 1
                      ? 'GET STARTED'
                      : 'NEXT',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: 1),
                ),
              ),
            ),
          ),

          SizedBox(height: 36),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WELCOME — shown only after onboarding, before login
// ─────────────────────────────────────────────────────────────
class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(children: [
          SizedBox(height: sh * 0.10),

          // Logo
          Image.asset('assets/logo.png',
              width: sh * 0.16, height: sh * 0.16),

          SizedBox(height: sh * 0.06),

          Text('Welcome to',
              style: TextStyle(
                  fontSize: 22,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w400)),
          SizedBox(height: 6),
          Text('VTU TOPUP',
              style: TextStyle(
                  fontSize: 36,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),

          SizedBox(height: sh * 0.04),

          // Description
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4, height: 72,
                  decoration: BoxDecoration(
                      color: AppColors.textDark.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Discover seamless voice and data transmission '
                    'services. Buy airtime, data, electricity and '
                    'cable TV subscriptions instantly.',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark.withOpacity(0.75),
                        height: 1.6),
                  ),
                ),
              ],
            ),
          ),

          Spacer(),

          // Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              // Sign Up — white
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => RegisterScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text('Sign Up',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ),
              ),
              SizedBox(height: 12),
              // Sign In — faded/outlined
              SizedBox(
                width: double.infinity, height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => LoginScreen())),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.textDark.withOpacity(0.4),
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Sign In',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ),
              ),
            ]),
          ),

          SizedBox(height: 40),
        ]),
      ),
    );
  }
}
