import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/custom_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScaffold(
      currentIndex: 4,
      forceShowBack: true,
      body: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : zDarkBlue,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Apply dark theme across the entire app'),
                  value: themeService.isDarkMode,
                  activeThumbColor: zDarkBlue,
                  onChanged: themeService.toggleDarkMode,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
