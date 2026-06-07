import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../utils/auth_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), checkLogin);
  }

  void checkLogin() async {
    final authed = await AuthHelper.isAuthenticated();

    if (!mounted) return;

    if (authed) {
      await CartService().reloadForCurrentUser();
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      await CartService().clearGuestCart();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1C2D), // Dark blue background
      body: Center(
        child: Image.asset(
          'assets/new logo.png',
          width: 350,
          height: 350,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

}
