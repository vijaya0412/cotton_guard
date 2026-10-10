import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';
import '../../services/profile_image_service.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/connection_controller.dart';
import '../../controllers/history_controller.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/location_picker_sheet.dart';
import '../../data/indian_locations.dart';
import '../settings/settings_screen.dart';
import '../settings/server_connection_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final StorageService storageService;
  final AuthController authController;
  final ConnectionController connectionController;

  const ProfileScreen({
    super.key,
    required this.storageService,
    required this.authController,
    required this.connectionController,
  });

  void _showChangePhotoSheet(BuildContext context) {
    final user = authController.currentUser ?? UserProfile.defaultFarmer();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final path = await ProfileImageService.pickAndSaveImage(ImageSource.gallery);
                  if (path != null) {
                    final updated = user.copyWith(profileImagePath: path);
                    await authController.updateProfile(updated);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
                title: const Text('Take New Photo with Camera'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final path = await ProfileImageService.pickAndSaveImage(ImageSource.camera);
                  if (path != null) {
                    final updated = user.copyWith(profileImagePath: path);
                    await authController.updateProfile(updated);
                  }
                },
              ),
              if (user.profileImagePath != null && user.profileImagePath!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  title: const Text('Remove Picture', style: TextStyle(color: AppColors.danger)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ProfileImageService.deleteImageFile(user.profileImagePath);
                    final updated = user.copyWith(clearProfileImage: true);
                    await authController.updateProfile(updated);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final user = authController.currentUser ?? UserProfile.defaultFarmer();
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phone);
    final locationCtrl = TextEditingController(text: user.location);
    final roleCtrl = TextEditingController(text: user.role);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText: 'Farm Location',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.place_outlined),
                    tooltip: 'Pick Indian Location',
                    onPressed: () {
                      LocationPickerSheet.show(
                        context: context,
                        currentLocation: locationCtrl.text,
                        onLocationSelected: (loc) {
                          locationCtrl.text = loc.displayName;
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final locName = locationCtrl.text.trim();
              final match = IndianLocations.find(locName);
              final updated = user.copyWith(
                fullName: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                location: locName,
                latitude: match?.latitude ?? user.latitude,
                longitude: match?.longitude ?? user.longitude,
                role: roleCtrl.text.trim(),
              );
              await authController.updateProfile(updated);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


  void _showFarmDetailsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Farm Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Field Plot Size', '8.5 Acres', isDark),
            const SizedBox(height: 10),
            _buildDetailRow('Cotton Variety', 'Bt Hybrid (Bollgard II)', isDark),
            const SizedBox(height: 10),
            _buildDetailRow('Crop Stage', 'Peak Flowering & Squaring (65 DAS)', isDark),
            const SizedBox(height: 10),
            _buildDetailRow('Soil Type', 'Deep Black Cotton Soil (Vertisol)', isDark),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Done',
              width: double.infinity,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  void _showHelpSupportDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Agronomic Support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'For severe pest or unknown pathogen outbreaks, contact your local Krishi Vigyan Kendra (KVK) or state agricultural extension officer.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 14),
            _buildDetailRow('Kisan Call Center', 'Toll-free 1800-180-1551', isDark),
            const SizedBox(height: 8),
            _buildDetailRow('Support Email', 'support@cottonguard.org', isDark),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Close',
              width: double.infinity,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Cotton Guard',
      applicationVersion: '1.0.0+1',
      applicationIcon: Image.asset('assets/images/cotton_guard_logo.png', width: 48, height: 48),
      children: const [
        Text(
          'Cotton Guard is an AI-powered cotton leaf health and disease diagnosis system.\n\n'
          'Featuring MobileNetV2 with CBAM attention, CIELAB-CLAHE preprocessing, and comprehensive agronomic advisory for cotton growers.',
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of Cotton Guard?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await authController.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(storageService: storageService),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyController = HistoryController(storageService);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    storageService: storageService,
                    connectionController: connectionController,
                    authController: authController,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: authController,
          builder: (context, _) {
            final user = authController.currentUser ?? UserProfile.defaultFarmer();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: Column(
                children: [
                  // Profile Header: Photo, Name, Email/Phone, Location, Edit Profile
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Profile Avatar with interactive Camera Edit Badge
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            UserAvatar(
                              imagePath: user.profileImagePath,
                              radius: 46,
                              borderWidth: 2.2,
                              onTap: () => _showChangePhotoSheet(context),
                            ),
                            GestureDetector(
                              onTap: () => _showChangePhotoSheet(context),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.secondary : AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? AppColors.surfaceDark : Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(isDark ? 60 : 30),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 15,
                                  color: isDark ? AppColors.backgroundDark : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Name
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Phone & Email
                        Text(
                          user.email.isNotEmpty ? user.email : user.phone,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Location with Tap to Change
                        InkWell(
                          onTap: () {
                            LocationPickerSheet.show(
                              context: context,
                              currentLocation: user.location,
                              onLocationSelected: (selected) async {
                                final updated = user.copyWith(
                                  location: selected.displayName,
                                  latitude: selected.latitude,
                                  longitude: selected.longitude,
                                );
                                await authController.updateProfile(updated);
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on_rounded,
                                    size: 14,
                                    color: isDark ? AppColors.secondary : AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  user.location,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.secondary
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.edit_location_alt_outlined,
                                    size: 13,
                                    color: isDark ? AppColors.secondary : AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Edit Profile Button
                        OutlinedButton.icon(
                          onPressed: () => _showEditProfileDialog(context),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Edit Profile'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            side: BorderSide(
                              color: isDark ? AppColors.secondary : AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Statistics Row: Total Scans | Diseases | Healthy
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          '${historyController.totalScans}',
                          'Total Scans',
                          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                        _buildStatColumn(
                          '${historyController.diseasedScans}',
                          'Diseases',
                          AppColors.danger,
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                        _buildStatColumn(
                          '${historyController.healthyScans}',
                          'Healthy',
                          const Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Sections List Group:
                  // Farm Details, AI Server Connection, App Settings, Help & Support, About Cotton Guard
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _buildSectionTile(
                          icon: Icons.agriculture_outlined,
                          iconColor: const Color(0xFF2E7D32),
                          title: 'Farm Details',
                          subtitle: 'Plot acreage, cotton variety & crop stage',
                          onTap: () => _showFarmDetailsDialog(context),
                        ),
                        const Divider(height: 1),
                        _buildSectionTile(
                          icon: Icons.settings_ethernet_rounded,
                          iconColor: AppColors.info,
                          title: 'AI Server Connection',
                          subtitle: 'Configure host, port & inspect latency',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ServerConnectionScreen(
                                  connectionController: connectionController,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _buildSectionTile(
                          icon: Icons.tune_rounded,
                          iconColor: AppColors.accent,
                          title: 'App Settings',
                          subtitle: 'Theme preference, storage & reset',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SettingsScreen(
                                  storageService: storageService,
                                  connectionController: connectionController,
                                  authController: authController,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _buildSectionTile(
                          icon: Icons.support_agent_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Help & Support',
                          subtitle: 'Kisan helpline & agricultural extension',
                          onTap: () => _showHelpSupportDialog(context),
                        ),
                        const Divider(height: 1),
                        _buildSectionTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: isDark ? AppColors.secondary : AppColors.primary,
                          title: 'About Cotton Guard',
                          subtitle: 'v1.0.0 • MobileNetV2 + CBAM + CLAHE',
                          onTap: () => _showAboutDialog(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign Out Button
                  CustomButton(
                    text: 'Sign Out',
                    icon: Icons.logout_rounded,
                    variant: ButtonVariant.danger,
                    width: double.infinity,
                    onPressed: () => _confirmLogout(context),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label, Color countColor) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: countColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF718096),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withAlpha(22),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}
