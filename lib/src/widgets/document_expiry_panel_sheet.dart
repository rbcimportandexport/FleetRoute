import 'package:flutter/material.dart';
import '../services/document_expiry_reminder_service.dart';
import '../services/overspeeding_alert_service.dart';

class DocumentExpiryPanelSheet extends StatefulWidget {
  const DocumentExpiryPanelSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DocumentExpiryPanelSheet(),
    );
  }

  @override
  State<DocumentExpiryPanelSheet> createState() => _DocumentExpiryPanelSheetState();
}

class _DocumentExpiryPanelSheetState extends State<DocumentExpiryPanelSheet> {
  List<ExpiryDocItem> _docs = [];
  bool _isLoading = true;
  bool _isFiringTrail = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final docs = await DocumentExpiryReminderService.instance.getAllDocuments();
    if (mounted) {
      setState(() {
        _docs = docs;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleTestNotifications() async {
    setState(() => _isFiringTrail = true);
    final count = await DocumentExpiryReminderService.instance.fireTrailNotifications();
    if (mounted) {
      setState(() => _isFiringTrail = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 $count ट्रायल नोटिफिकेशन फ़ोन के नोटिफिकेशन बार में भेज दिए गए हैं!'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _pickNewDate(ExpiryDocItem doc) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: doc.expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: '${doc.title} की नई एक्सपायरी तारीख चुनें',
    );
    if (picked != null) {
      await DocumentExpiryReminderService.instance.updateDocumentExpiry(doc.id, picked);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doc.title} की तारीख अपडेट हो गई!'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'दस्तावेज़ रिन्यूअल व नोटिफिकेशन',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '1 महीना पहले रोज़ाना 3 बार अलर्ट',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Trail Notification Action Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'दस्तावेज़ अलर्ट टेस्ट करें',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'लाइसेंस, फिटनेस, इंश्योरेंस, PUC नोटिफिकेशन',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: _isFiringTrail ? null : _handleTestNotifications,
                  child: _isFiringTrail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'टेस्ट करें (Test)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),

          // Overspeeding Test Action Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ओवरस्पीडिंग अलर्ट (110+ व 90+)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'हाईवे पर 110+ और गली में 90+ पर एडमिन अलर्ट',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: () async {
                    await OverspeedingAlertService.instance.fireTestOverspeedAlerts();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🚨 ओवरस्पीडिंग अलर्ट टेस्ट: नोटिफिकेशन बार में 110+ और 90+ का मैसेज भेजा गया!'),
                          backgroundColor: Color(0xFFDC2626),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'स्पीड टेस्ट',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Document List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _docs.length,
                    itemBuilder: (ctx, index) {
                      final doc = _docs[index];
                      final days = doc.daysLeft;
                      final isUrgent = days <= 10;
                      final isWithinMonth = doc.isDueWithinMonth;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isUrgent
                                ? const Color(0xFFFCA5A5)
                                : (isWithinMonth ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0)),
                            width: isWithinMonth ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: doc.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(doc.icon, color: doc.color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    doc.subtitle,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isUrgent
                                              ? const Color(0xFFFEE2E2)
                                              : (isWithinMonth ? const Color(0xFFFFEDD5) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          days <= 0
                                              ? 'एक्सपायर हो चुका है'
                                              : (isWithinMonth ? '⚠️ $days दिन बाक़ी (3x अलर्ट चालू)' : '✅ $days दिन बाक़ी'),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: isUrgent
                                                ? const Color(0xFFDC2626)
                                                : (isWithinMonth ? const Color(0xFFC2410C) : const Color(0xFF475569)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'तारीख: ${doc.expiryDate.day}/${doc.expiryDate.month}/${doc.expiryDate.year}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF2563EB)),
                              tooltip: 'तारीख बदलें',
                              onPressed: () => _pickNewDate(doc),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
