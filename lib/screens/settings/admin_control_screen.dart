import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../controllers/connection_controller.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/status_badge.dart';

class AdminControlScreen extends StatefulWidget {
  final StorageService storageService;
  final ConnectionController connectionController;

  const AdminControlScreen({
    super.key,
    required this.storageService,
    required this.connectionController,
  });

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  late final ApiService _apiService;
  final TextEditingController _keyController = TextEditingController();

  bool _isLoading = false;
  bool _isActionInProgress = false;
  String? _errorMessage;
  Map<String, dynamic>? _serviceStatus;
  List<dynamic> _auditLogs = [];
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.storageService);
    _checkInitialAccess();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _checkInitialAccess() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getAdminServiceState();
      setState(() {
        _isAuthenticated = true;
        _serviceStatus = res['service_status'] as Map<String, dynamic>?;
        _auditLogs = res['recent_audit_logs'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (_) {
      // Prompt for admin key/password if initial attempt required credentials
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAuthenticate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Administrator Key')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getAdminServiceState(adminKey: key);
      setState(() {
        _isAuthenticated = true;
        _serviceStatus = res['service_status'] as Map<String, dynamic>?;
        _auditLogs = res['recent_audit_logs'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid administrator credentials: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    try {
      final key = _keyController.text.trim();
      final res = await _apiService.getAdminServiceState(adminKey: key.isNotEmpty ? key : null);
      setState(() {
        _serviceStatus = res['service_status'] as Map<String, dynamic>?;
        _auditLogs = res['recent_audit_logs'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleStartService() async {
    setState(() => _isActionInProgress = true);
    try {
      final key = _keyController.text.trim();
      final res = await _apiService.startAdminService(adminKey: key.isNotEmpty ? key : null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String? ?? 'Service started successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _fetchStatus();
      if (!mounted) return;
      await widget.connectionController.checkConnection();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start service: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _handleStopService() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Service Shutdown'),
        content: const Text(
          'Are you sure you want to pause the Cotton Guard AI inference service?\n\n'
          'All mobile users worldwide will be unable to run disease scans until you start the service again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pause Service', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    try {
      final key = _keyController.text.trim();
      final res = await _apiService.stopAdminService(adminKey: key.isNotEmpty ? key : null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String? ?? 'Service stopped successfully.'),
          backgroundColor: AppColors.warning,
        ),
      );
      await _fetchStatus();
      if (!mounted) return;
      await widget.connectionController.checkConnection();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop service: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Inference Control Plane'),
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Status',
              onPressed: _isLoading || _isActionInProgress ? null : _fetchStatus,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isAuthenticated) ...[
                // Authentication Challenge Card
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded, size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'Administrator Authentication',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This panel controls the global AI inference engine running on the cloud server. Please provide administrator credentials.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _keyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Administrator Key / Token',
                          prefixIcon: const Icon(Icons.key_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Authenticate',
                        isLoading: _isLoading,
                        onPressed: _handleAuthenticate,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Authoritative Status Card
                _buildLiveStatusCard(isDark),
                const SizedBox(height: 20),

                // Start / Stop Action Buttons
                _buildActionControls(),
                const SizedBox(height: 24),

                // Audit Logs Section
                _buildAuditLogSection(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard(bool isDark) {
    final state = _serviceStatus?['state'] as String? ?? 'UNKNOWN';
    final isRunning = _serviceStatus?['is_running'] as bool? ?? false;
    final uptime = _serviceStatus?['uptime_seconds'] as num? ?? 0;
    final predictions = _serviceStatus?['predictions_served'] as int? ?? 0;

    Color stateColor;
    IconData stateIcon;

    switch (state) {
      case 'RUNNING':
        stateColor = AppColors.success;
        stateIcon = Icons.check_circle_rounded;
        break;
      case 'STOPPED':
        stateColor = AppColors.warning;
        stateIcon = Icons.pause_circle_filled_rounded;
        break;
      case 'STARTING':
      case 'STOPPING':
        stateColor = AppColors.info;
        stateIcon = Icons.sync_rounded;
        break;
      default:
        stateColor = AppColors.danger;
        stateIcon = Icons.error_rounded;
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cloud Engine State',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              StatusBadge(
                label: state,
                backgroundColor: stateColor.withValues(alpha: 0.15),
                textColor: stateColor,
                hasDot: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(stateIcon, size: 36, color: stateColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRunning
                          ? 'AI inference is LIVE for all users.'
                          : 'Inference is PAUSED. Users cannot scan.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: stateColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uptime: ${uptime}s | Predictions Served: $predictions',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionControls() {
    final state = _serviceStatus?['state'] as String? ?? 'UNKNOWN';
    final isRunning = state == 'RUNNING';
    final isStopped = state == 'STOPPED' || state == 'ERROR';

    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Start Service',
            icon: Icons.play_arrow_rounded,
            isLoading: _isActionInProgress && !isRunning,
            onPressed: isStopped && !_isActionInProgress ? _handleStartService : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: CustomButton(
            text: 'Stop Service',
            icon: Icons.stop_rounded,
            variant: ButtonVariant.danger,
            isLoading: _isActionInProgress && isRunning,
            onPressed: isRunning && !_isActionInProgress ? _handleStopService : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Administrative Audit Logs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_auditLogs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No state transition logs recorded yet.',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
          )
        else
          ..._auditLogs.map((log) {
            final action = log['action'] as String? ?? '';
            final prior = log['prior_state'] as String? ?? '';
            final next = log['new_state'] as String? ?? '';
            final ts = log['timestamp'] as String? ?? '';
            final admin = log['admin_email'] as String? ?? '';

            final isStart = action == 'START_SERVICE';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      isStart ? Icons.play_circle_fill_rounded : Icons.stop_circle_rounded,
                      color: isStart ? AppColors.success : AppColors.danger,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$action ($prior → $next)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$ts by $admin',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
