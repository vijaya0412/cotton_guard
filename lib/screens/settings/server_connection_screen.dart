import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/api_constants.dart';
import '../../controllers/connection_controller.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/status_badge.dart';
import 'server_diagnostics_screen.dart';

class ServerConnectionScreen extends StatefulWidget {
  final ConnectionController connectionController;

  const ServerConnectionScreen({super.key, required this.connectionController});

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  late final TextEditingController _urlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.connectionController.currentUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _applyPreset(String url) {
    setState(() {
      _urlController.text = url;
    });
  }

  Future<void> _handleSaveAndTest() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a server IP or URL')),
      );
      return;
    }

    final normalized = ApiConstants.normalizeBaseUrl(rawUrl);
    _urlController.text = normalized;

    setState(() => _isSaving = true);
    await widget.connectionController.updateServerUrl(normalized);
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.connectionController.isConnected
              ? 'Connected successfully to AI server!'
              : 'Server unreachable at $normalized. Ensure py -3.13 backend/run_server.py is running.',
        ),
        backgroundColor: widget.connectionController.isConnected
            ? AppColors.success
            : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('AI Server Connection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-check Health',
            onPressed: () => widget.connectionController.checkConnection(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.connectionController,
          builder: (context, _) {
            final health = widget.connectionController.health;
            final isChecking = widget.connectionController.isChecking;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Live Status Header Card
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Live Server Health',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            StatusBadge.serverStatus(health.status, latencyMs: health.latencyMs),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 10),

                        _buildInfoRow('Backend Version', health.version, isDark),
                        _buildInfoRow('Model Loaded', health.modelLoaded ? 'Yes (MobileNetV2)' : 'No', isDark),
                        _buildInfoRow('Inference Engine', health.inferenceEngine, isDark),
                        _buildInfoRow('Cotton Gate', health.cottonValidationReady ? 'Active' : 'Inactive', isDark),
                        _buildInfoRow(
                          'Latency',
                          health.latencyMs > 0 ? '${health.latencyMs} ms' : 'N/A',
                          isDark,
                        ),

                        if (health.errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              health.errorMessage!,
                              style: const TextStyle(fontSize: 12, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // URL Input Card
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Server Base API URL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Endpoint root for disease inference and agronomic services:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.link_rounded),
                            hintText: 'https://cotton-guard.onrender.com/api/v1',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Preset Shortcuts
                        const Text(
                          'Quick Device Presets:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.cloud_done, size: 16),
                              label: const Text('Production Cloud (Render)'),
                              onPressed: () => _applyPreset(ApiConstants.defaultCloudUrl),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.cloud_outlined, size: 16),
                              label: const Text('Hugging Face Space (*.hf.space)'),
                              onPressed: () => _applyPreset('https://<username>-cotton-guard.hf.space/api/v1'),
                            ),
                            ActionChip(
                              label: const Text('Android Emulator (10.0.2.2)'),
                              onPressed: () => _applyPreset(ApiConstants.defaultEmulatorUrl),
                            ),
                            ActionChip(
                              label: const Text('Localhost (127.0.0.1:7860)'),
                              onPressed: () => _applyPreset('http://127.0.0.1:7860/api/v1'),
                            ),
                            ActionChip(
                              label: const Text('Physical Device (LAN IP Template)'),
                              onPressed: () => _applyPreset('http://192.168.1.100:7860/api/v1'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: 'Save & Test Connection',
                                icon: Icons.sync_rounded,
                                isLoading: _isSaving || isChecking,
                                onPressed: _handleSaveAndTest,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Diagnostics Shortcut
                  CustomButton(
                    text: 'Open Diagnostic Test Center',
                    icon: Icons.troubleshoot_rounded,
                    variant: ButtonVariant.outline,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ServerDiagnosticsScreen(
                            storageService: widget.connectionController.health.modelLoaded
                                ? null
                                : null,
                            connectionController: widget.connectionController,
                          ),
                        ),
                      );
                    },
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

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
