import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'battery_platform_interface.dart';

RealBatteryPlatform createBatteryPlatform() => RealBatteryIo();

class RealBatteryIo implements RealBatteryPlatform {
  final Battery _battery = Battery();
  int _lastLevel = 75; // Neutral realistic default until instant hardware callback returns
  bool _isCharging = false;
  bool _initialized = false;
  final StreamController<RealDeviceBatteryInfo> _controller =
      StreamController<RealDeviceBatteryInfo>.broadcast();

  void _initIfNeeded() {
    if (_initialized) return;
    _initialized = true;

    // Fetch initial battery level and charging state immediately
    Future.wait([
      _battery.batteryLevel,
      _battery.batteryState,
    ]).then((results) {
      _lastLevel = (results[0] as int).clamp(1, 100);
      final state = results[1] as BatteryState;
      // BatteryState.full means 100% charged and idle.
      // It is ONLY charging when state == BatteryState.charging!
      _isCharging = (state == BatteryState.charging);
      _controller.add(RealDeviceBatteryInfo(level: _lastLevel, isCharging: _isCharging));
    }).catchError((_) {
      _battery.batteryLevel.then((lvl) {
        _lastLevel = lvl.clamp(1, 100);
        _controller.add(RealDeviceBatteryInfo(level: _lastLevel, isCharging: _isCharging));
      }).catchError((_) {});
    });

    // Listen to charging state changes immediately (instant callback when plugged / unplugged)
    _battery.onBatteryStateChanged.listen((state) {
      _isCharging = (state == BatteryState.charging);
      _battery.batteryLevel.then((lvl) {
        _lastLevel = lvl.clamp(1, 100);
        _controller.add(RealDeviceBatteryInfo(level: _lastLevel, isCharging: _isCharging));
      }).catchError((_) {
        _controller.add(RealDeviceBatteryInfo(level: _lastLevel, isCharging: _isCharging));
      });
    }, onError: (_) {});
  }

  @override
  Stream<RealDeviceBatteryInfo> get onBatteryChanged {
    _initIfNeeded();
    return _controller.stream;
  }

  @override
  RealDeviceBatteryInfo getRealBattery() {
    _initIfNeeded();
    // Refresh in background
    _battery.batteryLevel.then((lvl) {
      _lastLevel = lvl.clamp(1, 100);
    }).catchError((_) {});

    return RealDeviceBatteryInfo(level: _lastLevel, isCharging: _isCharging);
  }

  @override
  Future<RealDeviceBatteryInfo> fetchBatteryInfo() async {
    _initIfNeeded();
    try {
      final results = await Future.wait([
        _battery.batteryLevel,
        _battery.batteryState,
      ]);
      _lastLevel = (results[0] as int).clamp(1, 100);
      final state = results[1] as BatteryState;
      _isCharging = (state == BatteryState.charging);
    } catch (_) {
      try {
        final lvl = await _battery.batteryLevel;
        _lastLevel = lvl.clamp(1, 100);
      } catch (_) {}
    }
    return RealDeviceBatteryInfo(level: _lastLevel, isCharging: _isCharging);
  }
}
