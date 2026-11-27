import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/planner_controller.dart';
import '../widgets/document_expiry_panel_sheet.dart';
import 'admin_dashboard_screen.dart';
import 'admin_live_map_screen.dart';
import 'admin_trip_planner_screen.dart';
import 'admin_driver_view_screen.dart';

class AdminMainScaffold extends StatefulWidget {
  const AdminMainScaffold({required this.controller, super.key});

  final PlannerController controller;

  @override
  State<AdminMainScaffold> createState() => _AdminMainScaffoldState();
}

class _AdminMainScaffoldState extends State<AdminMainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  String _adminName = '';
  String? _adminPhotoBase64;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initDefaultName();
    _loadAdminProfile();
  }

  void _initDefaultName() {
    final regName = widget.controller.loggedInName;
    if (regName != null && regName.trim().isNotEmpty) {
      _adminName = regName.replaceAll('(Admin)', '').trim();
    } else {
      _adminName = 'Saurabh Yadav';
    }
  }

  Future<void> _loadAdminProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('admin_custom_name');
      final savedPhoto = prefs.getString('admin_custom_photo_b64');
      if (mounted) {
        setState(() {
          if (savedName != null && savedName.trim().isNotEmpty) {
            _adminName = savedName;
          } else {
            final regName = widget.controller.loggedInName;
            if (regName != null && regName.trim().isNotEmpty) {
              _adminName = regName.replaceAll('(Admin)', '').trim();
            } else {
              _adminName = 'Saurabh Yadav';
            }
          }
          _adminPhotoBase64 = savedPhoto;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAdminName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    setState(() => _adminName = trimmed);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_custom_name', trimmed);
    } catch (_) {}
  }

  Future<void> _pickAdminPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final b64 = base64Encode(bytes);
        setState(() => _adminPhotoBase64 = b64);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_custom_photo_b64', b64);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('फोटो सेलेक्ट करने में समस्या: $e')),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final textController = TextEditingController(text: _adminName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'एडमिन प्रोफाइल बदलें',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Photo selector options
              const Text(
                'फोटो चुनें (गैलरी या कैमरा)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickAdminPhoto(ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                      label: const Text('कैमरा', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF16A34A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickAdminPhoto(ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A)),
                      label: const Text('गैलरी', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Name text field
              const Text(
                'एडमिन नाम',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  hintText: 'अपना नाम लिखें...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _saveAdminName(textController.text);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'सेव करें (Save Profile)',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final List<Widget> screens = [
          AdminDashboardScreen(
            controller: widget.controller,
            onNavigateToMap: () => setState(() => _currentIndex = 1),
            onNavigateToPlanner: () => setState(() => _currentIndex = 2),
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          AdminLiveMapScreen(controller: widget.controller),
          AdminTripPlannerScreen(controller: widget.controller),
        ];

        final drivers = widget.controller.drivers.isNotEmpty
            ? widget.controller.drivers
            : PlannerController.defaultFleetDrivers;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF8FAFC),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      _showEditProfileDialog();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEFF6FF),
                                border: Border.all(color: const Color(0xFF2563EB), width: 2),
                              ),
                              child: ClipOval(
                                child: _adminPhotoBase64 != null
                                    ? Image.memory(
                                        base64Decode(_adminPhotoBase64!),
                                        fit: BoxFit.cover,
                                        width: 60,
                                        height: 60,
                                      )
                                    : const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 36),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _adminName,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 14),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'एडमिन कंट्रोल पैनल',
                                style: TextStyle(color: Color(0xFF2563EB), fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                              const Text(
                                'फोटो व नाम बदलने के लिए टैप करें',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_rounded, color: Color(0xFF2563EB)),
                  title: const Text('एडमिन डैशबोर्ड', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.location_on_rounded, color: Color(0xFF16A34A)),
                  title: const Text('लाइव लोकेशन मैप', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alt_route_rounded, color: Color(0xFFD97706)),
                  title: const Text('ट्रिप प्लानर', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notification_important_rounded, color: Color(0xFFE11D48)),
                  title: const Text('दस्तावेज़ रिन्यूअल अलर्ट व ट्रायल', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('1 महीना पहले 3x नोटिफिकेशन', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  onTap: () {
                    Navigator.pop(context);
                    DocumentExpiryPanelSheet.show(context);
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'ड्राइवर सेलेक्ट करें (Driver Dashboard):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ),
                ...drivers.map((driver) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.person, color: Color(0xFF16A34A), size: 20),
                    ),
                    title: Text(driver.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('गाड़ी: ${driver.assignedVehicle} • ${driver.phone}', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminDriverViewScreen(
                            controller: widget.controller,
                            initialDriver: driver,
                          ),
                        ),
                      );
                    },
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('लॉगआउट', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.controller.logout();
                  },
                ),
              ],
            ),
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'डैशबोर्ड',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.location_on_rounded,
                  label: 'लाइव लोकेशन',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.alt_route_rounded,
                  label: 'ट्रिप प्लानर',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    const activeColor = Color(0xFF2563EB); // Electric Royal Blue
    const inactiveColor = Color(0xFF64748B);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
