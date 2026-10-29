import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks GitHub Releases for a newer version of the Transport One APK.
/// When found, prompts the user to download and update with 1 click.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String _githubRepo = 'rbcimportandexport/FleetRoute';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/$_githubRepo/releases/latest';

  bool _checkedThisSession = false;

  Future<void> checkForUpdates(BuildContext context, {bool silentIfCurrent = true}) async {
    // Only check once per app launch session unless user manually requested it
    if (_checkedThisSession && silentIfCurrent) return;
    _checkedThisSession = true;

    // Web builds are always up to date from the server, OTA is for Android APK
    if (kIsWeb) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. 1.4.4
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final res = await http.get(
        Uri.parse(_latestReleaseApi),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      final tagName = rawTag.replaceAll('v', '').trim();
      final releaseName = data['name'] as String? ?? 'New Update Available';
      final releaseBody = data['body'] as String? ?? 'Bug fixes & UI performance improvements.';
      final publishedAtStr = data['published_at'] as String? ?? '';

      // Find the direct download URL for the apk asset
      String? apkDownloadUrl;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkDownloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      // Fallback release page if asset URL missing
      final updateUrl = apkDownloadUrl ?? (data['html_url'] as String? ?? 'https://github.com/$_githubRepo/releases/latest');

      // Compare versions
      bool isNewer = _isVersionNewer(
        remoteTag: tagName,
        remotePublishedAt: publishedAtStr,
        localVersion: currentVersion,
        localBuild: currentBuildNumber,
      );

      if (isNewer && context.mounted) {
        _showUpdateDialog(
          context,
          newVersion: tagName.isNotEmpty ? tagName : 'Latest',
          releaseTitle: releaseName,
          releaseNotes: releaseBody,
          downloadUrl: updateUrl,
        );
      } else if (!silentIfCurrent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aapka Transport One app pehle se hi latest version par hai!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for updates: $e');
    }
  }

  bool _isVersionNewer({
    required String remoteTag,
    required String remotePublishedAt,
    required String localVersion,
    required int localBuild,
  }) {
    if (remoteTag.isEmpty) return false;

    // Parse remote version e.g. 1.4.5+33 or 1.4.5
    final remoteParts = remoteTag.split('+');
    final remoteVer = remoteParts[0];
    final remoteBuild = remoteParts.length > 1 ? int.tryParse(remoteParts[1]) ?? 0 : 0;

    if (remoteBuild > 0 && localBuild > 0) {
      return remoteBuild > localBuild;
    }

    // Fallback semver comparison (1.4.5 vs 1.4.4)
    final remoteSegs = remoteVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final localSegs = localVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final r = i < remoteSegs.length ? remoteSegs[i] : 0;
      final l = i < localSegs.length ? localSegs[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }

    return false;
  }

  void _showUpdateDialog(
    BuildContext context, {
    required String newVersion,
    required String releaseTitle,
    required String releaseNotes,
    required String downloadUrl,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Update Available',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Naya update tayar hai',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.new_releases_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Version $newVersion available',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Naye UI updates, intermediate stops aur safety fixes ke sath app ko update karein.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Baad me (Later)', style: TextStyle(color: Color(0xFF64748B))),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text(
                'Update Karein (1-Click)',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }
}
