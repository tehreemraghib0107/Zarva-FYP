import 'dart:typed_data';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../services/ai_recommendation_service.dart';
import '../utils/zarbot_response_formatter.dart';
import '../widgets/custom_scaffold.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  static const Color _navy = Color(0xFF0B1C2D);
  static const Color _luxuryNavy = Color(0xFF0B1325);
  static const Color _luxuryGold = Color(0xFFD4AF37);
  static const Color _creamText = Color(0xFFF5E6C8);
  static const Color _creamSurface = Color.fromARGB(255, 235, 224, 204);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'bot',
      'type': 'text',
      'text':
          'Welcome to ZarBot ✨\n\n'
          'Send a message anytime, or attach an outfit photo for a full AI styling '
          'recommendation. Optional filters refine your results — leave them blank '
          'and we will auto-detect your palette.',
    },
  ];

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isAnalyzing = false;
  String? _userId;

  /// Optional filter chips — always cleared after each send unless re-selected.
  String? _dressColor;
  String? _skinTone;
  String? _selectedManualNeckline;

  bool get _isLoading => _isAnalyzing;

  static const List<String> _dressColors = [
    'Red',
    'Blue',
    'Pastel',
    'Gold',
    'Green',
    'Maroon',
    'Ivory',
  ];

  static const List<String> _skinTones = [
    'Warm',
    'Cool',
    'Neutral',
    'Olive',
    'Deep',
  ];

  static const List<String> _necklineOptions = [
    'Round / Scoop',
    'V-Neck',
    'Boat Neck',
    'Collar / Ban',
    'Sweetheart',
  ];

  late final AnimationController _dotController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadUserId();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_id');
    if (!mounted) return;
    setState(() {
      _userId = (stored != null && stored.isNotEmpty)
          ? stored
          : 'guest-${const Uuid().v4()}';
    });
  }

  void _showFlush(String message, {bool isError = true}) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(14),
      backgroundColor: isError ? const Color(0xFF8B2E2E) : _navy,
      messageColor: Colors.white,
      icon: Icon(
        isError ? Icons.info_outline : Icons.check_circle_outline,
        color: Colors.white,
      ),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedImage = file;
        _selectedImageBytes = Uint8List.fromList(bytes);
      });
      if (mounted) _showMetadataSheet();
    } catch (e) {
      _showFlush(
        'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e',
      );
    }
  }

  void _showAttachmentOptions() {
    if (_isLoading) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Attach outfit photo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _creamSurface,
                  child: const Icon(Icons.camera_alt_outlined, color: _navy),
                ),
                title: const Text('Take a Photo (Camera)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _creamSurface,
                  child: const Icon(Icons.photo_library_outlined, color: _navy),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetadataSheet() {
    String? tempColor = _dressColor;
    String? tempTone = _skinTone;
    String? tempNeck = _selectedManualNeckline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                        children: [
                          const Text(
                            'Style metadata',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All filters are optional. Tap a selected chip again to clear. '
                            'Empty fields let ZarBot auto-detect colours from your photo.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _sheetSectionTitle('Dress colour palette'),
                          const SizedBox(height: 10),
                          _optionalChipWrap(
                            options: _dressColors,
                            selected: tempColor,
                            onToggle: (v) =>
                                setModalState(() => tempColor = v),
                          ),
                          const SizedBox(height: 22),
                          _sheetSectionTitle('Skin tone target'),
                          const SizedBox(height: 10),
                          _optionalChipWrap(
                            options: _skinTones,
                            selected: tempTone,
                            onToggle: (v) => setModalState(() => tempTone = v),
                          ),
                          const SizedBox(height: 22),
                          _sheetSectionTitle('Select your neckline (backup override)'),
                          const SizedBox(height: 10),
                          _optionalChipWrap(
                            options: _necklineOptions,
                            selected: tempNeck,
                            onToggle: (v) => setModalState(() => tempNeck = v),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        MediaQuery.of(ctx).padding.bottom + 16,
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempColor = null;
                                tempTone = null;
                                tempNeck = null;
                              });
                            },
                            child: const Text('Clear all'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _dressColor = tempColor;
                                  _skinTone = tempTone;
                                  _selectedManualNeckline = tempNeck;
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Text('Apply Optional Filters'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sheetSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: _navy,
      ),
    );
  }

  Widget _optionalChipWrap({
    required List<String> options,
    required String? selected,
    required void Function(String?) onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected == option;
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          showCheckmark: true,
          selectedColor: _creamSurface,
          backgroundColor: Colors.grey.shade50,
          labelStyle: TextStyle(
            color: isSelected ? _navy : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
          side: BorderSide(
            color: isSelected ? _luxuryGold : Colors.grey.shade300,
            width: isSelected ? 1.4 : 1,
          ),
          onSelected: (_) => onToggle(isSelected ? null : option),
        );
      }).toList(),
    );
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  /// Wipes compose UI so the next message cannot inherit stale chips or images.
  void _resetPostSendState() {
    _controller.clear();
    if (!mounted) return;
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _dressColor = null;
      _skinTone = null;
      _selectedManualNeckline = null;
    });
  }

  String _emptyOr(String? value) =>
      (value != null && value.trim().isNotEmpty) ? value.trim() : '';

  String _filterLabel(String? value, String placeholder) =>
      (value != null && value.isNotEmpty) ? value : placeholder;

  /// Snapshot outbound data before any UI reset — isolated from widget state.
  Future<StyleRecommendationPayload?> _buildImagePayload(String userText) async {
    final file = _selectedImage;
    if (file == null) return null;

    final freshBytes = await file.readAsBytes();
    final path = file.path.trim();
    final filename =
        file.name.trim().isNotEmpty ? file.name.trim() : 'outfit_${DateTime.now().millisecondsSinceEpoch}.jpg';

    return StyleRecommendationPayload(
      userId: _userId ?? 'guest',
      dressColor: _emptyOr(_dressColor),
      skinTone: _emptyOr(_skinTone),
      manualNeckline: _emptyOr(_selectedManualNeckline),
      userQuery: userText,
      imagePath: path,
      imageBytes: freshBytes,
      imageFilename: filename,
    );
  }

  Future<void> _sendMessage() async {
    if (_isLoading) return;

    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final hasImage = _selectedImage != null;
    final userText = text.isEmpty && hasImage
        ? 'Please analyze my outfit for jewelry recommendations.'
        : text;

    StyleRecommendationPayload? imagePayload;
    if (hasImage) {
      imagePayload = await _buildImagePayload(userText);
      if (imagePayload == null) {
        _showFlush('Could not read the selected image. Please attach again.');
        return;
      }
    }

    setState(() {
      if (userText.isNotEmpty || hasImage) {
        _messages.add({
          'sender': 'user',
          'type': 'text',
          'text': userText,
          if (hasImage) 'hasImage': true,
        });
      }
      _messages.add({
        'sender': 'typing',
        'type': 'typing',
        'text': 'ZarBot is analyzing your style palette...',
      });
      _isAnalyzing = true;
    });

    _resetPostSendState();
    _scrollToBottom();

    try {
      final Map<String, dynamic> result;

      if (hasImage && imagePayload != null) {
        result = await AiRecommendationService.sendStyleRecommendation(
          imagePayload,
        );
      } else {
        result = await AiRecommendationService.sendTextQuery(
          userId: _userId ?? 'guest',
          userQuery: userText,
        );
      }

      if (!mounted) return;
      _handleApiResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m['sender'] == 'typing');
        _isAnalyzing = false;
        _messages.add({
          'sender': 'bot',
          'type': 'text',
          'text':
              'Connection error. Ensure Node.js (:5000) and the AI engine (:8000) are running.\n\n$e',
        });
      });
      _showFlush('Network error: $e');
    }

    _scrollToBottom();
  }

  void _handleApiResult(Map<String, dynamic> result) {
    setState(() {
      _messages.removeWhere((m) => m['sender'] == 'typing');
      _isAnalyzing = false;

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>? ?? {};

        final parsed = ZarbotResponseFormatter.parse(data);

        if (parsed.stylingInsight.isNotEmpty) {
          _messages.add({
            'sender': 'bot',
            'type': 'recommendation',
            'parsed': parsed,
            'raw': data,
          });
        } else {
          _messages.add({
            'sender': 'bot',
            'type': 'text',
            'text': parsed.stylingInsight.isNotEmpty
                ? parsed.stylingInsight
                : 'No recommendation returned. Please try again.',
          });
        }
      } else {
        final msg = result['message']?.toString() ??
            'Could not complete your styling request.';
        _messages.add({'sender': 'bot', 'type': 'text', 'text': msg});
        _showFlush(msg);
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildFilterStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _FilterChipButton(
            icon: Icons.palette_outlined,
            label: _filterLabel(_dressColor, 'Dress colour'),
            isActive: _dressColor != null,
            enabled: !_isLoading,
            onTap: _showMetadataSheet,
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            icon: Icons.face_retouching_natural,
            label: _filterLabel(_skinTone, 'Skin tone'),
            isActive: _skinTone != null,
            enabled: !_isLoading,
            onTap: _showMetadataSheet,
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            icon: Icons.checkroom_outlined,
            label: _filterLabel(_selectedManualNeckline, 'Neckline'),
            isActive: _selectedManualNeckline != null,
            enabled: !_isLoading,
            onTap: _showMetadataSheet,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _showMetadataSheet,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Filters', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewBanner() {
    if (_selectedImageBytes == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_creamSurface, _creamSurface.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _luxuryGold.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _selectedImageBytes!,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Outfit ready to style',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _navy,
                    fontSize: 13,
                  ),
                ),
                Text(
                  () {
                    final parts = <String>[
                      if (_dressColor != null) _dressColor!,
                      if (_skinTone != null) _skinTone!,
                      if (_selectedManualNeckline != null)
                        _selectedManualNeckline!,
                    ];
                    return parts.isEmpty
                        ? 'Optional filters — auto-detect enabled'
                        : parts.join(' · ');
                  }(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearSelectedImage,
            icon: const Icon(Icons.close, color: _navy, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(Map<String, dynamic> msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        decoration: BoxDecoration(
          color: _luxuryNavy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _luxuryGold.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _dotController,
                  builder: (context, child) {
                    final phase = (_dotController.value + i * 0.2) % 1.0;
                    final opacity = 0.35 + (phase < 0.5 ? phase : 1 - phase) * 1.3;
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _luxuryGold.withValues(alpha: opacity.clamp(0.3, 1.0)),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 10),
            Text(
              msg['text'] as String,
              style: const TextStyle(
                color: _creamText,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _buildShimmerBars(),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBars() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final t = _shimmerController.value;
        return Column(
          children: [
            _shimmerLine(widthFactor: 0.95, opacity: 0.25 + t * 0.2),
            const SizedBox(height: 6),
            _shimmerLine(widthFactor: 0.72, opacity: 0.2 + (1 - t) * 0.15),
          ],
        );
      },
    );
  }

  Widget _shimmerLine({required double widthFactor, required double opacity}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: _luxuryGold.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildLuxuryRecommendationCard(ParsedZarbotResponse parsed) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        decoration: BoxDecoration(
          color: _luxuryNavy,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _luxuryGold, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _luxuryGold.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _LuxuryBadge(
                      icon: Icons.checkroom_outlined,
                      label: parsed.necklineBadge,
                    ),
                    const SizedBox(width: 8),
                    _LuxuryBadge(
                      icon: Icons.diamond_outlined,
                      label: parsed.accentBadge,
                    ),
                    const SizedBox(width: 8),
                    _LuxuryBadge(
                      icon: Icons.public,
                      label: parsed.themeBadge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Text('✨', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'ZarBot Styling Insight',
                    style: TextStyle(
                      color: _luxuryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                parsed.stylingInsight,
                style: const TextStyle(
                  color: _creamText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text('📐', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'Why This Works',
                    style: TextStyle(
                      color: _luxuryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                parsed.whyThisWorks,
                style: TextStyle(
                  color: _creamText.withValues(alpha: 0.88),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserBubble(Map<String, dynamic> msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg['hasImage'] == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Photo attached',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              msg['text'] as String,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleBotBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: _creamSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final sender = msg['sender'] as String;
    if (sender == 'typing') return _buildTypingIndicator(msg);
    if (sender == 'user') return _buildUserBubble(msg);

    final type = msg['type'] as String?;
    if (type == 'recommendation' || type == 'text_card') {
      final parsed = msg['parsed'] as ParsedZarbotResponse?;
      if (parsed != null) {
        return _buildLuxuryRecommendationCard(parsed);
      }
    }

    return _buildSimpleBotBubble(msg['text'] as String? ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      currentIndex: 2,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterStrip(),
                  _buildImagePreviewBanner(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 8, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _isLoading ? null : _showAttachmentOptions,
                          icon: Icon(
                            Icons.attach_file_rounded,
                            color: _isLoading ? Colors.grey : _navy,
                          ),
                          tooltip: 'Attach outfit',
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_isLoading,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _isLoading ? null : (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              filled: true,
                              fillColor: const Color(0xFFF4F4F6),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: _isLoading ? Colors.grey.shade400 : _navy,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            onPressed: _isLoading ? null : _sendMessage,
                            icon: const Icon(Icons.arrow_upward_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool enabled;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: enabled ? const Color(0xFF0B1C2D) : Colors.grey,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? Colors.black87 : Colors.grey,
        ),
      ),
      backgroundColor: isActive
          ? const Color.fromARGB(255, 235, 224, 204)
          : Colors.grey.shade100,
      side: BorderSide(
        color: isActive ? const Color(0xFFD4AF37) : Colors.grey.shade300,
      ),
      onPressed: enabled ? onTap : null,
    );
  }
}

class _LuxuryBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LuxuryBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF162035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFD4AF37)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFF5E6C8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
