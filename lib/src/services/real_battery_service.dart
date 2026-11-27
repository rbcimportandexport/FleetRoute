import 'battery/battery_platform_interface.dart';
import 'battery/battery_io.dart' if (dart.library.js_interop) 'battery/battery_web.dart';

export 'battery/battery_platform_interface.dart' show RealDeviceBatteryInfo;

class RealBatteryService {
  RealBatteryService._();
  static final RealBatteryService instance = RealBatteryService._();

  final RealBatteryPlatform _platform = createBatteryPlatform();

  RealDeviceBatteryInfo getRealBattery() {
    return _platform.getRealBattery();
  }

  Future<RealDeviceBatteryInfo> fetchBatteryInfo() {
    return _platform.fetchBatteryInfo();
  }

  Stream<RealDeviceBatteryInfo> get onBatteryChanged {
    return _platform.onBatteryChanged;
  }
}
