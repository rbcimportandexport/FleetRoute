import 'dart:async';
import 'battery_platform_interface.dart';

RealBatteryPlatform createBatteryPlatform() => RealBatteryWeb();

class RealBatteryWeb implements RealBatteryPlatform {
  final StreamController<RealDeviceBatteryInfo> _controller =
      StreamController<RealDeviceBatteryInfo>.broadcast();

  @override
  Stream<RealDeviceBatteryInfo> get onBatteryChanged => _controller.stream;

  @override
  RealDeviceBatteryInfo getRealBattery() {
    return const RealDeviceBatteryInfo(level: 75, isCharging: false);
  }

  @override
  Future<RealDeviceBatteryInfo> fetchBatteryInfo() async {
    return getRealBattery();
  }
}
