import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
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
import 'features/settings_screen.dart';
import 'features/help_center_screen.dart';
import 'features/about_us_screen.dart';
import 'widgets/auth_gate.dart';
import 'config/route_observer.dart';
import 'services/theme_service.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const ZarvaApp(),
    ),
  );
}

class ZarvaApp extends StatelessWidget {
  const ZarvaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorObservers: [appRouteObserver],
            theme: themeService.getLightTheme(),
            darkTheme: themeService.getDarkTheme(),
            themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            useInheritedMediaQuery: true,
            locale: DevicePreview.locale(context),
            builder: DevicePreview.appBuilder,

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
              '/settings': (context) => const LoginRequiredGate(child: SettingsScreen()),
              '/help_center': (context) => const LoginRequiredGate(child: HelpCenterScreen()),
              '/about_us': (context) => const LoginRequiredGate(child: AboutUsScreen()),
              '/product_details': (context) => LoginRequiredGate(
                child: ProductDetailsScreen(
                  product: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
                ),
              ),
            },
          );
        },
      ),
    );
  }
}