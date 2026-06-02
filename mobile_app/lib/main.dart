import 'package:flutter/material.dart';
import 'features/splash_screen.dart';
import 'features/login_screen.dart';
import 'features/signup_screen.dart';
import 'features/home_screen.dart';
import 'features/notification.dart';
import 'features/cart.dart';
import 'features/account.dart';
import 'features/edit_profile.dart';
import 'features/ChatbotScreen.dart';
import 'features/category_screen.dart'; // Updated import
import 'features/favorites_screen.dart'; // Added import
import 'features/product_details_screen.dart'; // Added import
import 'features/history_screen.dart';
import 'features/order_history_products_screen.dart';

void main() {
  runApp(const ZarvaApp());
}

class ZarvaApp extends StatelessWidget {
  const ZarvaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 👇 App starts from Splash Screen
      initialRoute: '/',

      // 👇 All routes defined here
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
        '/notifications': (context) => const NotificationScreen(),
        '/cart': (context) => const CartScreen(),
        '/account': (context) => const AccountMenuScreen(),
        '/edit_profile': (context) => const AccountScreen(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/category': (context) => const CategoryScreen(),
        '/favorites': (context) => const FavoritesScreen(), // Added route
        '/history': (context) => const HistoryScreen(),
        '/order_history_products': (context) => const OrderHistoryProductsScreen(),
        '/product_details': (context) => ProductDetailsScreen(product: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>),
      },
    );
  }
}
