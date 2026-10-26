import 'package:flutter/foundation.dart';

enum AppLanguage {
  en('English', 'EN'),
  hi('हिंदी', 'HI'),
  gu('ગુજરાતી', 'GU');

  const AppLanguage(this.label, this.code);
  final String label;
  final String code;
}

class AppLocalizationService {
  AppLocalizationService._();
  static final AppLocalizationService instance = AppLocalizationService._();

  final ValueNotifier<AppLanguage> currentLanguage =
      ValueNotifier<AppLanguage>(AppLanguage.en);

  AppLanguage get language => currentLanguage.value;

  void setLanguage(AppLanguage lang) {
    currentLanguage.value = lang;
  }

  static const Map<String, Map<AppLanguage, String>> _strings = {
    // Navigation & General
    'app_name': {
      AppLanguage.en: 'FleetRoute',
      AppLanguage.hi: 'फ्लीट रूट',
      AppLanguage.gu: 'ફ્લીટ રૂટ',
    },
    'dashboard': {
      AppLanguage.en: 'Dashboard',
      AppLanguage.hi: 'डैशबोर्ड',
      AppLanguage.gu: 'ડેશબોર્ડ',
    },
    'planner': {
      AppLanguage.en: 'Live Route',
      AppLanguage.hi: 'लाइव रूट',
      AppLanguage.gu: 'લાઇવ રૂટ',
    },
    'trips': {
      AppLanguage.en: 'Trips & Cargo',
      AppLanguage.hi: 'ट्रिप और कार्गो',
      AppLanguage.gu: 'ટ્રિપ અને કાર્ગો',
    },
    'drivers': {
      AppLanguage.en: 'Drivers',
      AppLanguage.hi: 'ड्राइवर',
      AppLanguage.gu: 'ડ્રાઇવર',
    },
    'vehicles': {
      AppLanguage.en: 'Vehicles',
      AppLanguage.hi: 'वाहन सूची',
      AppLanguage.gu: 'વાહન યાદી',
    },
    'attendance': {
      AppLanguage.en: 'Attendance',
      AppLanguage.hi: 'उपस्थिति (हाजिरी)',
      AppLanguage.gu: 'હાજરી પત્રક',
    },
    'expenses': {
      AppLanguage.en: 'Expenses & P&L',
      AppLanguage.hi: 'खर्चे व लाभ-हानि',
      AppLanguage.gu: 'ખર્ચ અને નફો-નુકસાન',
    },
    'billing': {
      AppLanguage.en: 'Billing & Invoices',
      AppLanguage.hi: 'बिलिंग और इनवॉइस',
      AppLanguage.gu: 'બિલિંગ અને ઇનવૉઇસ',
    },
    'reports': {
      AppLanguage.en: 'Reports & Export',
      AppLanguage.hi: 'रिपोर्ट और निर्यात',
      AppLanguage.gu: 'રિપોર્ટ અને નિકાસ',
    },
    'alerts': {
      AppLanguage.en: 'Alerts',
      AppLanguage.hi: 'सूचनाएं (अलर्ट)',
      AppLanguage.gu: 'ચેતવણીઓ',
    },
    'sign_out': {
      AppLanguage.en: 'Sign Out',
      AppLanguage.hi: 'लॉग आउट',
      AppLanguage.gu: 'લૉગ આઉટ',
    },
    // Metrics
    'total_revenue': {
      AppLanguage.en: 'Total Revenue',
      AppLanguage.hi: 'कुल आय',
      AppLanguage.gu: 'કુલ આવક',
    },
    'total_expenses': {
      AppLanguage.en: 'Total Expenses',
      AppLanguage.hi: 'कुल खर्चे',
      AppLanguage.gu: 'કુલ ખર્ચ',
    },
    'net_profit': {
      AppLanguage.en: 'Net Profit',
      AppLanguage.hi: 'शुद्ध लाभ',
      AppLanguage.gu: 'ચોખ્ખો નફો',
    },
    'cargo_onboard': {
      AppLanguage.en: 'Cargo Onboard',
      AppLanguage.hi: 'गाड़ी में लोड माल',
      AppLanguage.gu: 'ગાડીમાં લોડ થયેલ માલ',
    },
    'unpaid_bills': {
      AppLanguage.en: 'Pending Receivables',
      AppLanguage.hi: 'बाकी वसूली (बिल)',
      AppLanguage.gu: 'બાકી વસૂલાત (બિલ)',
    },
    'active_trips': {
      AppLanguage.en: 'Active Trips',
      AppLanguage.hi: 'सक्रिय ट्रिप',
      AppLanguage.gu: 'ચાલુ ટ્રિપ',
    },
    'drivers_present': {
      AppLanguage.en: 'Drivers Present',
      AppLanguage.hi: 'उपस्थित ड्राइवर',
      AppLanguage.gu: 'હાજર ડ્રાઇવર',
    },
    'fleet_utilization': {
      AppLanguage.en: 'Fleet Utilization',
      AppLanguage.hi: 'गाड़ियों का उपयोग',
      AppLanguage.gu: 'વાહનોનો ઉપયોગ',
    },
    // Filters & Actions
    'filter_today': {
      AppLanguage.en: 'Today',
      AppLanguage.hi: 'आज',
      AppLanguage.gu: 'આજે',
    },
    'filter_this_week': {
      AppLanguage.en: 'This Week',
      AppLanguage.hi: 'इस सप्ताह',
      AppLanguage.gu: 'આ અઠવાડિયે',
    },
    'filter_this_month': {
      AppLanguage.en: 'This Month',
      AppLanguage.hi: 'इस महीने',
      AppLanguage.gu: 'આ મહિને',
    },
    'filter_all_time': {
      AppLanguage.en: 'All Time',
      AppLanguage.hi: 'सभी समय',
      AppLanguage.gu: 'બધો સમય',
    },
    'add_expense': {
      AppLanguage.en: 'Add Expense',
      AppLanguage.hi: 'खर्चा जोड़ें',
      AppLanguage.gu: 'ખર્ચ ઉમેરો',
    },
    'create_bill': {
      AppLanguage.en: 'Create Bill',
      AppLanguage.hi: 'बिल बनाएं',
      AppLanguage.gu: 'બિલ બનાવો',
    },
    'record_payment': {
      AppLanguage.en: 'Record Payment',
      AppLanguage.hi: 'भुगतान दर्ज करें',
      AppLanguage.gu: 'ચુકવણી નોંધો',
    },
    'punch_attendance': {
      AppLanguage.en: 'Punch Attendance',
      AppLanguage.hi: 'हाजिरी लगाएं',
      AppLanguage.gu: 'હાજરી પૂરો',
    },
    'export_csv': {
      AppLanguage.en: 'Export CSV',
      AppLanguage.hi: 'CSV निर्यात करें',
      AppLanguage.gu: 'CSV નિકાસ કરો',
    },
    'search': {
      AppLanguage.en: 'Search',
      AppLanguage.hi: 'खोजें',
      AppLanguage.gu: 'શોધો',
    },
    'driver_portal': {
      AppLanguage.en: 'Driver Portal',
      AppLanguage.hi: 'ड्राइवर पोर्टल',
      AppLanguage.gu: 'ડ્રાઇવર પોર્ટલ',
    },
    'duty_and_photos': {
      AppLanguage.en: 'Duty & Photos',
      AppLanguage.hi: 'ड्यूटी और फोटो',
      AppLanguage.gu: 'ડ્યુટી અને ફોટો',
    },
    'trip_and_route': {
      AppLanguage.en: 'Trip & Route',
      AppLanguage.hi: 'ट्रिप और रास्ता',
      AppLanguage.gu: 'ટ્રિપ અને રસ્તો',
    },
    'driver_desk_title': {
      AppLanguage.en: 'Driver Desk - Photo Hub',
      AppLanguage.hi: 'ड्राइवर डेस्क - फोटो हब',
      AppLanguage.gu: 'ડ્રાઇવર ડેસ્ક - ફોટો હબ',
    },
    'trip_navigation_title': {
      AppLanguage.en: 'Trip & Route Navigation',
      AppLanguage.hi: 'ट्रिप और नेविगेशन',
      AppLanguage.gu: 'ટ્રિપ અને નેવિગેશન',
    },
    'quick_upload_title': {
      AppLanguage.en: 'Quick Photo Upload',
      AppLanguage.hi: 'फोटो जमा करें (त्वरित अपलोड)',
      AppLanguage.gu: 'ફોટો જમા કરો (ઝડપી અપલોડ)',
    },
    'quick_upload_subtitle': {
      AppLanguage.en: 'Tap a card and snap a photo to submit',
      AppLanguage.hi: 'कार्ड दबाएं और कैमरा से फोटो लेकर सबमिट करें',
      AppLanguage.gu: 'કાર્ડ દબાવો અને કેમેરાથી ફોટો લઈને સબમિટ કરો',
    },
    'on_duty': {
      AppLanguage.en: 'ON DUTY',
      AppLanguage.hi: 'ड्यूटी चालू',
      AppLanguage.gu: 'ડ્યુટી ચાલુ',
    },
    'off_duty': {
      AppLanguage.en: 'OFF DUTY',
      AppLanguage.hi: 'ड्यूटी बंद',
      AppLanguage.gu: 'ડ્યુટી બંધ',
    },
    'start_duty': {
      AppLanguage.en: 'Start Duty (हाजिरी लगाएं)',
      AppLanguage.hi: 'ड्यूटी शुरू करें (हाजिरी लगाएं)',
      AppLanguage.gu: 'ડ્યુટી શરૂ કરો (હાજરી પૂરો)',
    },
    'end_duty': {
      AppLanguage.en: 'End Duty (ड्यूटी समाप्त)',
      AppLanguage.hi: 'ड्यूटी समाप्त करें',
      AppLanguage.gu: 'ડ્યુટી પૂર્ણ કરો',
    },
    'assigned_vehicle': {
      AppLanguage.en: 'Assigned Vehicle',
      AppLanguage.hi: 'आवंटित वाहन (आपकी गाड़ी)',
      AppLanguage.gu: 'સોંપેલ વાહન (તમારી ગાડી)',
    },
    'duty_attendance_title': {
      AppLanguage.en: 'Driver Duty & Attendance',
      AppLanguage.hi: 'ड्राइवर ड्यूटी और हाजिरी',
      AppLanguage.gu: 'ડ્રાઇવર ડ્યુટી અને હાજરી',
    },
    'verified_truck': {
      AppLanguage.en: 'VERIFIED TRUCK',
      AppLanguage.hi: 'सत्यापित ट्रक',
      AppLanguage.gu: 'ચકાસાયેલ ટ્રક',
    },
    'recent_photos': {
      AppLanguage.en: 'Recent Uploaded Photos',
      AppLanguage.hi: 'हाल ही में अपलोड की गई फोटो',
      AppLanguage.gu: 'તાજેતરમાં અપલોડ કરેલા ફોટા',
    },
    'seatbelt_photo': {
      AppLanguage.en: 'Driver Seatbelt Photo',
      AppLanguage.hi: 'सीटबेल्ट फोटो',
      AppLanguage.gu: 'સીટબેલ્ટ ફોટો',
    },
    'sunday_cleaning': {
      AppLanguage.en: 'Sunday Vehicle Cleaning',
      AppLanguage.hi: 'रविवार वाहन धुलाई व सफाई',
      AppLanguage.gu: 'રવિવાર વાહન સફાઈ',
    },
    'police_memo': {
      AppLanguage.en: 'Police Memo / Challan',
      AppLanguage.hi: 'पुलिस मेमो / चालान',
      AppLanguage.gu: 'પોલીસ મેમો / ચલણ',
    },
    'meter_photo': {
      AppLanguage.en: 'Service & Meter Photo',
      AppLanguage.hi: 'सर्विस व मीटर फोटो',
      AppLanguage.gu: 'સર્વિસ અને મીટર ફોટો',
    },
    'insurance_puc': {
      AppLanguage.en: 'Insurance & PUC Papers',
      AppLanguage.hi: 'बीमा और पीयूसी कागजात',
      AppLanguage.gu: 'વીમો અને પીયુસી કાગળો',
    },
    'fuel_receipt': {
      AppLanguage.en: 'Bilty / Diesel & Toll Slip',
      AppLanguage.hi: 'बिल्टी / डीजल व टोल पर्ची',
      AppLanguage.gu: 'બિલ્ટી / ડીઝલ અને ટોલ પર્ચી',
    },
    'tyre_change': {
      AppLanguage.en: 'Tyre Change',
      AppLanguage.hi: 'टायर बदलाव',
      AppLanguage.gu: 'ટાયર બદલો',
    },
    'report_km_position': {
      AppLanguage.en: 'Report KM & Position',
      AppLanguage.hi: 'मीटर व स्थान दर्ज करें',
      AppLanguage.gu: 'મીટર અને સ્થળ નોંધો',
    },
    'daily_fluids': {
      AppLanguage.en: 'Daily Fluids Check',
      AppLanguage.hi: 'दैनिक तेल/पानी जांच',
      AppLanguage.gu: 'દૈનિક તેલ/પાણી તપાસ',
    },
    'fluids_check_desc': {
      AppLanguage.en: 'Oil, Coolant, DEF, Brakes',
      AppLanguage.hi: 'ऑयल, कूलेंट, DEF, ब्रेक जांच',
      AppLanguage.gu: 'ઓઇલ, કુલન્ટ, DEF, બ્રેક તપાસ',
    },
    'sunday_clean_title': {
      AppLanguage.en: 'Sunday Vehicle Cleaning',
      AppLanguage.hi: 'रविवार वाहन धुलाई व सफाई',
      AppLanguage.gu: 'રવિવાર વાહન સફાઈ',
    },
    'cleaning_due_today': {
      AppLanguage.en: 'Sunday Vehicle Cleaning Due Today!',
      AppLanguage.hi: 'आज रविवार गाड़ी धुलाई का दिन है!',
      AppLanguage.gu: 'આજે રવિવાર વાહન સફાઈનો દિવસ છે!',
    },
    'cleaning_schedule': {
      AppLanguage.en: 'Weekly Sunday Cleaning Schedule',
      AppLanguage.hi: 'साप्ताहिक रविवार गाड़ी धुलाई शिड्यूल',
      AppLanguage.gu: 'સાપ્તાહિક રવિવાર વાહન સફાઈ શિડ્યુલ',
    },
    'memo_banner_title': {
      AppLanguage.en: 'Police / RTO Memo Received?',
      AppLanguage.hi: 'पुलिस / RTO मेमो मिला?',
      AppLanguage.gu: 'પોલીસ / RTO મેમો મળ્યો?',
    },
    'memo_banner_sub': {
      AppLanguage.en: 'Upload fine receipt or challan photo immediately',
      AppLanguage.hi: 'चालान या फाइन पर्ची की तुरंत फोटो अपलोड करें',
      AppLanguage.gu: 'ચલણ અથવા દંડ પર્ચીનો તાત્કાલિક ફોટો અપલોડ કરો',
    },
    'take_photo': {
      AppLanguage.en: 'TAKE PHOTO',
      AppLanguage.hi: 'फोटो लें',
      AppLanguage.gu: 'ફોટો લો',
    },
    'route_map_live_gps': {
      AppLanguage.en: 'Route Map & Live GPS',
      AppLanguage.hi: 'रास्ता नक्शा और लाइव जीपीएस',
      AppLanguage.gu: 'રૂટ નકશો અને લાઈવ જીપીએસ',
    },
    'open_map': {
      AppLanguage.en: 'OPEN MAP',
      AppLanguage.hi: 'नक्शा खोलें',
      AppLanguage.gu: 'નકશો ખોલો',
    },
    'route_map_sub': {
      AppLanguage.en: 'View assigned trip route and launch live turn navigation',
      AppLanguage.hi: 'ट्रिप का रास्ता देखें और लाइव नेविगेशन शुरू करें',
      AppLanguage.gu: 'ટ્રિપનો રસ્તો જુઓ અને લાઈવ નેવિગેશન શરૂ કરો',
    },
    'maintenance_and_insurance': {
      AppLanguage.en: 'Maintenance & Insurance',
      AppLanguage.hi: 'मेंटेनेंस और बीमा',
      AppLanguage.gu: 'મેન્ટેનન્સ અને વીમો',
    },
    'insurance_puc_title': {
      AppLanguage.en: 'Insurance & PUC',
      AppLanguage.hi: 'बीमा और पीयूसी',
      AppLanguage.gu: 'વીમો અને પીયુસી',
    },
    'next_service': {
      AppLanguage.en: 'Next Service',
      AppLanguage.hi: 'अगली सर्विस',
      AppLanguage.gu: 'આગામી સર્વિસ',
    },
    'view_all': {
      AppLanguage.en: 'View All',
      AppLanguage.hi: 'सभी देखें',
      AppLanguage.gu: 'બધા જુઓ',
    },
    'no_photos_uploaded': {
      AppLanguage.en: 'No photos uploaded yet',
      AppLanguage.hi: 'अभी तक कोई फोटो अपलोड नहीं हुई',
      AppLanguage.gu: 'હજી સુધી કોઈ ફોટો અપલોડ થયો નથી',
    },
    'duty_record': {
      AppLanguage.en: 'Record Attendance',
      AppLanguage.hi: 'हाजिरी दर्ज करें',
      AppLanguage.gu: 'હાજરી નોંધો',
    },
    'cancel': {
      AppLanguage.en: 'Cancel',
      AppLanguage.hi: 'रद्द करें',
      AppLanguage.gu: 'રદ કરો',
    },
    'save': {
      AppLanguage.en: 'Save',
      AppLanguage.hi: 'सुरक्षित करें',
      AppLanguage.gu: 'સાચવો',
    },
    // Login Screen
    'whatsapp_otp': {
      AppLanguage.en: 'WhatsApp OTP',
      AppLanguage.hi: 'व्हाट्सएप ओटीपी',
      AppLanguage.gu: 'વોટ્સએપ ઓટીપી',
    },
    'password_pin': {
      AppLanguage.en: 'Password / PIN',
      AppLanguage.hi: 'पासवर्ड / पिन',
      AppLanguage.gu: 'પાસવર્ડ / પિન',
    },
    'phone_number': {
      AppLanguage.en: 'Phone Number',
      AppLanguage.hi: 'फ़ोन नंबर',
      AppLanguage.gu: 'ફોન નંબર',
    },
    'driver_id_or_email': {
      AppLanguage.en: 'Driver ID or Account Email',
      AppLanguage.hi: 'ड्राइवर आईडी या अकाउंट ईमेल',
      AppLanguage.gu: 'ડ્રાઇવર આઈડી અથવા એકાઉન્ટ ઇમેઇલ',
    },
    'enter_mobile_hint': {
      AppLanguage.en: 'Enter 10-digit Mobile Number',
      AppLanguage.hi: '10 अंकों का मोबाइल नंबर दर्ज करें',
      AppLanguage.gu: '10 અંકનો મોબાઇલ નંબર દાખલ કરો',
    },
    'enter_password_hint': {
      AppLanguage.en: 'Enter Password or PIN',
      AppLanguage.hi: 'पासवर्ड या पिन दर्ज करें',
      AppLanguage.gu: 'પાસવર્ડ અથવા પિન દાખલ કરો',
    },
    'password_label': {
      AppLanguage.en: 'Password',
      AppLanguage.hi: 'पासवर्ड',
      AppLanguage.gu: 'પાસવર્ડ',
    },
    'sign_in': {
      AppLanguage.en: 'Sign In',
      AppLanguage.hi: 'साइन इन करें',
      AppLanguage.gu: 'સાઇન ઇન કરો',
    },
    'send_otp': {
      AppLanguage.en: 'Send WhatsApp OTP',
      AppLanguage.hi: 'व्हाट्सएप OTP भेजें',
      AppLanguage.gu: 'વોટ્સએપ OTP મોકલો',
    },
    'verify_and_sign_in': {
      AppLanguage.en: 'Verify & Sign In',
      AppLanguage.hi: 'सत्यापित और साइन इन करें',
      AppLanguage.gu: 'ચકાસો અને સાઇન ઇન કરો',
    },
    'auto_login_enabled': {
      AppLanguage.en: 'Auto-Login Enabled: Session permanently saved on this device',
      AppLanguage.hi: 'ऑटो-लॉगिन सक्रिय: सत्र इस फोन में सुरक्षित रहेगा',
      AppLanguage.gu: 'ઓટો-લૉગિન સક્ષમ: સત્ર આ ડિવાઇસ પર કાયમી સાચવેલ છે',
    },
    // Driver Portal & Trips
    'attendance_history': {
      AppLanguage.en: 'Duty History',
      AppLanguage.hi: 'हाजिरी इतिहास',
      AppLanguage.gu: 'હાજરી ઇતિહાસ',
    },
    'trip_history': {
      AppLanguage.en: 'Trip History',
      AppLanguage.hi: 'ट्रिप इतिहास',
      AppLanguage.gu: 'ટ્રિપ ઇતિહાસ',
    },
    'driver_docs_title': {
      AppLanguage.en: 'Driver License & Insurance Validity',
      AppLanguage.hi: 'ड्राइविंग लाइसेंस व बीमा वैधता',
      AppLanguage.gu: 'ડ્રાઇવિંગ લાયસન્સ અને વીમા માન્યતા',
    },
    'driver_docs_subtitle': {
      AppLanguage.en: 'Official documents and insurance expiry dates',
      AppLanguage.hi: 'आपके कागजात और बीमा की तारीख',
      AppLanguage.gu: 'તમારા દસ્તાવેજો અને વીમાની તારીખ',
    },
    'driving_license_label': {
      AppLanguage.en: 'Driving License (DL):',
      AppLanguage.hi: 'ड्राइविंग लाइसेंस (DL):',
      AppLanguage.gu: 'ડ્રાઇવિંગ લાયસન્સ (DL):',
    },
    'driver_insurance_label': {
      AppLanguage.en: 'Driver Bima (Insurance):',
      AppLanguage.hi: 'ड्राइवर बीमा (Insurance):',
      AppLanguage.gu: 'ડ્રાઇવર વીમો (Insurance):',
    },
    'cargo_balance_title': {
      AppLanguage.en: 'CARGO & SHIPMENT BALANCE',
      AppLanguage.hi: 'माल और शिपमेंट बैलेंस',
      AppLanguage.gu: 'માલ અને શિપમેન્ટ બેલેન્સ',
    },
    'stop_ledger': {
      AppLanguage.en: 'Stop Ledger',
      AppLanguage.hi: 'स्टॉप लेजर',
      AppLanguage.gu: 'સ્ટોપ લેજર',
    },
    'delivery_proof': {
      AppLanguage.en: 'DELIVERY PROOF',
      AppLanguage.hi: 'डिलीवरी प्रूफ',
      AppLanguage.gu: 'ડિલિવરી પ્રૂફ',
    },
    'receiving_copy': {
      AppLanguage.en: 'RECEIVING',
      AppLanguage.hi: 'रिसीविंग कॉपी',
      AppLanguage.gu: 'રીસીવિંગ કોપી',
    },
    'kharcha': {
      AppLanguage.en: 'EXPENSES',
      AppLanguage.hi: 'खर्चा',
      AppLanguage.gu: 'ખર્ચ',
    },
    'call_customer': {
      AppLanguage.en: 'CALL CUSTOMER',
      AppLanguage.hi: 'ग्राहक को कॉल करें',
      AppLanguage.gu: 'ગ્રાહકને કૉલ કરો',
    },
    'google_maps': {
      AppLanguage.en: 'GOOGLE MAPS',
      AppLanguage.hi: 'गूगल मैप्स',
      AppLanguage.gu: 'ગૂગલ મેપ્સ',
    },
    'upload_meter_photo': {
      AppLanguage.en: 'Upload Meter/Photo',
      AppLanguage.hi: 'मीटर/फोटो अपलोड करें',
      AppLanguage.gu: 'મીટર/ફોટો અપલોડ કરો',
    },
    'upload_document': {
      AppLanguage.en: 'Upload Document',
      AppLanguage.hi: 'दस्तावेज़ अपलोड करें',
      AppLanguage.gu: 'દસ્તાવેજ અપલોડ કરો',
    },
  };

  String tr(String key) {
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[language] ?? entry[AppLanguage.en] ?? key;
  }
}
