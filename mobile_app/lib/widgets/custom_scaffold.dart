import 'package:flutter/material.dart';
import '../utils/auth_helper.dart';

class CustomScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final Widget? drawer;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;
  final bool showLogoOnly; 
  final Widget? leading;
  final bool forceShowBack;

  const CustomScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    this.drawer,
    this.floatingActionButton,
    this.actions,
    this.showLogoOnly = false,
    this.leading,
    this.forceShowBack = false,
  });

  void _onBottomNavTap(BuildContext context, int index) async {
    if (index == currentIndex) return;

    if (index == 1 || index == 3) {
      if (!await AuthHelper.isAuthenticated()) {
        if (context.mounted) {
          AuthHelper.showLoginRedirect(context);
        }
        return;
      }
    }

    String route = '/home';
    switch (index) {
      case 0:
        route = '/home';
        break;
      case 1:
        route = '/favorites';
        break;
      case 2:
        route = '/chatbot';
        break;
      case 3:
        route = '/cart';
        break;
      case 4:
        route = '/account';
        break;
    }
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: drawer,
      appBar: AppBar(
        backgroundColor: zDarkBlue,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 120, // Increased height for a more prominent top bar
        leading: leading ?? ((forceShowBack || Navigator.canPop(context) || currentIndex != 0)
            ? IconButton(
                icon: const Icon(Icons.arrow_back), 
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                }
              )
            : (drawer != null 
                ? Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()))
                : null)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Image.asset(
          'assets/new logo.png',
          height: 120, // Increased size to match the toolbar
        ),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onBottomNavTap(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        showUnselectedLabels: true,
        backgroundColor: zDarkBlue,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'Chatbot'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}
