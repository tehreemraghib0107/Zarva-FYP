import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPass = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPass.isEmpty) {
      _showSnack("Please fill all fields");
      return;
    }

    if (password != confirmPass) {
      _showSnack("Passwords do not match!");
      return;
    }

    setState(() => _isLoading = true);
    final res = await _authService.signup(name, email, password);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res['success']) {
       _showSnack("Account Created! Please login.");
       // Optional: could auto-login here or just pop
       Navigator.pop(context);
    } else {
       _showSnack(res['message']);
    }
  }

  void _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    final res = await _authService.googleLogin(); // Google Login handles signup too
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res['success']) {
       // Navigate to home logic is not usually in signup screen (usually signup -> login or signup -> home)
       // But if Google Sign Up is successful, they are logged in.
       // So we should navigate to Home.
       Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
       _showSnack(res['message']);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1C2D), // Dark blue background
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // 🔰 LOGO
            Image.asset(
              'assets/new logo.png',
              width: 150,
              height: 150,
            ),

            const SizedBox(height: 20),

            // WHITE CARD
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(40),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 30),

                      _buildInput(
                        hint: 'Full Name',
                        controller: _nameController,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 18),

                      _buildInput(
                        hint: 'Email',
                        controller: _emailController,
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 18),

                      _buildInput(
                        hint: 'Password',
                        controller: _passwordController,
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),
                      const SizedBox(height: 18),

                      _buildInput(
                        hint: 'Confirm Password',
                        controller: _confirmPasswordController,
                        icon: Icons.lock_reset_outlined,
                        obscure: true,
                      ),

                      const SizedBox(height: 30),

                      // SIGN UP BUTTON
                      Center(
                        child: SizedBox(
                          width: 170,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                      backgroundColor: Colors.transparent, // Fix color issue
                                    ),
                                  )
                                : const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // GOOGLE SIGN UP BUTTON
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignUp,
                          icon: Image.asset('assets/google.png', height: 24),
                          label: const Text(
                            "Sign up with Google",
                            style: TextStyle(color: Colors.black),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // LOGIN REDIRECT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(color: Colors.black54),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              "Login now",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
