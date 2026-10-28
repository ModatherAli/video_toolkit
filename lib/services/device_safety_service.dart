import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'video_compressor_service.dart';

class DeviceSafetyService {
  static const String _prefPauseOnLowBattery = 'pref_pause_on_low_battery';
  static const String _prefRequireCharging = 'pref_require_charging';
  static const String _prefLowBatteryThreshold = 'pref_low_battery_threshold';

  final VideoCompressorService compressorService;
  final ValueNotifier<int> batteryLevelNotifier = ValueNotifier<int>(100);
  final ValueNotifier<bool> isChargingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isThermalThrottlingNotifier = ValueNotifier<bool>(false);

  bool pauseOnLowBattery = true;
  bool requireCharging = false;
  int lowBatteryThreshold = 20;

  DeviceSafetyService({required this.compressorService});

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    pauseOnLowBattery = prefs.getBool(_prefPauseOnLowBattery) ?? true;
    requireCharging = prefs.getBool(_prefRequireCharging) ?? false;
    lowBatteryThreshold = prefs.getInt(_prefLowBatteryThreshold) ?? 20;
    await checkDeviceState();
  }

  Future<void> saveSettings({
    required bool pauseLowBattery,
    required bool reqCharging,
    required int threshold,
  }) async {
    pauseOnLowBattery = pauseLowBattery;
    requireCharging = reqCharging;
    lowBatteryThreshold = threshold;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefPauseOnLowBattery, pauseLowBattery);
    await prefs.setBool(_prefRequireCharging, reqCharging);
    await prefs.setInt(_prefLowBatteryThreshold, threshold);
  }

  Future<Map<String, dynamic>> checkDeviceState() async {
    final status = await compressorService.getDeviceSafetyStatus();
    final battery = (status['batteryLevel'] as num?)?.toInt() ?? 100;
    final charging = status['isCharging'] == true;
    final thermal = status['isThermalThrottling'] == true;

    batteryLevelNotifier.value = battery;
    isChargingNotifier.value = charging;
    isThermalThrottlingNotifier.value = thermal;

    return status;
  }

  /// Evaluates whether compression is safe to run according to safety rules.
  ({bool isSafe, String? reason}) evaluateSafety() {
    if (requireCharging && !isChargingNotifier.value) {
      return (
        isSafe: false,
        reason: 'Device is not plugged into a charger (Charging-Only mode is active).'
      );
    }

    if (pauseOnLowBattery && !isChargingNotifier.value && batteryLevelNotifier.value < lowBatteryThreshold) {
      return (
        isSafe: false,
        reason: 'Battery is at ${batteryLevelNotifier.value}%, below the safe $lowBatteryThreshold% threshold.'
      );
    }

    if (isThermalThrottlingNotifier.value) {
      return (
        isSafe: false,
        reason: 'Device CPU is experiencing thermal throttling. Allow phone to cool down.'
      );
    }

    return (isSafe: true, reason: null);
  }

  void dispose() {
    batteryLevelNotifier.dispose();
    isChargingNotifier.dispose();
    isThermalThrottlingNotifier.dispose();
  }
}
