import 'package:flutter/material.dart';
import '../utils/auth_helper.dart';

/// Redirects unauthenticated users to /login — no guest browsing.
class LoginRequiredGate extends StatefulWidget {
  final Widget child;

  const LoginRequiredGate({super.key, required this.child});

  @override
  State<LoginRequiredGate> createState() => _LoginRequiredGateState();
}

class _LoginRequiredGateState extends State<LoginRequiredGate> {
  bool _checked = false;
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final authed = await AuthHelper.validateSession();
    if (!mounted) return;
    setState(() {
      _authed = authed;
      _checked = true;
    });
    if (!authed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_authed) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}

/// Blocks child routes for unauthenticated users and shows the login sheet.
class AuthGate extends StatefulWidget {
  final Widget child;
  final bool showLockedScaffold;

  const AuthGate({
    super.key,
    required this.child,
    this.showLockedScaffold = true,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checked = false;
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authed = await AuthHelper.isAuthenticated();
    if (!mounted) return;
    setState(() {
      _authed = authed;
      _checked = true;
    });
    if (!authed && widget.showLockedScaffold) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AuthHelper.showLoginRedirect(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_authed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 72, color: Color(0xFF0B1C2D)),
                const SizedBox(height: 20),
                const Text(
                  'Shopping Vault Locked',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B1C2D),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please sign up or login to access your shopping vault.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => AuthHelper.showLoginRedirect(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B1C2D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Login / Signup',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
