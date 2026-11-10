import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Answer of the verification server. Every field is `null` when the server could not
/// tell (network error, API not configured, verdict unevaluated) - callers must treat
/// `null` as "keep what you have", never as a negative answer.
class VerifyResult {
  /// Google Play says the purchase token is a valid, completed purchase of the product.
  final bool? purchaseValid;

  /// Play Integrity: the binary is the one Google Play distributes (PLAY_RECOGNIZED).
  /// `false` means a modified or re-signed APK.
  final bool? appRecognized;

  const VerifyResult({this.purchaseValid, this.appRecognized});
  static const unknown = VerifyResult();
}

/// Level-4 tamper defence: asks our server (a Supabase Edge Function holding a Google
/// service account) to check the purchase token with the Google Play Developer API and
/// to decode a Play Integrity token. Patchers such as Lucky Patcher can fake the local
/// billing answer, but not a token that Google's servers accept.
///
/// Disabled (every call returns [VerifyResult.unknown]) until the build gets
/// `--dart-define=VERIFY_URL=...` and `VERIFY_KEY=...`.
class IntegrityService {
  static const _channel = MethodChannel('app/integrity');
  static const verifyUrl = String.fromEnvironment('VERIFY_URL');
  static const verifyKey = String.fromEnvironment('VERIFY_KEY');
  static const cloudProject = String.fromEnvironment('PLAY_CLOUD_PROJECT');

  static bool get enabled => verifyUrl.isNotEmpty && defaultTargetPlatform == TargetPlatform.android;

  static String _nonce() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
  }

  static Future<String?> _integrityToken(String nonce) async {
    try {
      return await _channel.invokeMethod<String>('token', {'nonce': nonce, 'cloudProject': cloudProject});
    } catch (e) {
      debugPrint('Integrity token unavailable: $e');
      return null;
    }
  }

  static Future<VerifyResult> verify({
    required String packageName,
    required String productId,
    String? purchaseToken,
  }) async {
    if (!enabled) return VerifyResult.unknown;
    final nonce = _nonce();
    final integrityToken = await _integrityToken(nonce);
    if (purchaseToken == null && integrityToken == null) return VerifyResult.unknown;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(Uri.parse(verifyUrl)).timeout(const Duration(seconds: 10));
      req.headers.contentType = ContentType.json;
      if (verifyKey.isNotEmpty) {
        req.headers.set('Authorization', 'Bearer $verifyKey');
        req.headers.set('apikey', verifyKey);
      }
      req.write(jsonEncode({
        'packageName': packageName,
        'productId': productId,
        if (purchaseToken != null) 'purchaseToken': purchaseToken,
        if (integrityToken != null) 'integrityToken': integrityToken,
        'nonce': nonce,
      }));
      final resp = await req.close().timeout(const Duration(seconds: 20));
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) return VerifyResult.unknown;
      final j = jsonDecode(body) as Map<String, dynamic>;
      // A verdict only counts when the server confirms it was issued for our nonce.
      final nonceOk = j['nonceOk'] == true;
      return VerifyResult(
        purchaseValid: j['purchaseValid'] as bool?,
        appRecognized: nonceOk ? j['appRecognized'] as bool? : null,
      );
    } catch (e) {
      debugPrint('Verification failed: $e');
      return VerifyResult.unknown;
    } finally {
      client.close(force: true);
    }
  }
}
