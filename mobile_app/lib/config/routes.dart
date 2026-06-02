import 'package:flutter/material.dart';

// Splash & Auth
import '../features/splash_screen.dart';
import '../features/login_screen.dart';
import '../features/signup_screen.dart';

// Main Screens
import '../features/home_screen.dart';
import '../features/notification.dart';
import '../features/cart.dart';
import '../features/account.dart';
import '../features/edit_profile.dart';
import '../features/ChatbotScreen.dart';
import '../features/Category.dart';

final Map<String, WidgetBuilder> routes = {
  // Initial
  '/': (context) => const SplashScreen(),

  // Auth
  '/login': (context) => const LoginScreen(),
  '/signup': (context) => const SignUpScreen(),

  // Home
  '/home': (context) => const HomeScreen(),

  // Drawer / Bottom Nav Screens
  '/notifications': (context) => const NotificationScreen(),
  '/cart': (context) => const CartScreen(),
  '/account': (context) => const AccountMenuScreen(),

  // Account
  '/edit_profile': (context) => const AccountScreen(),
  '/chatbot': (context) => const ChatbotScreen(),
   '/category': (context) => const CategoryScreen(),
};
