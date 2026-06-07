import 'package:flutter/material.dart';
import '../widgets/custom_scaffold.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';

class AccountMenuScreen extends StatefulWidget {
  const AccountMenuScreen({super.key});

  @override
  State<AccountMenuScreen> createState() => _AccountMenuScreenState();
}

class _AccountMenuScreenState extends State<AccountMenuScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await _authService.getProfile();
    if (mounted) {
      setState(() {
        if (result['success']) {
          _userData = result['user'];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    final bool isGuest = _userData == null || _userData!.isEmpty;

    return CustomScaffold(
      currentIndex: 4,
      showLogoOnly: true, 
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : isGuest
          ? _buildGuestLanding()
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                   CircleAvatar(
                     radius: 35,
                     backgroundColor: Colors.grey.shade200,
                     backgroundImage: (_userData?['profileImage'] != null && _userData!['profileImage'].isNotEmpty)
                        ? ( _userData!['profileImage'].startsWith('data:image') 
                            ? MemoryImage(Uri.parse(_userData!['profileImage']).data!.contentAsBytes()) as ImageProvider
                            : NetworkImage(_userData!['profileImage']) )
                        : null,
                     child: (_userData?['profileImage'] == null || _userData!['profileImage'].isEmpty)
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                   ),
                   const SizedBox(width: 15),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text(
                            _userData?['name'] ?? "User", 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: zDarkBlue),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _userData?['email'] ?? "Personal Profile", 
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                       ],
                     ),
                   ),
                   IconButton(
                     onPressed: () => Navigator.pushNamed(context, '/edit_profile').then((_) => _loadProfile()),
                     icon: const Icon(Icons.edit_outlined, color: zDarkBlue),
                   )
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // Menu Items In Cards
            _buildSection([
              _accountItem(context, Icons.person_outline, "My Profile", '/edit_profile'),
              _accountItem(context, Icons.shopping_bag, "My Orders", '/history'),
              _accountItem(context, Icons.history, "History", '/order_history_products'),
              _accountItem(context, Icons.favorite_border, "My Favorites", '/favorites'),
            ]),

            _buildSection([
              _accountItem(context, Icons.settings_outlined, "Settings", null),
              _accountItem(context, Icons.help_outline, "Help Center", null),
              _accountItem(context, Icons.info_outline, "About Us", null),
            ]),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                tileColor: Colors.white,
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Log Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                onTap: () async {
                   await _authService.logout();
                   await CartService().clearGuestCart();
                   await CartService().reloadForCurrentUser();
                   if (mounted) Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestLanding() {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: zDarkBlue.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_circle_outlined,
                size: 80,
                color: zDarkBlue,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Join ZARVA",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: zDarkBlue,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Log in or sign up to access your shopping vault, track orders, edit your style profile, and save favorite jewelry items.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login').then((_) => _loadProfile());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: zDarkBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Log In",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup').then((_) => _loadProfile());
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: zDarkBlue, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  "Create Account",
                  style: TextStyle(
                    color: zDarkBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: items),
    );
  }

  Widget _accountItem(BuildContext context, IconData icon, String title, String? route) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0B1C2D)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: () {
        if (route != null) {
          Navigator.pushNamed(context, route).then((_) => _loadProfile());
        }
      },
    );
  }
}
