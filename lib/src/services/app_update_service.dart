import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Checks GitHub Releases for a newer version of the Transport One APK.
/// When found, automatically and silently downloads and triggers the installation
/// without displaying any dialogs, buttons, or prompt UI to the user.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String _githubRepo = 'rbcimportandexport/FleetRoute';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/$_githubRepo/releases/latest';

  bool _isCheckingOrUpdating = false;

  /// Silently checks for updates and triggers installation automatically.
  /// Zero UI shown in the app.
  Future<void> checkAndApplyUpdateSilently() async {
    if (_isCheckingOrUpdating) return;
    _isCheckingOrUpdating = true;

    // Web builds are always up to date from the hosting server
    if (kIsWeb) {
      _isCheckingOrUpdating = false;
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. 1.4.4
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final res = await http.get(
        Uri.parse(_latestReleaseApi),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        _isCheckingOrUpdating = false;
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      final tagName = rawTag.replaceAll('v', '').trim();

      // Find direct download URL for the .apk asset
      String? apkDownloadUrl;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkDownloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (apkDownloadUrl == null || apkDownloadUrl.isEmpty) {
        _isCheckingOrUpdating = false;
        return;
      }

      // Check if remote version is newer
      final bool isNewer = _isVersionNewer(
        remoteTag: tagName,
        localVersion: currentVersion,
        localBuild: currentBuildNumber,
      );

      if (isNewer) {
        debugPrint('[AppUpdateService] Newer update found: $tagName. Starting silent auto-update...');
        _startSilentOtaUpdate(apkDownloadUrl);
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Silent update check error: $e');
    } finally {
      _isCheckingOrUpdating = false;
    }
  }

  void _startSilentOtaUpdate(String url) {
    try {
      OtaUpdate()
          .execute(
        url,
        destinationFilename: 'TransportOne-Release.apk',
      )
          .listen(
        (OtaEvent event) {
          debugPrint('[AppUpdateService] Silent OTA status: ${event.status}, value: ${event.value}');
        },
        onError: (dynamic error) {
          debugPrint('[AppUpdateService] Silent OTA error: $error');
        },
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Could not trigger OTA update: $e');
    }
  }

  bool _isVersionNewer({
    required String remoteTag,
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
}
