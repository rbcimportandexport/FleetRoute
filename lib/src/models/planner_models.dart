import 'package:flutter/material.dart';

String _jsonString(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

bool _jsonBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

int _jsonInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

DateTime _jsonDateTime(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

double _jsonDouble(Object? value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

enum VehicleType { bike, car, truck }

extension VehicleTypeView on VehicleType {
  String get label => switch (this) {
        VehicleType.bike => 'Bike',
        VehicleType.car => 'Car',
        VehicleType.truck => 'Truck',
      };

  String get caption => switch (this) {
        VehicleType.bike => 'Two-Wheeler',
        VehicleType.car => 'Passenger / Light',
        VehicleType.truck => 'Commercial Fleet',
      };

  IconData get icon => switch (this) {
        VehicleType.bike => Icons.two_wheeler_rounded,
        VehicleType.car => Icons.directions_car_rounded,
        VehicleType.truck => Icons.local_shipping_rounded,
      };
}

class GpsBreadcrumb {
  const GpsBreadcrumb({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.course,
    required this.timestamp,
    this.isIgnitionOn = false,
  });

  final double latitude;
  final double longitude;
  final double speed;
  final double course;
  final DateTime timestamp;
  final bool isIgnitionOn;

  Map<String, Object> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'course': course,
        'timestamp': timestamp.toIso8601String(),
        'isIgnitionOn': isIgnitionOn,
      };

  factory GpsBreadcrumb.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return GpsBreadcrumb(
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      speed: parseDouble(json['speed']),
      course: parseDouble(json['course']),
      timestamp: _jsonDateTime(json['timestamp']),
      isIgnitionOn: _jsonBool(json['isIgnitionOn']),
    );
  }
}

class FastagRechargeRecord {
  const FastagRechargeRecord({
    required this.id,
    required this.amount,
    required this.date,
    this.refNumber = '',
    this.provider = 'Paytm Payments Bank',
    this.notes = '',
  });

  final String id;
  final double amount;
  final String date;
  final String refNumber;
  final String provider;
  final String notes;

  String get rechargeId => refNumber.isNotEmpty ? refNumber : id;

  Map<String, Object> toJson() => {
        'id': id,
        'amount': amount,
        'date': date,
        'refNumber': refNumber,
        'provider': provider,
        'notes': notes,
      };

  factory FastagRechargeRecord.fromJson(Map<String, dynamic> json) =>
      FastagRechargeRecord(
        id: _jsonString(json['id']),
        amount: _jsonDouble(json['amount']),
        date: _jsonString(json['date']),
        refNumber: _jsonString(json['refNumber']),
        provider: _jsonString(json['provider'], 'Paytm Payments Bank'),
        notes: _jsonString(json['notes']),
      );
}

class TyreRecord {
  const TyreRecord({
    required this.tyreNumber,
    required this.position,
    this.fittingDate = '',
    this.fittingKm = 0,
    this.currentKm = 0,
    this.replacementCost = 0.0,
    this.condition = 'Good',
    this.notes = '',
  });

  final String tyreNumber;
  final String position;
  final String fittingDate;
  final int fittingKm;
  final int currentKm;
  final double replacementCost;
  final String condition;
  final String notes;

  int get kmRun => (currentKm >= fittingKm && fittingKm > 0)
      ? (currentKm - fittingKm)
      : currentKm;

  TyreRecord copyWith({
    String? tyreNumber,
    String? position,
    String? fittingDate,
    int? fittingKm,
    int? currentKm,
    double? replacementCost,
    String? condition,
    String? notes,
  }) =>
      TyreRecord(
        tyreNumber: tyreNumber ?? this.tyreNumber,
        position: position ?? this.position,
        fittingDate: fittingDate ?? this.fittingDate,
        fittingKm: fittingKm ?? this.fittingKm,
        currentKm: currentKm ?? this.currentKm,
        replacementCost: replacementCost ?? this.replacementCost,
        condition: condition ?? this.condition,
        notes: notes ?? this.notes,
      );

  Map<String, Object> toJson() => {
        'tyreNumber': tyreNumber,
        'position': position,
        'fittingDate': fittingDate,
        'fittingKm': fittingKm,
        'currentKm': currentKm,
        'replacementCost': replacementCost,
        'condition': condition,
        'notes': notes,
      };

  factory TyreRecord.fromJson(Map<String, dynamic> json) => TyreRecord(
        tyreNumber: _jsonString(json['tyreNumber']),
        position: _jsonString(json['position'], 'Front Left'),
        fittingDate: _jsonString(json['fittingDate']),
        fittingKm: _jsonInt(json['fittingKm']),
        currentKm: _jsonInt(json['currentKm']),
        replacementCost: _jsonDouble(json['replacementCost']),
        condition: _jsonString(json['condition'], 'Good'),
        notes: _jsonString(json['notes']),
      );
}

class VehicleServiceRecord {
  const VehicleServiceRecord({
    required this.id,
    required this.serviceDate,
    this.odometerKm = 0,
    this.garageName = '',
    this.mechanicDetails = '',
    this.engineOilChanged = false,
    this.brakeChecked = false,
    this.batteryChecked = false,
    this.coolantChecked = false,
    this.sparePartsReplaced = '',
    this.repairCost = 0.0,
    this.notes = '',
  });

  final String id;
  final String serviceDate;
  final int odometerKm;
  final String garageName;
  final String mechanicDetails;
  final bool engineOilChanged;
  final bool brakeChecked;
  final bool batteryChecked;
  final bool coolantChecked;
  final String sparePartsReplaced;
  final double repairCost;
  final String notes;

  Map<String, Object> toJson() => {
        'id': id,
        'serviceDate': serviceDate,
        'odometerKm': odometerKm,
        'garageName': garageName,
        'mechanicDetails': mechanicDetails,
        'engineOilChanged': engineOilChanged,
        'brakeChecked': brakeChecked,
        'batteryChecked': batteryChecked,
        'coolantChecked': coolantChecked,
        'sparePartsReplaced': sparePartsReplaced,
        'repairCost': repairCost,
        'notes': notes,
      };

  factory VehicleServiceRecord.fromJson(Map<String, dynamic> json) =>
      VehicleServiceRecord(
        id: _jsonString(json['id']),
        serviceDate: _jsonString(json['serviceDate']),
        odometerKm: _jsonInt(json['odometerKm']),
        garageName: _jsonString(json['garageName']),
        mechanicDetails: _jsonString(json['mechanicDetails']),
        engineOilChanged: _jsonBool(json['engineOilChanged']),
        brakeChecked: _jsonBool(json['brakeChecked']),
        batteryChecked: _jsonBool(json['batteryChecked']),
        coolantChecked: _jsonBool(json['coolantChecked']),
        sparePartsReplaced: _jsonString(json['sparePartsReplaced']),
        repairCost: _jsonDouble(json['repairCost']),
        notes: _jsonString(json['notes']),
      );
}

class TruckModel {
  const TruckModel({
    required this.code,
    required this.name,
    required this.axles,
    required this.capacity,
    this.maxSpeed = 80,
    this.imei = '',
    this.currentLat,
    this.currentLng,
    this.currentSpeed = 0.0,
    this.course = 0.0,
    this.isIgnitionOn = false,
    this.lastGpsUpdate = '',
    this.hasValidGpsFix = false,
    this.isDemoTelemetry = false,
    this.gpsHistory = const [],
    this.fastagBalance = 0.0,
    this.fitnessExpiry = '',
    this.insuranceExpiry = '',
    this.isInsuranceAutoPay = false,
    this.isServiceAutoPay = false,
    this.rcExpiry = '',
    this.pucExpiry = '',
    this.statePermitTaxExpiry = '',
    this.allIndiaPermitExpiry = '',
    this.nextServiceKm = 0,
    this.currentOdometerKm = 0,
    this.tyres = const [],
    this.serviceHistory = const [],
    this.fastagRecharges = const [],
    this.ownerName = '',
    this.vehicleModel = '',
    this.payloadCapacity = '',
    this.vehicleStatus = 'available',
    this.assignedDriver = '',
    this.insuranceNumber = '',
    this.pucNumber = '',
    this.fitnessNumber = '',
    this.aitpNumber = '',
    this.statePermitNumber = '',
    this.maintenanceNotes = '',
    this.isArchived = false,
  });

  final String code;
  final String name;
  final String axles;
  final String capacity;
  final int maxSpeed;
  final String imei;
  final double? currentLat;
  final double? currentLng;
  final double currentSpeed;
  final double course;
  final bool isIgnitionOn;
  final String lastGpsUpdate;
  final bool hasValidGpsFix;
  final bool isDemoTelemetry;
  final List<GpsBreadcrumb> gpsHistory;

  // Fleet Compliance & Operations
  final double fastagBalance;
  final String fitnessExpiry;
  final String insuranceExpiry;
  final bool isInsuranceAutoPay;
  final bool isServiceAutoPay;
  final String rcExpiry;
  final String pucExpiry;
  final String statePermitTaxExpiry;
  final String allIndiaPermitExpiry;
  final int nextServiceKm;
  final int currentOdometerKm;
  final List<TyreRecord> tyres;
  final List<VehicleServiceRecord> serviceHistory;
  final List<FastagRechargeRecord> fastagRecharges;

  // Vehicle Management & Details
  final String ownerName;
  final String vehicleModel;
  final String payloadCapacity;
  final String
      vehicleStatus; // available, assigned, in_service, under_maintenance, disabled
  final String assignedDriver;
  final String insuranceNumber;
  final String pucNumber;
  final String fitnessNumber;
  final String aitpNumber;
  final String statePermitNumber;
  final String maintenanceNotes;
  final bool isArchived;

  bool get isAvailable =>
      (vehicleStatus == 'available' || vehicleStatus.isEmpty) && !isArchived;
  bool get isDisabled => vehicleStatus == 'disabled' || isArchived;
  bool get isUnderMaintenance => vehicleStatus == 'under_maintenance';
  bool get isAssigned => vehicleStatus == 'assigned';
  bool get isInService => vehicleStatus == 'in_service';

  double get numericPayloadCapacityTon {
    final match = RegExp(r'([\d.]+)').firstMatch(payloadCapacity);
    return match != null ? (double.tryParse(match.group(1) ?? '') ?? 0.0) : 0.0;
  }

  int get kmUntilNextService =>
      nextServiceKm > currentOdometerKm ? nextServiceKm - currentOdometerKm : 0;
  bool get isServiceDueSoon => kmUntilNextService <= 1000;
  bool get isFastagLow => fastagBalance < 500;

  String get maskedImei {
    final clean = imei.trim();
    if (clean.length < 8) return clean;
    return '${clean.substring(0, 4)}****${clean.substring(clean.length - 4)}';
  }

  bool get hasCoordinates =>
      currentLat != null &&
      currentLng != null &&
      currentLat! >= -90.0 &&
      currentLat! <= 90.0 &&
      currentLng! >= -180.0 &&
      currentLng! <= 180.0 &&
      (currentLat!.abs() > 0.0001 || currentLng!.abs() > 0.0001);

  double? get latitude => currentLat;
  double? get longitude => currentLng;

  bool get isNeverSynced => lastGpsUpdate.trim().isEmpty && currentLat == null;

  DateTime? get lastGpsDateTime {
    if (lastGpsUpdate.trim().isEmpty) return null;
    return DateTime.tryParse(lastGpsUpdate);
  }

  DateTime? get lastGpsTime => lastGpsDateTime;

  bool get isGpsStale {
    final dt = lastGpsDateTime;
    if (dt == null) return true;
    return DateTime.now().difference(dt) > const Duration(minutes: 5);
  }

  bool get isMoving =>
      hasValidGpsFix &&
      !isDemoTelemetry &&
      !isGpsStale &&
      isIgnitionOn &&
      currentSpeed >= 3.0;

  TruckModel copyWith({
    String? code,
    String? name,
    String? axles,
    String? capacity,
    int? maxSpeed,
    String? imei,
    double? currentLat,
    double? currentLng,
    double? currentSpeed,
    double? course,
    bool? isIgnitionOn,
    String? lastGpsUpdate,
    bool? hasValidGpsFix,
    bool? isDemoTelemetry,
    List<GpsBreadcrumb>? gpsHistory,
    bool clearGpsCoordinates = false,
    double? fastagBalance,
    String? fitnessExpiry,
    String? insuranceExpiry,
    bool? isInsuranceAutoPay,
    bool? isServiceAutoPay,
    String? rcExpiry,
    String? pucExpiry,
    String? statePermitTaxExpiry,
    String? allIndiaPermitExpiry,
    int? nextServiceKm,
    int? currentOdometerKm,
    List<TyreRecord>? tyres,
    List<VehicleServiceRecord>? serviceHistory,
    List<FastagRechargeRecord>? fastagRecharges,
    String? ownerName,
    String? vehicleModel,
    String? payloadCapacity,
    String? vehicleStatus,
    String? assignedDriver,
    String? insuranceNumber,
    String? pucNumber,
    String? fitnessNumber,
    String? aitpNumber,
    String? statePermitNumber,
    String? maintenanceNotes,
    bool? isArchived,
  }) =>
      TruckModel(
        code: code ?? this.code,
        name: name ?? this.name,
        axles: axles ?? this.axles,
        capacity: capacity ?? this.capacity,
        maxSpeed: maxSpeed ?? this.maxSpeed,
        imei: imei ?? this.imei,
        currentLat:
            clearGpsCoordinates ? null : (currentLat ?? this.currentLat),
        currentLng:
            clearGpsCoordinates ? null : (currentLng ?? this.currentLng),
        currentSpeed: currentSpeed ?? this.currentSpeed,
        course: course ?? this.course,
        isIgnitionOn: isIgnitionOn ?? this.isIgnitionOn,
        lastGpsUpdate: lastGpsUpdate ?? this.lastGpsUpdate,
        hasValidGpsFix: clearGpsCoordinates
            ? false
            : (hasValidGpsFix ?? this.hasValidGpsFix),
        isDemoTelemetry: isDemoTelemetry ?? this.isDemoTelemetry,
        gpsHistory: gpsHistory ?? this.gpsHistory,
        fastagBalance: fastagBalance ?? this.fastagBalance,
        fitnessExpiry: fitnessExpiry ?? this.fitnessExpiry,
        insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
        isInsuranceAutoPay: isInsuranceAutoPay ?? this.isInsuranceAutoPay,
        isServiceAutoPay: isServiceAutoPay ?? this.isServiceAutoPay,
        rcExpiry: rcExpiry ?? this.rcExpiry,
        pucExpiry: pucExpiry ?? this.pucExpiry,
        statePermitTaxExpiry: statePermitTaxExpiry ?? this.statePermitTaxExpiry,
        allIndiaPermitExpiry: allIndiaPermitExpiry ?? this.allIndiaPermitExpiry,
        nextServiceKm: nextServiceKm ?? this.nextServiceKm,
        currentOdometerKm: currentOdometerKm ?? this.currentOdometerKm,
        tyres: tyres ?? this.tyres,
        serviceHistory: serviceHistory ?? this.serviceHistory,
        fastagRecharges: fastagRecharges ?? this.fastagRecharges,
        ownerName: ownerName ?? this.ownerName,
        vehicleModel: vehicleModel ?? this.vehicleModel,
        payloadCapacity: payloadCapacity ?? this.payloadCapacity,
        vehicleStatus: vehicleStatus ?? this.vehicleStatus,
        assignedDriver: assignedDriver ?? this.assignedDriver,
        insuranceNumber: insuranceNumber ?? this.insuranceNumber,
        pucNumber: pucNumber ?? this.pucNumber,
        fitnessNumber: fitnessNumber ?? this.fitnessNumber,
        aitpNumber: aitpNumber ?? this.aitpNumber,
        statePermitNumber: statePermitNumber ?? this.statePermitNumber,
        maintenanceNotes: maintenanceNotes ?? this.maintenanceNotes,
        isArchived: isArchived ?? this.isArchived,
      );

  Map<String, Object> toJson() => {
        'code': code,
        'name': name,
        'axles': axles,
        'capacity': capacity,
        'maxSpeed': maxSpeed,
        'imei': imei,
        if (currentLat != null) 'currentLat': currentLat!,
        if (currentLng != null) 'currentLng': currentLng!,
        'currentSpeed': currentSpeed,
        'course': course,
        'isIgnitionOn': isIgnitionOn,
        'lastGpsUpdate': lastGpsUpdate,
        'hasValidGpsFix': hasValidGpsFix,
        'isDemoTelemetry': isDemoTelemetry,
        'gpsHistory': gpsHistory.map((b) => b.toJson()).toList(),
        'fastagBalance': fastagBalance,
        'fitnessExpiry': fitnessExpiry,
        'insuranceExpiry': insuranceExpiry,
        'isInsuranceAutoPay': isInsuranceAutoPay,
        'isServiceAutoPay': isServiceAutoPay,
        'rcExpiry': rcExpiry,
        'pucExpiry': pucExpiry,
        'statePermitTaxExpiry': statePermitTaxExpiry,
        'allIndiaPermitExpiry': allIndiaPermitExpiry,
        'nextServiceKm': nextServiceKm,
        'currentOdometerKm': currentOdometerKm,
        'tyres': tyres.map((t) => t.toJson()).toList(),
        'serviceHistory': serviceHistory.map((s) => s.toJson()).toList(),
        'fastagRecharges': fastagRecharges.map((f) => f.toJson()).toList(),
        'ownerName': ownerName,
        'vehicleModel': vehicleModel,
        'payloadCapacity': payloadCapacity,
        'vehicleStatus': vehicleStatus,
        'assignedDriver': assignedDriver,
        'insuranceNumber': insuranceNumber,
        'pucNumber': pucNumber,
        'fitnessNumber': fitnessNumber,
        'aitpNumber': aitpNumber,
        'statePermitNumber': statePermitNumber,
        'maintenanceNotes': maintenanceNotes,
        'isArchived': isArchived,
      };

  factory TruckModel.fromJson(Map<String, dynamic> json) {
    final rawSpeed = json['maxSpeed'];
    final maxSpeed = rawSpeed is num
        ? rawSpeed.toInt()
        : int.tryParse(rawSpeed?.toString() ?? '') ?? 80;

    double? lat;
    if (json['currentLat'] != null) {
      final rawLat = json['currentLat'];
      lat = rawLat is num
          ? rawLat.toDouble()
          : double.tryParse(rawLat.toString());
    }
    double? lng;
    if (json['currentLng'] != null) {
      final rawLng = json['currentLng'];
      lng = rawLng is num
          ? rawLng.toDouble()
          : double.tryParse(rawLng.toString());
    }
    double speed = 0.0;
    if (json['currentSpeed'] != null) {
      final rawSpeed = json['currentSpeed'];
      speed = rawSpeed is num
          ? rawSpeed.toDouble()
          : double.tryParse(rawSpeed.toString()) ?? 0.0;
    }
    double courseVal = 0.0;
    if (json['course'] != null) {
      final rawCourse = json['course'];
      courseVal = rawCourse is num
          ? rawCourse.toDouble()
          : double.tryParse(rawCourse.toString()) ?? 0.0;
    }

    final history = <GpsBreadcrumb>[];
    if (json['gpsHistory'] is List) {
      for (final item in json['gpsHistory'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            history.add(GpsBreadcrumb.fromJson(item));
          } catch (_) {
            // Discard single malformed breadcrumb without failing whole vehicle
          }
        }
      }
    }

    final tyresList = <TyreRecord>[];
    if (json['tyres'] is List) {
      for (final item in json['tyres'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            tyresList.add(TyreRecord.fromJson(item));
          } catch (_) {}
        }
      }
    }

    final servicesList = <VehicleServiceRecord>[];
    if (json['serviceHistory'] is List) {
      for (final item in json['serviceHistory'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            servicesList.add(VehicleServiceRecord.fromJson(item));
          } catch (_) {}
        }
      }
    }

    final rechargesList = <FastagRechargeRecord>[];
    if (json['fastagRecharges'] is List) {
      for (final item in json['fastagRecharges'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            rechargesList.add(FastagRechargeRecord.fromJson(item));
          } catch (_) {}
        }
      }
    }

    return TruckModel(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      axles: json['axles']?.toString() ?? '',
      capacity: json['capacity']?.toString() ?? '',
      maxSpeed: maxSpeed,
      imei: json['imei']?.toString() ?? '',
      currentLat: lat,
      currentLng: lng,
      currentSpeed: speed,
      course: courseVal,
      isIgnitionOn: _jsonBool(json['isIgnitionOn']),
      lastGpsUpdate: json['lastGpsUpdate']?.toString() ?? '',
      hasValidGpsFix: _jsonBool(json['hasValidGpsFix']),
      isDemoTelemetry: _jsonBool(json['isDemoTelemetry']),
      gpsHistory: history,
      fastagBalance: _jsonDouble(json['fastagBalance']),
      fitnessExpiry: _jsonString(json['fitnessExpiry']),
      insuranceExpiry: _jsonString(json['insuranceExpiry']),
      isInsuranceAutoPay: _jsonBool(json['isInsuranceAutoPay']),
      isServiceAutoPay: _jsonBool(json['isServiceAutoPay'], false),
      rcExpiry: _jsonString(json['rcExpiry']),
      pucExpiry: _jsonString(json['pucExpiry']),
      statePermitTaxExpiry: _jsonString(json['statePermitTaxExpiry']),
      allIndiaPermitExpiry: _jsonString(json['allIndiaPermitExpiry']),
      nextServiceKm: _jsonInt(json['nextServiceKm']),
      currentOdometerKm: _jsonInt(json['currentOdometerKm']),
      tyres: tyresList,
      serviceHistory: servicesList,
      fastagRecharges: rechargesList,
      ownerName: _jsonString(json['ownerName']),
      vehicleModel: _jsonString(json['vehicleModel']),
      payloadCapacity: _jsonString(json['payloadCapacity']),
      vehicleStatus: _jsonString(json['vehicleStatus'], 'available'),
      assignedDriver: _jsonString(json['assignedDriver']),
      insuranceNumber: _jsonString(json['insuranceNumber']),
      pucNumber: _jsonString(json['pucNumber']),
      fitnessNumber: _jsonString(json['fitnessNumber']),
      aitpNumber: _jsonString(json['aitpNumber']),
      statePermitNumber: _jsonString(json['statePermitNumber']),
      maintenanceNotes: _jsonString(json['maintenanceNotes']),
      isArchived: _jsonBool(json['isArchived']),
    );
  }
}

class DriverProfile {
  const DriverProfile(
    this.name,
    this.email, {
    this.photo = '',
    this.phone = '',
    this.password = '',
    this.assignedVehicle = '',
    this.role = 'driver',
    this.createdAt = '',
    this.licenseNumber = '',
    this.licenseExpiry = '',
    this.driverInsurancePolicy = '',
    this.driverInsuranceExpiry = '',
    this.completedTripsCount = 0,
    this.totalKilometersDriven = 0,
    this.violationsCount = 0,
  });

  final String name;
  final String email;
  final String photo;
  final String phone;
  final String password;
  final String assignedVehicle;
  final String role;
  final String createdAt;

  // Driver Compliance & History
  final String licenseNumber;
  final String licenseExpiry;
  final String driverInsurancePolicy;
  final String driverInsuranceExpiry;
  final int completedTripsCount;
  final int totalKilometersDriven;
  final int violationsCount;

  String get effectivePhone => phone.isNotEmpty ? phone : email;

  DriverProfile copyWith({
    String? name,
    String? email,
    String? photo,
    String? phone,
    String? password,
    String? assignedVehicle,
    String? role,
    String? createdAt,
    String? licenseNumber,
    String? licenseExpiry,
    String? driverInsurancePolicy,
    String? driverInsuranceExpiry,
    int? completedTripsCount,
    int? totalKilometersDriven,
    int? violationsCount,
  }) =>
      DriverProfile(
        name ?? this.name,
        email ?? this.email,
        photo: photo ?? this.photo,
        phone: phone ?? this.phone,
        password: password ?? this.password,
        assignedVehicle: assignedVehicle ?? this.assignedVehicle,
        role: role ?? this.role,
        createdAt: createdAt ?? this.createdAt,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        licenseExpiry: licenseExpiry ?? this.licenseExpiry,
        driverInsurancePolicy:
            driverInsurancePolicy ?? this.driverInsurancePolicy,
        driverInsuranceExpiry:
            driverInsuranceExpiry ?? this.driverInsuranceExpiry,
        completedTripsCount: completedTripsCount ?? this.completedTripsCount,
        totalKilometersDriven:
            totalKilometersDriven ?? this.totalKilometersDriven,
        violationsCount: violationsCount ?? this.violationsCount,
      );

  Map<String, Object> toJson() => {
        'name': name,
        'email': email,
        'phone': phone.isNotEmpty ? phone : email,
        'photo': photo,
        'password': password,
        'assignedVehicle': assignedVehicle,
        'role': role,
        'createdAt': createdAt,
        'licenseNumber': licenseNumber,
        'licenseExpiry': licenseExpiry,
        'driverInsurancePolicy': driverInsurancePolicy,
        'driverInsuranceExpiry': driverInsuranceExpiry,
        'completedTripsCount': completedTripsCount,
        'totalKilometersDriven': totalKilometersDriven,
        'violationsCount': violationsCount,
      };

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
        _jsonString(json['name']),
        _jsonString(json['email'] ?? json['phone']),
        photo: _jsonString(json['photo']),
        phone: _jsonString(json['phone']),
        password: _jsonString(json['password']),
        assignedVehicle: _jsonString(json['assignedVehicle']),
        role: _jsonString(json['role'], 'driver'),
        createdAt: _jsonString(json['createdAt']),
        licenseNumber: _jsonString(json['licenseNumber']),
        licenseExpiry: _jsonString(json['licenseExpiry']),
        driverInsurancePolicy: _jsonString(json['driverInsurancePolicy']),
        driverInsuranceExpiry: _jsonString(json['driverInsuranceExpiry']),
        completedTripsCount: _jsonInt(json['completedTripsCount']),
        totalKilometersDriven: _jsonInt(json['totalKilometersDriven']),
        violationsCount: _jsonInt(json['violationsCount'], 0),
      );
}

class TripRecord {
  const TripRecord({
    required this.reference,
    required this.origin,
    required this.destination,
    this.stops = const [],
    this.status = 'planned',
    this.createdAt = '',
    this.tripNumber = '',
    this.customerName = '',
    this.assignedVehicle = '',
    this.assignedDriver = '',
    this.cargoDescription = 'General Cargo / Heavy Goods',
    this.ewayBillNumber = '',
    this.ewayBillPhoto = '',
    this.loadingDateTime = '',
    this.unloadingDateTime = '',
    this.pickupStatus = 'pending',
    this.deliveryStatus = 'pending',
    this.podPhoto = '',
    this.podStatus = 'pending',
    this.podReceivedAt = '',
    this.receivingCopyPhoto = '',
    this.receivingCopyStatus = 'pending',
    this.freightAmount = 0.0,
    this.advancePaid = 0.0,
    this.customerInvoiceNumber = '',
    this.customerInvoiceStatus = 'draft',
    this.dieselExpense = 0.0,
    this.tollExpense = 0.0,
    this.parkingExpense = 0.0,
    this.driverAllowance = 0.0,
    this.otherExpense = 0.0,
    this.expenseNotes = '',
    this.expenseSlips = const [],
    this.cargoItems = const [],
    this.cargoLedger = const [],
    this.deliveryProofs = const [],
    this.departureDateTime = '',
    this.returnDepot = '',
    this.driverInstructions = '',
    this.currentStopIndex = 0,
    this.operationalStep = 'not_started',
    this.deliveryProof,
    this.plannedDistanceKm = 0,
    this.plannedDurationMinutes = 0,
    this.trafficSummary = '',
    this.startedAt = '',
    this.completedAt = '',
    this.actualDistanceKm = 0,
    this.averageSpeedKmh = 0,
  });

  final String reference;
  final String origin;
  final String destination;
  final List<String> stops;
  final String status;
  final String createdAt;

  // Operations & Financials
  final String tripNumber;
  final String customerName;
  final String assignedVehicle;
  final String assignedDriver;
  final String cargoDescription;
  final String ewayBillNumber;
  final String ewayBillPhoto;
  final String loadingDateTime;
  final String unloadingDateTime;
  final String pickupStatus;
  final String deliveryStatus;
  final String podPhoto;
  final String podStatus;
  final String podReceivedAt;
  final String receivingCopyPhoto;
  final String receivingCopyStatus;
  final double freightAmount;
  final double advancePaid;
  final String customerInvoiceNumber;
  final String customerInvoiceStatus;
  final double dieselExpense;
  final double tollExpense;
  final double parkingExpense;
  final double driverAllowance;
  final double otherExpense;
  final String expenseNotes;
  final List<String> expenseSlips;

  // Cargo & Step Workflow
  final List<CargoItem> cargoItems;
  final List<CargoLedgerEntry> cargoLedger;
  final List<DeliveryProofRecord> deliveryProofs;
  final String departureDateTime;
  final String returnDepot;
  final String driverInstructions;
  final int currentStopIndex;
  final String
      operationalStep; // not_started, navigating, arrived_loading, loading_started, loading_completed, navigating_drop, arrived_drop, unloading_started, unloading_completed, trip_completed
  final DeliveryProofRecord? deliveryProof;
  final double plannedDistanceKm;
  final int plannedDurationMinutes;
  final String trafficSummary;
  final String startedAt;
  final String completedAt;
  final double actualDistanceKm;
  final double averageSpeedKmh;

  Duration? get actualDuration {
    final start = DateTime.tryParse(startedAt);
    final end = DateTime.tryParse(completedAt);
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start);
  }

  String get effectiveTripNumber =>
      tripNumber.isNotEmpty ? tripNumber : reference;

  double get totalExpenses =>
      dieselExpense +
      tollExpense +
      parkingExpense +
      driverAllowance +
      otherExpense;
  double get netProfit => freightAmount - totalExpenses;
  double get profitMarginPercentage =>
      freightAmount > 0 ? (netProfit / freightAmount) * 100 : 0.0;
  double get balanceDue => freightAmount - advancePaid;
  bool get isProfitable => netProfit >= 0;

  double get totalLoadedCargo =>
      cargoItems.fold(0.0, (sum, i) => sum + i.loadedQuantity);
  double get totalDeliveredCargo =>
      cargoItems.fold(0.0, (sum, i) => sum + i.deliveredQuantity);
  double get totalDamagedCargo =>
      cargoItems.fold(0.0, (sum, i) => sum + i.damagedQuantity);
  double get totalReturnedCargo =>
      cargoItems.fold(0.0, (sum, i) => sum + i.returnedQuantity);
  double get totalRemainingCargo =>
      cargoItems.fold(0.0, (sum, i) => sum + i.remainingQuantity);
  double get totalPendingCargo => totalRemainingCargo;

  TripRecord copyWith({
    String? reference,
    String? origin,
    String? destination,
    List<String>? stops,
    String? status,
    String? createdAt,
    String? tripNumber,
    String? customerName,
    String? assignedVehicle,
    String? assignedDriver,
    String? cargoDescription,
    String? ewayBillNumber,
    String? ewayBillPhoto,
    String? loadingDateTime,
    String? unloadingDateTime,
    String? pickupStatus,
    String? deliveryStatus,
    String? podPhoto,
    String? podStatus,
    String? podReceivedAt,
    String? receivingCopyPhoto,
    String? receivingCopyStatus,
    double? freightAmount,
    double? advancePaid,
    String? customerInvoiceNumber,
    String? customerInvoiceStatus,
    double? dieselExpense,
    double? tollExpense,
    double? parkingExpense,
    double? driverAllowance,
    double? otherExpense,
    String? expenseNotes,
    List<String>? expenseSlips,
    List<CargoItem>? cargoItems,
    List<CargoLedgerEntry>? cargoLedger,
    List<DeliveryProofRecord>? deliveryProofs,
    String? departureDateTime,
    String? returnDepot,
    String? driverInstructions,
    int? currentStopIndex,
    String? operationalStep,
    DeliveryProofRecord? deliveryProof,
    double? plannedDistanceKm,
    int? plannedDurationMinutes,
    String? trafficSummary,
    String? startedAt,
    String? completedAt,
    double? actualDistanceKm,
    double? averageSpeedKmh,
  }) =>
      TripRecord(
        reference: reference ?? this.reference,
        origin: origin ?? this.origin,
        destination: destination ?? this.destination,
        stops: stops ?? this.stops,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        tripNumber: tripNumber ?? this.tripNumber,
        customerName: customerName ?? this.customerName,
        assignedVehicle: assignedVehicle ?? this.assignedVehicle,
        assignedDriver: assignedDriver ?? this.assignedDriver,
        cargoDescription: cargoDescription ?? this.cargoDescription,
        ewayBillNumber: ewayBillNumber ?? this.ewayBillNumber,
        ewayBillPhoto: ewayBillPhoto ?? this.ewayBillPhoto,
        loadingDateTime: loadingDateTime ?? this.loadingDateTime,
        unloadingDateTime: unloadingDateTime ?? this.unloadingDateTime,
        pickupStatus: pickupStatus ?? this.pickupStatus,
        deliveryStatus: deliveryStatus ?? this.deliveryStatus,
        podPhoto: podPhoto ?? this.podPhoto,
        podStatus: podStatus ?? this.podStatus,
        podReceivedAt: podReceivedAt ?? this.podReceivedAt,
        receivingCopyPhoto: receivingCopyPhoto ?? this.receivingCopyPhoto,
        receivingCopyStatus: receivingCopyStatus ?? this.receivingCopyStatus,
        freightAmount: freightAmount ?? this.freightAmount,
        advancePaid: advancePaid ?? this.advancePaid,
        customerInvoiceNumber:
            customerInvoiceNumber ?? this.customerInvoiceNumber,
        customerInvoiceStatus:
            customerInvoiceStatus ?? this.customerInvoiceStatus,
        dieselExpense: dieselExpense ?? this.dieselExpense,
        tollExpense: tollExpense ?? this.tollExpense,
        parkingExpense: parkingExpense ?? this.parkingExpense,
        driverAllowance: driverAllowance ?? this.driverAllowance,
        otherExpense: otherExpense ?? this.otherExpense,
        expenseNotes: expenseNotes ?? this.expenseNotes,
        expenseSlips: expenseSlips ?? this.expenseSlips,
        cargoItems: cargoItems ?? this.cargoItems,
        cargoLedger: cargoLedger ?? this.cargoLedger,
        deliveryProofs: deliveryProofs ?? this.deliveryProofs,
        departureDateTime: departureDateTime ?? this.departureDateTime,
        returnDepot: returnDepot ?? this.returnDepot,
        driverInstructions: driverInstructions ?? this.driverInstructions,
        currentStopIndex: currentStopIndex ?? this.currentStopIndex,
        operationalStep: operationalStep ?? this.operationalStep,
        deliveryProof: deliveryProof ?? this.deliveryProof,
        plannedDistanceKm: plannedDistanceKm ?? this.plannedDistanceKm,
        plannedDurationMinutes:
            plannedDurationMinutes ?? this.plannedDurationMinutes,
        trafficSummary: trafficSummary ?? this.trafficSummary,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        actualDistanceKm: actualDistanceKm ?? this.actualDistanceKm,
        averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      );

  Map<String, Object> toJson() => {
        'reference': reference,
        'origin': origin,
        'destination': destination,
        'stops': stops,
        'status': status,
        'createdAt': createdAt,
        'tripNumber': tripNumber,
        'customerName': customerName,
        'assignedVehicle': assignedVehicle,
        'assignedDriver': assignedDriver,
        'cargoDescription': cargoDescription,
        'ewayBillNumber': ewayBillNumber,
        'ewayBillPhoto': ewayBillPhoto,
        'loadingDateTime': loadingDateTime,
        'unloadingDateTime': unloadingDateTime,
        'pickupStatus': pickupStatus,
        'deliveryStatus': deliveryStatus,
        'podPhoto': podPhoto,
        'podStatus': podStatus,
        'podReceivedAt': podReceivedAt,
        'receivingCopyPhoto': receivingCopyPhoto,
        'receivingCopyStatus': receivingCopyStatus,
        'freightAmount': freightAmount,
        'advancePaid': advancePaid,
        'customerInvoiceNumber': customerInvoiceNumber,
        'customerInvoiceStatus': customerInvoiceStatus,
        'dieselExpense': dieselExpense,
        'tollExpense': tollExpense,
        'parkingExpense': parkingExpense,
        'driverAllowance': driverAllowance,
        'otherExpense': otherExpense,
        'expenseNotes': expenseNotes,
        'expenseSlips': expenseSlips,
        'cargoItems': cargoItems.map((c) => c.toJson()).toList(),
        'cargoLedger': cargoLedger.map((l) => l.toJson()).toList(),
        'deliveryProofs': deliveryProofs.map((p) => p.toJson()).toList(),
        'departureDateTime': departureDateTime,
        'returnDepot': returnDepot,
        'driverInstructions': driverInstructions,
        'currentStopIndex': currentStopIndex,
        'operationalStep': operationalStep,
        if (deliveryProof != null) 'deliveryProof': deliveryProof!.toJson(),
        'plannedDistanceKm': plannedDistanceKm,
        'plannedDurationMinutes': plannedDurationMinutes,
        'trafficSummary': trafficSummary,
        'startedAt': startedAt,
        'completedAt': completedAt,
        'actualDistanceKm': actualDistanceKm,
        'averageSpeedKmh': averageSpeedKmh,
      };

  factory TripRecord.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'];
    final rawSlips = json['expenseSlips'];

    final cargoList = <CargoItem>[];
    if (json['cargoItems'] is List) {
      for (final item in json['cargoItems'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            cargoList.add(CargoItem.fromJson(item));
          } catch (_) {}
        }
      }
    }

    final ledgerList = <CargoLedgerEntry>[];
    if (json['cargoLedger'] is List) {
      for (final item in json['cargoLedger'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            ledgerList.add(CargoLedgerEntry.fromJson(item));
          } catch (_) {}
        }
      }
    }

    final proofsList = <DeliveryProofRecord>[];
    if (json['deliveryProofs'] is List) {
      for (final item in json['deliveryProofs'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            proofsList.add(DeliveryProofRecord.fromJson(item));
          } catch (_) {}
        }
      }
    }

    DeliveryProofRecord? singleProof;
    if (json['deliveryProof'] is Map<String, dynamic>) {
      try {
        singleProof = DeliveryProofRecord.fromJson(json['deliveryProof']);
      } catch (_) {}
    }

    return TripRecord(
      reference: json['reference']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      stops: rawStops is List
          ? rawStops
              .whereType<String>()
              .where((stop) => stop.trim().isNotEmpty)
              .toList(growable: false)
          : const [],
      status: json['status']?.toString() ?? 'planned',
      createdAt: json['createdAt']?.toString() ?? '',
      tripNumber: _jsonString(json['tripNumber']),
      customerName: _jsonString(json['customerName']),
      assignedVehicle: _jsonString(json['assignedVehicle']),
      assignedDriver: _jsonString(json['assignedDriver']),
      cargoDescription:
          _jsonString(json['cargoDescription'], 'General Cargo / Heavy Goods'),
      ewayBillNumber: _jsonString(json['ewayBillNumber']),
      ewayBillPhoto: _jsonString(json['ewayBillPhoto']),
      loadingDateTime: _jsonString(json['loadingDateTime']),
      unloadingDateTime: _jsonString(json['unloadingDateTime']),
      pickupStatus: _jsonString(json['pickupStatus'], 'pending'),
      deliveryStatus: _jsonString(json['deliveryStatus'], 'pending'),
      podPhoto: _jsonString(json['podPhoto']),
      podStatus: _jsonString(json['podStatus'], 'pending'),
      podReceivedAt: _jsonString(json['podReceivedAt']),
      receivingCopyPhoto: _jsonString(json['receivingCopyPhoto']),
      receivingCopyStatus: _jsonString(json['receivingCopyStatus'], 'pending'),
      freightAmount: _jsonDouble(json['freightAmount']),
      advancePaid: _jsonDouble(json['advancePaid']),
      customerInvoiceNumber: _jsonString(json['customerInvoiceNumber']),
      customerInvoiceStatus:
          _jsonString(json['customerInvoiceStatus'], 'draft'),
      dieselExpense: _jsonDouble(json['dieselExpense']),
      tollExpense: _jsonDouble(json['tollExpense']),
      parkingExpense: _jsonDouble(json['parkingExpense']),
      driverAllowance: _jsonDouble(json['driverAllowance']),
      otherExpense: _jsonDouble(json['otherExpense']),
      expenseNotes: _jsonString(json['expenseNotes']),
      expenseSlips:
          rawSlips is List ? rawSlips.whereType<String>().toList() : const [],
      cargoItems: cargoList,
      cargoLedger: ledgerList,
      deliveryProofs: proofsList,
      departureDateTime: _jsonString(json['departureDateTime']),
      returnDepot: _jsonString(json['returnDepot']),
      driverInstructions: _jsonString(json['driverInstructions']),
      currentStopIndex: _jsonInt(json['currentStopIndex']),
      operationalStep: _jsonString(json['operationalStep'], 'not_started'),
      deliveryProof: singleProof,
      plannedDistanceKm: _jsonDouble(json['plannedDistanceKm']),
      plannedDurationMinutes: _jsonInt(json['plannedDurationMinutes']),
      trafficSummary: _jsonString(json['trafficSummary']),
      startedAt: _jsonString(json['startedAt']),
      completedAt: _jsonString(json['completedAt']),
      actualDistanceKm: _jsonDouble(json['actualDistanceKm']),
      averageSpeedKmh: _jsonDouble(json['averageSpeedKmh']),
    );
  }
}

class OperationsAlert {
  const OperationsAlert({
    required this.title,
    required this.details,
    this.severity = 'info',
    this.createdAt = '',
    this.isRead = false,
    this.isResolved = false,
    this.category = 'general',
    this.vehicleNumber = '',
    this.challanNumber = '',
    this.fineAmount = 0,
    this.location = '',
    this.driverPhoto = '',
  });

  final String title;
  final String details;
  final String severity;
  final String createdAt;
  final bool isRead;
  final bool isResolved;
  final String category;
  final String vehicleNumber;
  final String challanNumber;
  final int fineAmount;
  final String location;
  final String driverPhoto;

  bool get isMemo =>
      category == 'memo' || challanNumber.isNotEmpty || fineAmount > 0;
  bool get isOverspeed => category == 'overspeed';
  bool get isSeatbelt => category == 'seatbelt';

  OperationsAlert copyWith({
    String? title,
    String? details,
    String? severity,
    String? createdAt,
    bool? isRead,
    bool? isResolved,
    String? category,
    String? vehicleNumber,
    String? challanNumber,
    int? fineAmount,
    String? location,
    String? driverPhoto,
  }) =>
      OperationsAlert(
        title: title ?? this.title,
        details: details ?? this.details,
        severity: severity ?? this.severity,
        createdAt: createdAt ?? this.createdAt,
        isRead: isRead ?? this.isRead,
        isResolved: isResolved ?? this.isResolved,
        category: category ?? this.category,
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
        challanNumber: challanNumber ?? this.challanNumber,
        fineAmount: fineAmount ?? this.fineAmount,
        location: location ?? this.location,
        driverPhoto: driverPhoto ?? this.driverPhoto,
      );

  Map<String, Object> toJson() => {
        'title': title,
        'details': details,
        'severity': severity,
        'createdAt': createdAt,
        'isRead': isRead,
        'isResolved': isResolved,
        'category': category,
        'vehicleNumber': vehicleNumber,
        'challanNumber': challanNumber,
        'fineAmount': fineAmount,
        'location': location,
        'driverPhoto': driverPhoto,
      };

  factory OperationsAlert.fromJson(Map<String, dynamic> json) {
    final title = _jsonString(json['title']);
    final details = _jsonString(json['details']);
    String cat = _jsonString(json['category']);
    if (cat.isEmpty) {
      final combined = '$title $details'.toLowerCase();
      if (combined.contains('memo') ||
          combined.contains('challan') ||
          combined.contains('fine')) {
        cat = 'memo';
      } else if (combined.contains('speed') || combined.contains('overspeed')) {
        cat = 'overspeed';
      } else if (combined.contains('seatbelt') || combined.contains('belt')) {
        cat = 'seatbelt';
      } else if (combined.contains('fatigue') ||
          combined.contains('drowsy') ||
          combined.contains('brake') ||
          combined.contains('rash')) {
        cat = 'safety';
      } else {
        cat = 'general';
      }
    }
    return OperationsAlert(
      title: title,
      details: details,
      severity: _jsonString(json['severity'], 'info'),
      createdAt: _jsonString(json['createdAt']),
      isRead: _jsonBool(json['isRead']),
      isResolved: _jsonBool(json['isResolved']),
      category: cat,
      vehicleNumber: _jsonString(json['vehicleNumber']),
      challanNumber: _jsonString(json['challanNumber']),
      fineAmount: _jsonInt(json['fineAmount']),
      location: _jsonString(json['location']),
      driverPhoto: _jsonString(json['driverPhoto']),
    );
  }
}

enum ActivityCategory { driver, vehicle, trip, alert, planner }

extension ActivityCategoryView on ActivityCategory {
  String get label => switch (this) {
        ActivityCategory.driver => 'Driver',
        ActivityCategory.vehicle => 'Vehicle',
        ActivityCategory.trip => 'Trip',
        ActivityCategory.alert => 'Alert',
        ActivityCategory.planner => 'Planner',
      };

  IconData get icon => switch (this) {
        ActivityCategory.driver => Icons.badge_outlined,
        ActivityCategory.vehicle => Icons.local_shipping_outlined,
        ActivityCategory.trip => Icons.route_outlined,
        ActivityCategory.alert => Icons.notifications_none_rounded,
        ActivityCategory.planner => Icons.map_outlined,
      };

  Color get color => switch (this) {
        ActivityCategory.driver => const Color(0xFF1769E8),
        ActivityCategory.vehicle => const Color(0xFF7C3AED),
        ActivityCategory.trip => const Color(0xFF10B981),
        ActivityCategory.alert => const Color(0xFFF59E0B),
        ActivityCategory.planner => const Color(0xFF0284C7),
      };

  Color get background => switch (this) {
        ActivityCategory.driver => const Color(0xFFEDF4FF),
        ActivityCategory.vehicle => const Color(0xFFF3E8FF),
        ActivityCategory.trip => const Color(0xFFECFDF5),
        ActivityCategory.alert => const Color(0xFFFFFBEB),
        ActivityCategory.planner => const Color(0xFFE0F2FE),
      };
}

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.title,
    required this.details,
    required this.category,
    required this.action,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String details;
  final ActivityCategory category;
  final String action;
  final DateTime timestamp;

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'details': details,
        'category': category.name,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        id: _jsonString(json['id']),
        title: _jsonString(json['title']),
        details: _jsonString(json['details']),
        category: ActivityCategory.values.firstWhere(
          (c) => c.name == _jsonString(json['category']),
          orElse: () => ActivityCategory.planner,
        ),
        action: _jsonString(json['action'], 'updated'),
        timestamp: _jsonDateTime(json['timestamp']),
      );
}

class SeatbeltRecord {
  const SeatbeltRecord({
    required this.id,
    required this.driverName,
    required this.driverId,
    required this.vehicleNumber,
    required this.photoBase64,
    required this.timestamp,
    required this.isApproved,
    this.location = '',
    this.notes = '',
  });

  final String id;
  final String driverName;
  final String driverId;
  final String vehicleNumber;
  final String photoBase64;
  final DateTime timestamp;
  final bool isApproved;
  final String location;
  final String notes;

  Map<String, Object> toJson() => {
        'id': id,
        'driverName': driverName,
        'driverId': driverId,
        'vehicleNumber': vehicleNumber,
        'photoBase64': photoBase64,
        'timestamp': timestamp.toIso8601String(),
        'isApproved': isApproved,
        'location': location,
        'notes': notes,
      };

  factory SeatbeltRecord.fromJson(Map<String, dynamic> json) => SeatbeltRecord(
        id: _jsonString(json['id']),
        driverName: _jsonString(json['driverName']),
        driverId: _jsonString(json['driverId']),
        vehicleNumber: _jsonString(json['vehicleNumber']),
        photoBase64: _jsonString(json['photoBase64']),
        timestamp: _jsonDateTime(json['timestamp']),
        isApproved: _jsonBool(json['isApproved']),
        location: _jsonString(json['location']),
        notes: _jsonString(json['notes']),
      );
}

class CargoItem {
  const CargoItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.brand = '',
    this.category = '',
    this.photoAsset = '',
    this.unit = 'Ton',
    this.loadedQuantity = 0.0,
    this.deliveredQuantity = 0.0,
    this.damagedQuantity = 0.0,
    this.returnedQuantity = 0.0,
    this.notes = '',
  });

  final String id;
  final String productId;
  final String productName;
  final String brand;
  final String category;
  final String photoAsset;
  final String unit;
  final double loadedQuantity;
  final double deliveredQuantity;
  final double damagedQuantity;
  final double returnedQuantity;
  final String notes;

  double get remainingQuantity {
    final rem =
        loadedQuantity - deliveredQuantity - damagedQuantity - returnedQuantity;
    return rem > 0 ? rem : 0.0;
  }

  double get pendingQuantity => remainingQuantity;
  bool get isFullyDelivered => remainingQuantity <= 0.001 && loadedQuantity > 0;

  CargoItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? brand,
    String? category,
    String? photoAsset,
    String? unit,
    double? loadedQuantity,
    double? deliveredQuantity,
    double? damagedQuantity,
    double? returnedQuantity,
    String? notes,
  }) =>
      CargoItem(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        brand: brand ?? this.brand,
        category: category ?? this.category,
        photoAsset: photoAsset ?? this.photoAsset,
        unit: unit ?? this.unit,
        loadedQuantity: loadedQuantity ?? this.loadedQuantity,
        deliveredQuantity: deliveredQuantity ?? this.deliveredQuantity,
        damagedQuantity: damagedQuantity ?? this.damagedQuantity,
        returnedQuantity: returnedQuantity ?? this.returnedQuantity,
        notes: notes ?? this.notes,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'brand': brand,
        'category': category,
        'photoAsset': photoAsset,
        'unit': unit,
        'loadedQuantity': loadedQuantity,
        'deliveredQuantity': deliveredQuantity,
        'damagedQuantity': damagedQuantity,
        'returnedQuantity': returnedQuantity,
        'notes': notes,
      };

  factory CargoItem.fromJson(Map<String, dynamic> json) => CargoItem(
        id: _jsonString(json['id']),
        productId: _jsonString(json['productId']),
        productName: _jsonString(json['productName']),
        brand: _jsonString(json['brand']),
        category: _jsonString(json['category']),
        photoAsset: _jsonString(json['photoAsset']),
        unit: _jsonString(json['unit'], 'Ton'),
        loadedQuantity: _jsonDouble(json['loadedQuantity']),
        deliveredQuantity: _jsonDouble(json['deliveredQuantity']),
        damagedQuantity: _jsonDouble(json['damagedQuantity']),
        returnedQuantity: _jsonDouble(json['returnedQuantity']),
        notes: _jsonString(json['notes']),
      );
}

class CargoLedgerEntry {
  const CargoLedgerEntry({
    required this.id,
    required this.tripId,
    required this.stopIndex,
    required this.stopLocation,
    required this.productId,
    required this.productName,
    required this.action, // load, deliver, damage, return
    required this.quantity,
    required this.timestamp,
    this.unit = 'Ton',
    this.recordedBy = '',
    this.notes = '',
  });

  final String id;
  final String tripId;
  final int stopIndex;
  final String stopLocation;
  final String productId;
  final String productName;
  final String action;
  final double quantity;
  final String timestamp;
  final String unit;
  final String recordedBy;
  final String notes;

  Map<String, Object> toJson() => {
        'id': id,
        'tripId': tripId,
        'stopIndex': stopIndex,
        'stopLocation': stopLocation,
        'productId': productId,
        'productName': productName,
        'action': action,
        'quantity': quantity,
        'timestamp': timestamp,
        'unit': unit,
        'recordedBy': recordedBy,
        'notes': notes,
      };

  factory CargoLedgerEntry.fromJson(Map<String, dynamic> json) =>
      CargoLedgerEntry(
        id: _jsonString(json['id']),
        tripId: _jsonString(json['tripId']),
        stopIndex: _jsonInt(json['stopIndex']),
        stopLocation: _jsonString(json['stopLocation']),
        productId: _jsonString(json['productId']),
        productName: _jsonString(json['productName']),
        action: _jsonString(json['action'], 'load'),
        quantity: _jsonDouble(json['quantity']),
        timestamp: _jsonString(json['timestamp']),
        unit: _jsonString(json['unit'], 'Ton'),
        recordedBy: _jsonString(json['recordedBy']),
        notes: _jsonString(json['notes']),
      );
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.date,
    required this.startTime,
    this.endTime = '',
    this.totalWorkingHours = 0.0,
    this.status = 'present', // present, absent, late, half_day, on_leave
    this.tripId = '',
    this.notes = '',
    this.createdAt = '',
  });

  final String id;
  final String driverId;
  final String driverName;
  final String date;
  final String startTime;
  final String endTime;
  final double totalWorkingHours;
  final String status;
  final String tripId;
  final String notes;
  final String createdAt;

  bool get isOnDuty =>
      endTime.trim().isEmpty && status != 'absent' && status != 'on_leave';

  static double calculateHours(String startStr, String endStr) {
    if (startStr.isEmpty || endStr.isEmpty) return 0.0;
    final start = DateTime.tryParse(startStr);
    final end = DateTime.tryParse(endStr);
    if (start != null && end != null && end.isAfter(start)) {
      return (end.difference(start).inMinutes / 60.0);
    }
    return 0.0;
  }

  double calculateWorkingHours() => calculateHours(startTime, endTime);

  AttendanceRecord copyWith({
    String? id,
    String? driverId,
    String? driverName,
    String? date,
    String? startTime,
    String? endTime,
    double? totalWorkingHours,
    String? status,
    String? tripId,
    String? notes,
    String? createdAt,
  }) =>
      AttendanceRecord(
        id: id ?? this.id,
        driverId: driverId ?? this.driverId,
        driverName: driverName ?? this.driverName,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        totalWorkingHours: totalWorkingHours ?? this.totalWorkingHours,
        status: status ?? this.status,
        tripId: tripId ?? this.tripId,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'driverId': driverId,
        'driverName': driverName,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'totalWorkingHours': totalWorkingHours,
        'status': status,
        'tripId': tripId,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: _jsonString(json['id']),
        driverId: _jsonString(json['driverId']),
        driverName: _jsonString(json['driverName']),
        date: _jsonString(json['date']),
        startTime: _jsonString(json['startTime']),
        endTime: _jsonString(json['endTime']),
        totalWorkingHours: _jsonDouble(json['totalWorkingHours']),
        status: _jsonString(json['status'], 'present'),
        tripId: _jsonString(json['tripId']),
        notes: _jsonString(json['notes']),
        createdAt: _jsonString(json['createdAt']),
      );
}

class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.landmark = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.arrivalRadiusMeters = 300.0,
    this.deliveryInstructions = '',
    this.isActive = true,
    this.createdAt = '',
  });

  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String landmark;
  final double latitude;
  final double longitude;
  final double arrivalRadiusMeters;
  final String deliveryInstructions;
  final bool isActive;
  final String createdAt;

  CustomerRecord copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? landmark,
    double? latitude,
    double? longitude,
    double? arrivalRadiusMeters,
    String? deliveryInstructions,
    bool? isActive,
    String? createdAt,
  }) =>
      CustomerRecord(
        id: id ?? this.id,
        name: name ?? this.name,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        landmark: landmark ?? this.landmark,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        arrivalRadiusMeters: arrivalRadiusMeters ?? this.arrivalRadiusMeters,
        deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
        'arrivalRadiusMeters': arrivalRadiusMeters,
        'deliveryInstructions': deliveryInstructions,
        'isActive': isActive,
        'createdAt': createdAt,
      };

  factory CustomerRecord.fromJson(Map<String, dynamic> json) => CustomerRecord(
        id: _jsonString(json['id']),
        name: _jsonString(json['name']),
        contactPerson: _jsonString(json['contactPerson']),
        phone: _jsonString(json['phone']),
        email: _jsonString(json['email']),
        address: _jsonString(json['address']),
        landmark: _jsonString(json['landmark']),
        latitude: _jsonDouble(json['latitude']),
        longitude: _jsonDouble(json['longitude']),
        arrivalRadiusMeters: _jsonDouble(json['arrivalRadiusMeters'], 300.0),
        deliveryInstructions: _jsonString(json['deliveryInstructions']),
        isActive: _jsonBool(json['isActive'], true),
        createdAt: _jsonString(json['createdAt']),
      );
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    this.tripId = '',
    this.vehicleNumber = '',
    this.driverId = '',
    this.driverName = '',
    required this.category,
    required this.isDirect,
    required this.amount,
    required this.date,
    this.receiptBase64 = '',
    this.notes = '',
    this.createdBy = '',
    this.status = 'pending', // pending, approved, rejected
    this.approvedBy = '',
    this.approvedAt = '',
    this.createdAt = '',
  });

  final String id;
  final String tripId;
  final String vehicleNumber;
  final String driverId;
  final String driverName;
  final String category;
  final bool isDirect;
  final double amount;
  final String date;
  final String receiptBase64;
  final String notes;
  final String createdBy;
  final String status;
  final String approvedBy;
  final String approvedAt;
  final String createdAt;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';

  ExpenseRecord copyWith({
    String? id,
    String? tripId,
    String? vehicleNumber,
    String? driverId,
    String? driverName,
    String? category,
    bool? isDirect,
    double? amount,
    String? date,
    String? receiptBase64,
    String? notes,
    String? createdBy,
    String? status,
    String? approvedBy,
    String? approvedAt,
    String? createdAt,
  }) =>
      ExpenseRecord(
        id: id ?? this.id,
        tripId: tripId ?? this.tripId,
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
        driverId: driverId ?? this.driverId,
        driverName: driverName ?? this.driverName,
        category: category ?? this.category,
        isDirect: isDirect ?? this.isDirect,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        receiptBase64: receiptBase64 ?? this.receiptBase64,
        notes: notes ?? this.notes,
        createdBy: createdBy ?? this.createdBy,
        status: status ?? this.status,
        approvedBy: approvedBy ?? this.approvedBy,
        approvedAt: approvedAt ?? this.approvedAt,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'tripId': tripId,
        'vehicleNumber': vehicleNumber,
        'driverId': driverId,
        'driverName': driverName,
        'category': category,
        'isDirect': isDirect,
        'amount': amount,
        'date': date,
        'receiptBase64': receiptBase64,
        'notes': notes,
        'createdBy': createdBy,
        'status': status,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
        'createdAt': createdAt,
      };

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
        id: _jsonString(json['id']),
        tripId: _jsonString(json['tripId']),
        vehicleNumber: _jsonString(json['vehicleNumber']),
        driverId: _jsonString(json['driverId']),
        driverName: _jsonString(json['driverName']),
        category: _jsonString(json['category'], 'fuel'),
        isDirect: _jsonBool(json['isDirect'], true),
        amount: _jsonDouble(json['amount']),
        date: _jsonString(json['date']),
        receiptBase64: _jsonString(json['receiptBase64']),
        notes: _jsonString(json['notes']),
        createdBy: _jsonString(json['createdBy']),
        status: _jsonString(json['status'], 'pending'),
        approvedBy: _jsonString(json['approvedBy']),
        approvedAt: _jsonString(json['approvedAt']),
        createdAt: _jsonString(json['createdAt']),
      );
}

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod, // cash, bank_transfer, cheque, upi
    this.referenceNumber = '',
    this.receiptBase64 = '',
    this.recordedBy = '',
    this.notes = '',
  });

  final String id;
  final double amount;
  final String paymentDate;
  final String paymentMethod;
  final String referenceNumber;
  final String receiptBase64;
  final String recordedBy;
  final String notes;

  Map<String, Object> toJson() => {
        'id': id,
        'amount': amount,
        'paymentDate': paymentDate,
        'paymentMethod': paymentMethod,
        'referenceNumber': referenceNumber,
        'receiptBase64': receiptBase64,
        'recordedBy': recordedBy,
        'notes': notes,
      };

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) =>
      PaymentTransaction(
        id: _jsonString(json['id']),
        amount: _jsonDouble(json['amount']),
        paymentDate: _jsonString(json['paymentDate']),
        paymentMethod: _jsonString(json['paymentMethod'], 'bank_transfer'),
        referenceNumber: _jsonString(json['referenceNumber']),
        receiptBase64: _jsonString(json['receiptBase64']),
        recordedBy: _jsonString(json['recordedBy']),
        notes: _jsonString(json['notes']),
      );
}

class BillingRecord {
  const BillingRecord({
    required this.id,
    required this.tripId,
    this.tripNumber = '',
    this.customerName = '',
    this.freightRate = 0.0,
    this.deliveryCharge = 0.0,
    this.loadingUnloadingCharge = 0.0,
    this.waitingCharge = 0.0,
    this.parkingCharge = 0.0,
    this.driverAllowance = 0.0,
    this.otherCharges = 0.0,
    this.paymentStatus = 'pending', // pending, partially_paid, paid, cancelled
    this.invoiceNumber = '',
    this.invoiceDate = '',
    this.invoiceFileBase64 = '',
    this.payments = const [],
    this.createdAt = '',
    this.notes = '',
  });

  final String id;
  final String tripId;
  final String tripNumber;
  final String customerName;
  final double freightRate;
  final double deliveryCharge;
  final double loadingUnloadingCharge;
  final double waitingCharge;
  final double parkingCharge;
  final double driverAllowance;
  final double otherCharges;
  final String paymentStatus;
  final String invoiceNumber;
  final String invoiceDate;
  final String invoiceFileBase64;
  final List<PaymentTransaction> payments;
  final String createdAt;
  final String notes;

  String get tripReference => tripId;

  double get totalAmount =>
      freightRate +
      deliveryCharge +
      loadingUnloadingCharge +
      waitingCharge +
      parkingCharge +
      otherCharges;

  double get totalPaid => payments.fold(0.0, (sum, p) => sum + p.amount);

  double get balanceDue {
    final bal = totalAmount - totalPaid;
    return bal > 0 ? bal : 0.0;
  }

  bool get isFullyPaid => balanceDue <= 0.001 && totalAmount > 0;

  BillingRecord copyWith({
    String? id,
    String? tripId,
    String? tripNumber,
    String? customerName,
    double? freightRate,
    double? deliveryCharge,
    double? loadingUnloadingCharge,
    double? waitingCharge,
    double? parkingCharge,
    double? driverAllowance,
    double? otherCharges,
    String? paymentStatus,
    String? invoiceNumber,
    String? invoiceDate,
    String? invoiceFileBase64,
    List<PaymentTransaction>? payments,
    String? createdAt,
    String? notes,
  }) =>
      BillingRecord(
        id: id ?? this.id,
        tripId: tripId ?? this.tripId,
        tripNumber: tripNumber ?? this.tripNumber,
        customerName: customerName ?? this.customerName,
        freightRate: freightRate ?? this.freightRate,
        deliveryCharge: deliveryCharge ?? this.deliveryCharge,
        loadingUnloadingCharge:
            loadingUnloadingCharge ?? this.loadingUnloadingCharge,
        waitingCharge: waitingCharge ?? this.waitingCharge,
        parkingCharge: parkingCharge ?? this.parkingCharge,
        driverAllowance: driverAllowance ?? this.driverAllowance,
        otherCharges: otherCharges ?? this.otherCharges,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        invoiceDate: invoiceDate ?? this.invoiceDate,
        invoiceFileBase64: invoiceFileBase64 ?? this.invoiceFileBase64,
        payments: payments ?? this.payments,
        createdAt: createdAt ?? this.createdAt,
        notes: notes ?? this.notes,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'tripId': tripId,
        'tripNumber': tripNumber,
        'customerName': customerName,
        'freightRate': freightRate,
        'deliveryCharge': deliveryCharge,
        'loadingUnloadingCharge': loadingUnloadingCharge,
        'waitingCharge': waitingCharge,
        'parkingCharge': parkingCharge,
        'driverAllowance': driverAllowance,
        'otherCharges': otherCharges,
        'paymentStatus': paymentStatus,
        'invoiceNumber': invoiceNumber,
        'invoiceDate': invoiceDate,
        'invoiceFileBase64': invoiceFileBase64,
        'payments': payments.map((p) => p.toJson()).toList(),
        'createdAt': createdAt,
        'notes': notes,
      };

  factory BillingRecord.fromJson(Map<String, dynamic> json) {
    final payList = <PaymentTransaction>[];
    if (json['payments'] is List) {
      for (final item in json['payments'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            payList.add(PaymentTransaction.fromJson(item));
          } catch (_) {}
        }
      }
    }
    return BillingRecord(
      id: _jsonString(json['id']),
      tripId: _jsonString(json['tripId']),
      tripNumber: _jsonString(json['tripNumber']),
      customerName: _jsonString(json['customerName']),
      freightRate: _jsonDouble(json['freightRate']),
      deliveryCharge: _jsonDouble(json['deliveryCharge']),
      loadingUnloadingCharge: _jsonDouble(json['loadingUnloadingCharge']),
      waitingCharge: _jsonDouble(json['waitingCharge']),
      parkingCharge: _jsonDouble(json['parkingCharge']),
      driverAllowance: _jsonDouble(json['driverAllowance']),
      otherCharges: _jsonDouble(json['otherCharges']),
      paymentStatus: _jsonString(json['paymentStatus'], 'pending'),
      invoiceNumber: _jsonString(json['invoiceNumber']),
      invoiceDate: _jsonString(json['invoiceDate']),
      invoiceFileBase64: _jsonString(json['invoiceFileBase64']),
      payments: payList,
      createdAt: _jsonString(json['createdAt']),
      notes: _jsonString(json['notes']),
    );
  }
}

class DeliveryProofRecord {
  const DeliveryProofRecord({
    required this.id,
    required this.tripId,
    this.tripNumber = '',
    this.stopLocation = '',
    this.customerName = '',
    this.driverName = '',
    this.recipientName = '',
    this.recipientPhone = '',
    this.deliveredQuantity = 0.0,
    this.damagedQuantity = 0.0,
    this.returnedQuantity = 0.0,
    this.damageOrRefusalReason = '',
    this.photoBase64 = '',
    this.signatureBase64 = '',
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.notes = '',
    this.isConfirmed = false,
  });

  final String id;
  final String tripId;
  final String tripNumber;
  final String stopLocation;
  final String customerName;
  final String driverName;
  final String recipientName;
  final String recipientPhone;
  final double deliveredQuantity;
  final double damagedQuantity;
  final double returnedQuantity;
  final String damageOrRefusalReason;
  final String photoBase64;
  final String signatureBase64;
  final double? latitude;
  final double? longitude;
  final String timestamp;
  final String notes;
  final bool isConfirmed;

  DeliveryProofRecord copyWith({
    String? id,
    String? tripId,
    String? tripNumber,
    String? stopLocation,
    String? customerName,
    String? driverName,
    String? recipientName,
    String? recipientPhone,
    double? deliveredQuantity,
    double? damagedQuantity,
    double? returnedQuantity,
    String? damageOrRefusalReason,
    String? photoBase64,
    String? signatureBase64,
    double? latitude,
    double? longitude,
    String? timestamp,
    String? notes,
    bool? isConfirmed,
  }) =>
      DeliveryProofRecord(
        id: id ?? this.id,
        tripId: tripId ?? this.tripId,
        tripNumber: tripNumber ?? this.tripNumber,
        stopLocation: stopLocation ?? this.stopLocation,
        customerName: customerName ?? this.customerName,
        driverName: driverName ?? this.driverName,
        recipientName: recipientName ?? this.recipientName,
        recipientPhone: recipientPhone ?? this.recipientPhone,
        deliveredQuantity: deliveredQuantity ?? this.deliveredQuantity,
        damagedQuantity: damagedQuantity ?? this.damagedQuantity,
        returnedQuantity: returnedQuantity ?? this.returnedQuantity,
        damageOrRefusalReason:
            damageOrRefusalReason ?? this.damageOrRefusalReason,
        photoBase64: photoBase64 ?? this.photoBase64,
        signatureBase64: signatureBase64 ?? this.signatureBase64,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        timestamp: timestamp ?? this.timestamp,
        notes: notes ?? this.notes,
        isConfirmed: isConfirmed ?? this.isConfirmed,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'tripId': tripId,
        'tripNumber': tripNumber,
        'stopLocation': stopLocation,
        'customerName': customerName,
        'driverName': driverName,
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        'deliveredQuantity': deliveredQuantity,
        'damagedQuantity': damagedQuantity,
        'returnedQuantity': returnedQuantity,
        'damageOrRefusalReason': damageOrRefusalReason,
        'photoBase64': photoBase64,
        'signatureBase64': signatureBase64,
        if (latitude != null) 'latitude': latitude!,
        if (longitude != null) 'longitude': longitude!,
        'timestamp': timestamp,
        'notes': notes,
        'isConfirmed': isConfirmed,
      };

  factory DeliveryProofRecord.fromJson(Map<String, dynamic> json) =>
      DeliveryProofRecord(
        id: _jsonString(json['id']),
        tripId: _jsonString(json['tripId']),
        tripNumber: _jsonString(json['tripNumber']),
        stopLocation: _jsonString(json['stopLocation']),
        customerName: _jsonString(json['customerName']),
        driverName: _jsonString(json['driverName']),
        recipientName: _jsonString(json['recipientName']),
        recipientPhone: _jsonString(json['recipientPhone']),
        deliveredQuantity: _jsonDouble(json['deliveredQuantity']),
        damagedQuantity: _jsonDouble(json['damagedQuantity']),
        returnedQuantity: _jsonDouble(json['returnedQuantity']),
        damageOrRefusalReason: _jsonString(json['damageOrRefusalReason']),
        photoBase64: _jsonString(json['photoBase64']),
        signatureBase64: _jsonString(json['signatureBase64']),
        latitude: json['latitude'] is num
            ? (json['latitude'] as num).toDouble()
            : null,
        longitude: json['longitude'] is num
            ? (json['longitude'] as num).toDouble()
            : null,
        timestamp: _jsonString(json['timestamp']),
        notes: _jsonString(json['notes']),
        isConfirmed: _jsonBool(json['isConfirmed']),
      );
}
