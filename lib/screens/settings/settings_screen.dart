import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';
import '../../controllers/connection_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/location_picker_sheet.dart';
import 'server_connection_screen.dart';
import 'server_diagnostics_screen.dart';
import 'admin_control_screen.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final ConnectionController connectionController;
  final AuthController authController;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.connectionController,
    required this.authController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.storageService.getNotificationsEnabled();
  }

  void _showThemeDialog(BuildContext context, ThemeController themeCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('System Default'),
              trailing: themeCtrl.themeMode == ThemeMode.system
                  ? const Icon(Icons.check_rounded, color: AppColors.success)
                  : null,
              onTap: () {
                themeCtrl.setThemeMode(ThemeMode.system);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('Light Mode'),
              trailing: themeCtrl.themeMode == ThemeMode.light
                  ? const Icon(Icons.check_rounded, color: AppColors.success)
                  : null,
              onTap: () {
                themeCtrl.setThemeMode(ThemeMode.light);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('Dark Mode'),
              trailing: themeCtrl.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check_rounded, color: AppColors.success)
                  : null,
              onTap: () {
                themeCtrl.setThemeMode(ThemeMode.dark);
                Navigator.of(ctx).pop();
              },
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
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset(
        'assets/images/cotton_guard_logo.png',
        width: 48,
        height: 48,
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'AI-Based Smart Cotton Leaf Disease Detection & Agronomic Advisory System.\n\n'
          'Designed for cotton growers, agronomists, and researchers. Incorporates automated image quality verification, botanical leaf gating, and ONNX Runtime accelerated disease inference across 7 canonical conditions.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeCtrl = ThemeController(widget.storageService);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          children: [
            // Connectivity Group
            Text(
              'AI Backend & Connectivity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.secondary : AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dns_outlined, color: AppColors.info),
                    title: const Text('Server Connection'),
                    subtitle: Text(
                      widget.connectionController.currentUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ServerConnectionScreen(
                            connectionController: widget.connectionController,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.troubleshoot_rounded, color: AppColors.accent),
                    title: const Text('Server Test Center / Diagnostics'),
                    subtitle: const Text('Run 8-point automated API test suite'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ServerDiagnosticsScreen(
                            storageService: widget.storageService,
                            connectionController: widget.connectionController,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
                    title: const Text('Inference Control Plane (Admin)'),
                    subtitle: const Text('Start / Stop global AI inference service'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminControlScreen(
                            storageService: widget.storageService,
                            connectionController: widget.connectionController,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Preferences Group
            Text(
              'Preferences & Appearance',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.secondary : AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      color: isDark ? AppColors.secondary : AppColors.primary,
                    ),
                    title: const Text('Display Theme'),
                    subtitle: Text(
                      widget.storageService.getThemeMode().toUpperCase(),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showThemeDialog(context, themeCtrl),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: isDark ? AppColors.secondary : AppColors.primary,
                    ),
                    title: const Text('Farm Location'),
                    subtitle: Text(
                      widget.authController.currentUser?.location ?? 'Warangal, Telangana',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      final cur = widget.authController.currentUser?.location ?? 'Warangal, Telangana';
                      LocationPickerSheet.show(
                        context: context,
                        currentLocation: cur,
                        onLocationSelected: (loc) async {
                          final user = widget.authController.currentUser ?? UserProfile.defaultFarmer();
                          final updated = user.copyWith(
                            location: loc.displayName,
                            latitude: loc.latitude,
                            longitude: loc.longitude,
                          );
                          await widget.authController.updateProfile(updated);
                          if (mounted) setState(() {});
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Agronomic Alerts'),
                    subtitle: const Text('Advisory updates & weather advisories'),
                    value: _notificationsEnabled,
                    activeThumbColor: isDark ? AppColors.secondary : AppColors.primary,
                    onChanged: (val) async {
                      setState(() => _notificationsEnabled = val);
                      await widget.storageService.setNotificationsEnabled(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Data & System Group
            Text(
              'Data & Privacy',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.secondary : AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: const Text('Clear All Diagnosis History'),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear History?'),
                          content: const Text('Permanently remove all saved leaf diagnoses from device storage?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await widget.storageService.clearAllHistory();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All scan history cleared')),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('About Cotton Guard'),
                    subtitle: const Text('Version 1.0.0 (Production Release)'),
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
