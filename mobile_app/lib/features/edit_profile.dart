import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_scaffold.dart';
import '../services/auth_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _profileImageBase64;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await _authService.getProfile();
    if (mounted) {
      if (result['success']) {
        final user = result['user'];
        setState(() {
          _nameController.text = user['name'] ?? "";
          _emailController.text = user['email'] ?? "";
          if (user['profileImage'] != null && user['profileImage'].isNotEmpty) {
            _profileImageBase64 = user['profileImage'];
            if (_profileImageBase64!.startsWith('data:image')) {
               _imageBytes = base64Decode(_profileImageBase64!.split(',').last);
            }
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final String base64Image = "data:image/png;base64,${base64Encode(bytes)}";
      setState(() {
        _imageBytes = bytes;
        _profileImageBase64 = base64Image;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    
    try {
      final result = await _authService.updateProfile(
        name: _nameController.text,
        profileImage: _profileImageBase64,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });
        
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
          );
          _loadProfile(); // Refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to update profile'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);

    return CustomScaffold(
      currentIndex: 4,
      showLogoOnly: true,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // PROFILE AVATAR
              Stack(
                children: [
                   CircleAvatar(
                     radius: 50,
                     backgroundColor: zDarkBlue.withOpacity(0.1),
                     backgroundImage: _imageBytes != null 
                        ? MemoryImage(_imageBytes!) 
                        : null,
                     child: _imageBytes == null 
                        ? const Icon(Icons.person, size: 55, color: zDarkBlue)
                        : null,
                   ),
                   if (_isEditing)
                     Positioned(
                       right: 0,
                       bottom: 0,
                       child: GestureDetector(
                         onTap: _pickImage,
                         child: Container(
                           padding: const EdgeInsets.all(8),
                           decoration: const BoxDecoration(color: zDarkBlue, shape: BoxShape.circle),
                           child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                         ),
                       ),
                     ),
                ],
              ),
              const SizedBox(height: 30),

              // FORM FIELDS
              _buildField(
                label: 'Full Name',
                controller: _nameController,
                enabled: _isEditing,
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 20),
              _buildField(
                label: 'Email Address',
                controller: _emailController,
                enabled: false, // Don't allow email change for now as it's the primary ID
                icon: Icons.email_outlined,
              ),
              
              const SizedBox(height: 40),

              if (!_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = true),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: zDarkBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Edit Profile', style: TextStyle(color: zDarkBlue, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Column(
                  children: [
                    if (_isSaving) const CircularProgressIndicator(),
                    if (!_isSaving)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: zDarkBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
            ],
          ),
        ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(color: Color(0xFF0B1C2D), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF0B1C2D)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
            ),
          ),
        ),
      ],
    );
  }
}
