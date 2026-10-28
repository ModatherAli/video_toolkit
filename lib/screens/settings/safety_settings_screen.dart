import 'package:flutter/material.dart';
import '../../services/device_safety_service.dart';
import '../../theme/app_colors.dart';

class SafetySettingsScreen extends StatefulWidget {
  final DeviceSafetyService safetyService;

  const SafetySettingsScreen({super.key, required this.safetyService});

  @override
  State<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends State<SafetySettingsScreen> {
  late bool _pauseOnLowBattery;
  late bool _requireCharging;
  late int _threshold;
  bool _fastStartMp4 = true;

  @override
  void initState() {
    super.initState();
    _pauseOnLowBattery = widget.safetyService.pauseOnLowBattery;
    _requireCharging = widget.safetyService.requireCharging;
    _threshold = widget.safetyService.lowBatteryThreshold;
    widget.safetyService.checkDeviceState();
  }

  Future<void> _save() async {
    await widget.safetyService.saveSettings(
      pauseLowBattery: _pauseOnLowBattery,
      reqCharging: _requireCharging,
      threshold: _threshold,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Safety settings updated.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device & Thermal Safety'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Live Device Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Live Device Telemetry',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<int>(
                  valueListenable: widget.safetyService.batteryLevelNotifier,
                  builder: (context, battery, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: widget.safetyService.isChargingNotifier,
                      builder: (context, isCharging, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: widget.safetyService.isThermalThrottlingNotifier,
                          builder: (context, isThrottling, _) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatusIndicator(
                                  icon: isCharging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded,
                                  label: '$battery%',
                                  sublabel: isCharging ? 'Charging' : 'On Battery',
                                  color: battery > 20 ? AppColors.success : AppColors.warning,
                                ),
                                _buildStatusIndicator(
                                  icon: Icons.thermostat_rounded,
                                  label: isThrottling ? 'High Temp' : 'Optimal',
                                  sublabel: 'CPU Heat',
                                  color: isThrottling ? AppColors.error : AppColors.success,
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Protection Rules',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),

          // Pause on Low Battery Switch
          SwitchListTile(
            title: const Text('Pause on Low Battery', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Prevents phone from dying during compression jobs below $_threshold%.'),
            value: _pauseOnLowBattery,
            onChanged: (val) {
              setState(() => _pauseOnLowBattery = val);
              _save();
            },
          ),
          if (_pauseOnLowBattery) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Threshold:', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _threshold.toDouble(),
                      min: 10,
                      max: 40,
                      divisions: 6,
                      label: '$_threshold%',
                      onChanged: (val) {
                        setState(() => _threshold = val.toInt());
                        _save();
                      },
                    ),
                  ),
                  Text('$_threshold%', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          const Divider(),

          // Require Charging Switch
          SwitchListTile(
            title: const Text('Process Only While Charging', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Runs batch compression exclusively when plugged into wall power.'),
            value: _requireCharging,
            onChanged: (val) {
              setState(() => _requireCharging = val);
              _save();
            },
          ),
          const Divider(),

          // Faststart MP4
          SwitchListTile(
            title: const Text('Faststart MP4 (moov at front)', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Enables instant video playback when sharing to WhatsApp and web links.'),
            value: _fastStartMp4,
            onChanged: (val) {
              setState(() => _fastStartMp4 = val);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(sublabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
