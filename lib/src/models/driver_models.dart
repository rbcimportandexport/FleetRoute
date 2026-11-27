import 'package:flutter/foundation.dart';

enum SmartCaptureType {
  fuelBill,
  meterOdometer,
  oldTyre,
  newTyre,
  tyreBill,
  hotelFood,
  driverLicense,
  insurance,
  seatbelt,
  challanMemo,
  biltyCustomer,
  sundayCleaning,
  tollTaxSlip,
  pucCertificate,
  fitnessCertificate,
  rcBook,
  nationalPermit,
}

extension SmartCaptureTypeExt on SmartCaptureType {
  String get titleHindi => switch (this) {
        SmartCaptureType.fuelBill => 'पेट्रोल / डीजल पर्ची',
        SmartCaptureType.meterOdometer => 'मीटर (ओडोमीटर) रीडिंग',
        SmartCaptureType.oldTyre => 'पुराना टायर फोटो',
        SmartCaptureType.newTyre => 'नया टायर फोटो',
        SmartCaptureType.tyreBill => 'टायर चेंज बिल',
        SmartCaptureType.hotelFood => 'होटल / खाना खर्चा (बिल + थाली)',
        SmartCaptureType.driverLicense => 'ड्राइविंग लाइसेंस',
        SmartCaptureType.insurance => 'गाड़ी इंश्योरेंस',
        SmartCaptureType.seatbelt => 'सीट बेल्ट वेरिफिकेशन',
        SmartCaptureType.challanMemo => 'चालान / मेमो पर्ची',
        SmartCaptureType.biltyCustomer => 'कस्टमर बिल्टी / इनवॉइस',
        SmartCaptureType.sundayCleaning => 'Sunday Vehicle Cleaning',
        SmartCaptureType.tollTaxSlip => 'टोल टैक्स पर्ची (Toll Slip)',
        SmartCaptureType.pucCertificate => 'प्रदूषण जांच (PUC)',
        SmartCaptureType.fitnessCertificate => 'गाड़ी फिटनेस प्रमाण पत्र (Fitness)',
        SmartCaptureType.rcBook => 'गाड़ी आरसी (RC Book)',
        SmartCaptureType.nationalPermit => 'गाड़ी परमिट (Permit)',
      };

  String get shortTag => switch (this) {
        SmartCaptureType.fuelBill => 'डीजल बिल',
        SmartCaptureType.meterOdometer => 'मीटर KM',
        SmartCaptureType.oldTyre => 'पुराना टायर',
        SmartCaptureType.newTyre => 'नया टायर',
        SmartCaptureType.tyreBill => 'टायर बिल',
        SmartCaptureType.hotelFood => 'खाना व बिल',
        SmartCaptureType.driverLicense => 'लाइसेंस',
        SmartCaptureType.insurance => 'इंश्योरेंस',
        SmartCaptureType.seatbelt => 'सीट बेल्ट',
        SmartCaptureType.challanMemo => 'चालान',
        SmartCaptureType.biltyCustomer => 'बिल्टी',
        SmartCaptureType.sundayCleaning => 'सफाई फोटो',
        SmartCaptureType.tollTaxSlip => 'टोल पर्ची',
        SmartCaptureType.pucCertificate => 'PUC पेपर',
        SmartCaptureType.fitnessCertificate => 'फिटनेस',
        SmartCaptureType.rcBook => 'गाड़ी RC',
        SmartCaptureType.nationalPermit => 'परमिट',
      };
}

class PhotoLogRecord {
  final String id;
  final SmartCaptureType type;
  final DateTime time;
  final String location;
  final double? amount;
  final double? liters;
  final double? odometer;
  final double? mileage;
  final String vendor;
  final String docNumber;
  final String summary;
  final String imageBase64;
  final Uint8List? imageBytes;
  final String? secondaryImageBase64;
  final Uint8List? secondaryImageBytes;

  const PhotoLogRecord({
    required this.id,
    required this.type,
    required this.time,
    required this.location,
    this.amount,
    this.liters,
    this.odometer,
    this.mileage,
    this.vendor = '',
    this.docNumber = '',
    required this.summary,
    required this.imageBase64,
    this.imageBytes,
    this.secondaryImageBase64,
    this.secondaryImageBytes,
  });
}
