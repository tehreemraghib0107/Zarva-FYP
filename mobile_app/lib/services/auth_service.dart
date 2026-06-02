import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class AuthService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web, or your machine's IP for physical device
  static const String baseUrl = '${AppConstants.baseUrl}/auth';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '662650739627-cngolf2q7n1p673mmkij4h0uf73esrsq.apps.googleusercontent.com', // Web Client ID
    scopes: ['email', 'openid', 'profile'],
  );

  // Manual Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveSession(token: data['token'], user: data['user']);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['msg'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Manual Signup
  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Signup successful'};
      } else {
        return {'success': false, 'message': data['msg'] ?? 'Signup failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Google Login
  Future<Map<String, dynamic>> googleLogin() async {
    try {
      // Force sign out to ensure we get a fresh token if previous attempts were bad
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'Google Sign-In aborted'};
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      print("Google Auth Debug - AccessToken: ${googleAuth.accessToken}");
      print("Google Auth Debug - IdToken: ${googleAuth.idToken}");

      String? tokenToSend = idToken;
      String type = 'idToken';

      if (tokenToSend == null) {
        if (googleAuth.accessToken != null) {
            tokenToSend = googleAuth.accessToken;
            type = 'accessToken';
        } else {
            return {'success': false, 'message': 'Failed to get ID Token OR Access Token from Google'};
        }
      }

      // Send Token to Backend
      final response = await http.post(
        Uri.parse('$baseUrl/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': tokenToSend, 'type': type}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
         await _saveSession(token: data['token'], user: data['user']);
         return {'success': true, 'data': data};
      } else {
         return {'success': false, 'message': data['error'] ?? 'Google Backend Auth Failed'};
      }

    } catch (e) {
      return {'success': false, 'message': 'Google Auth Error: $e'};
    }
  }
  
  // Logout
  Future<void> logout() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('isLoggedIn');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
  }

  // Fetch Profile data
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'user': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Failed to fetch profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update Profile data (Name & Image)
  Future<Map<String, dynamic>> updateProfile({String? name, String? profileImage}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (name != null) 'name': name,
          if (profileImage != null) 'profileImage': profileImage,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Failed to update profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<void> _saveSession({required String token, Map<String, dynamic>? user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setBool('isLoggedIn', true);
    if (user != null) {
      final id = user['id']?.toString();
      final email = user['email']?.toString();
      if (id != null && id.isNotEmpty) await prefs.setString('user_id', id);
      if (email != null && email.isNotEmpty) await prefs.setString('user_email', email);
    }
  }
}
