import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String notes;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.notes,
  });
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// อ่าน update.json จาก GitHub raw แล้วเทียบ versionCode กับแอพที่ติดตั้งอยู่
  Future<UpdateInfo?> check(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final remoteCode = int.tryParse('${decoded['versionCode']}') ?? 0;
    final package = await PackageInfo.fromPlatform();
    final localCode = int.tryParse(package.buildNumber) ?? 0;
    if (remoteCode <= localCode) return null;

    final apkUrl = (decoded['apkUrl'] ?? '').toString();
    if (apkUrl.isEmpty) return null;

    return UpdateInfo(
      versionCode: remoteCode,
      versionName: (decoded['versionName'] ?? 'ใหม่กว่า').toString(),
      apkUrl: apkUrl,
      notes: (decoded['notes'] ?? '').toString(),
    );
  }

  /// เปิดลิงก์ APK ในเบราว์เซอร์ → ผู้ใช้กดดาวน์โหลดแล้วติดตั้งเอง
  /// (ไม่ต้องขอสิทธิ์ REQUEST_INSTALL_PACKAGES ในแอพ)
  Future<bool> openDownload(String apkUrl) async {
    final uri = Uri.tryParse(apkUrl);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
