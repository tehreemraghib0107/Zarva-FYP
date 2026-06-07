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
import 'widgets/auth_gate.dart';
import 'config/route_observer.dart';

void main() {
  runApp(const ZarvaApp());
}

class ZarvaApp extends StatelessWidget {
  const ZarvaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],

      // 👇 App starts from Splash Screen
      initialRoute: '/',

      // 👇 All routes defined here
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const LoginRequiredGate(child: HomeScreen()),
        '/notifications': (context) => const LoginRequiredGate(child: NotificationScreen()),
        '/cart': (context) => const LoginRequiredGate(child: CartScreen()),
        '/account': (context) => const LoginRequiredGate(child: AccountMenuScreen()),
        '/edit_profile': (context) => const LoginRequiredGate(child: AccountScreen()),
        '/chatbot': (context) => const LoginRequiredGate(child: ChatbotScreen()),
        '/category': (context) => const LoginRequiredGate(child: CategoryScreen()),
        '/favorites': (context) => const LoginRequiredGate(child: FavoritesScreen()),
        '/history': (context) => const LoginRequiredGate(child: HistoryScreen()),
        '/order_history_products': (context) => const OrderHistoryProductsScreen(),
        '/product_details': (context) => LoginRequiredGate(
          child: ProductDetailsScreen(
            product: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
          ),
        ),
      },
    );
  }
}
