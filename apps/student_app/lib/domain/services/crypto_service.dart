import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/student_user.dart';

class CryptoService {
  static const String institutionalHmacSecret = 'UA_CAMPUS_SECRET_HMAC_2026_KEY_PROV';
  static const int totpIntervalSeconds = 15;

  /// Genera un Nonce criptográfico aleatorio
  static String generateNonce([int length = 16]) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(values).substring(0, length);
  }

  /// Calcula la firma HMAC-SHA256 de un mensaje
  static String signPayload(String payload, [String secret = institutionalHmacSecret]) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Genera la trama de emulación de tarjeta NFC HCE (ISO/IEC 14443-4)
  static Map<String, dynamic> generateNfcHcePayload(StudentUser user) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final nonce = generateNonce(12);
    final rawData = '${user.id}|${user.rut}|${user.role.code}|$timestamp|$nonce';
    final signature = signPayload(rawData);

    return {
      'protocol': 'NFC_HCE_ISO_14443_4',
      'frequency': '13.56MHz',
      'student_id': user.id,
      'rut': user.rut,
      'role': user.role.code,
      'full_name': user.fullName,
      'timestamp': timestamp,
      'nonce': nonce,
      'signature': signature,
    };
  }

  /// Calcula el código TOTP numérico y el payload para el QR Dinámico de 15 segundos
  static Map<String, dynamic> generateDynamicQrPayload(StudentUser user) {
    final now = DateTime.now().toUtc();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final timeStep = epochSeconds ~/ totpIntervalSeconds;
    final remainingSeconds = totpIntervalSeconds - (epochSeconds % totpIntervalSeconds);

    // Semilla combinada de tiempo y estudiante
    final timeStepBytes = utf8.encode('${user.id}|$timeStep|$institutionalHmacSecret');
    final hashDigest = sha256.convert(timeStepBytes).bytes;

    // Truncamiento dinámico estilo RFC 6238
    final offset = hashDigest[hashDigest.length - 1] & 0x0F;
    final binaryCode = ((hashDigest[offset] & 0x7f) << 24) |
        ((hashDigest[offset + 1] & 0xff) << 16) |
        ((hashDigest[offset + 2] & 0xff) << 8) |
        (hashDigest[offset + 3] & 0xff);
    final totpCode = (binaryCode % 1000000).toString().padLeft(6, '0');

    final signature = signPayload('${user.id}|$totpCode|$timeStep');

    final qrJsonString = jsonEncode({
      'type': 'UA_DYNAMIC_QR_FALLBACK',
      'student_id': user.id,
      'rut': user.rut,
      'role': user.role.code,
      'totp': totpCode,
      'time_step': timeStep,
      'sig': signature.substring(0, 16),
    });

    return {
      'qr_string': qrJsonString,
      'totp_code': totpCode,
      'time_step': timeStep,
      'remaining_seconds': remainingSeconds,
      'progress': remainingSeconds / totpIntervalSeconds,
    };
  }

  /// Verifica si una firma de payload es legítima
  static bool verifySignature(String rawData, String signature, [String secret = institutionalHmacSecret]) {
    final expected = signPayload(rawData, secret);
    return expected == signature;
  }
}
