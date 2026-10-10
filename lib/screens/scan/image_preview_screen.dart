import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../controllers/connection_controller.dart';
import '../../controllers/history_controller.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import 'ai_analysis_screen.dart';

class ImagePreviewScreen extends StatefulWidget {
  final File? imageFile;
  final String? assetPath;
  final StorageService storageService;
  final ConnectionController connectionController;
  final HistoryController historyController;

  const ImagePreviewScreen({
    super.key,
    this.imageFile,
    this.assetPath,
    required this.storageService,
    required this.connectionController,
    required this.historyController,
  }) : assert(imageFile != null || assetPath != null);

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late File? _currentFile;
  late String? _currentAsset;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentFile = widget.imageFile;
    _currentAsset = widget.assetPath;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (file != null && mounted) {
        setState(() {
          _currentFile = File(file.path);
          _currentAsset = null;
        });
      }
    } catch (_) {}
  }

  void _proceedToAnalysis() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AiAnalysisScreen(
          imageFile: _currentFile,
          assetPath: _currentAsset,
          storageService: widget.storageService,
          connectionController: widget.connectionController,
          historyController: widget.historyController,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget imageWidget;
    if (_currentFile != null) {
      imageWidget = Image.file(_currentFile!, fit: BoxFit.cover);
    } else {
      imageWidget = Image.asset(_currentAsset!, fit: BoxFit.cover);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Review Leaf Capture'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Large Image Preview Container with Hero tag
              Expanded(
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'leaf_scan_hero',
                          child: imageWidget,
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(160),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.scanBeam, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Ready for Analysis',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Leaf Quality Guidance Tips
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        color: AppColors.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ensure lesions, venation, and symptoms are sharp and visible without heavy shadow.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Primary Action: Analyze Leaf
              CustomButton(
                text: 'Analyze Leaf with AI',
                icon: Icons.psychology_rounded,
                onPressed: _proceedToAnalysis,
              ),
              const SizedBox(height: 12),

              // Secondary Actions: Retake & Gallery
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Retake',
                      icon: Icons.camera_alt_outlined,
                      variant: ButtonVariant.outline,
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Gallery',
                      icon: Icons.photo_library_outlined,
                      variant: ButtonVariant.outline,
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
