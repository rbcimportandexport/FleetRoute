class RealDeviceBatteryInfo {
  final int level;
  final bool isCharging;

  const RealDeviceBatteryInfo({
    required this.level,
    required this.isCharging,
  });
}

abstract class RealBatteryPlatform {
  RealDeviceBatteryInfo getRealBattery();
  Future<RealDeviceBatteryInfo> fetchBatteryInfo();
  Stream<RealDeviceBatteryInfo> get onBatteryChanged;
}
