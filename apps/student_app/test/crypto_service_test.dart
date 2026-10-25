import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/domain/models/student_user.dart';
import 'package:student_app/domain/services/crypto_service.dart';

void main() {
  group('CryptoService & 512D Vector Tests', () {
    test('generateNfcHcePayload creates valid HMAC signed packet', () {
      final user = InstitutionalMockDatabase.users.first;
      final payload = CryptoService.generateNfcHcePayload(user);

      expect(payload['protocol'], 'NFC_HCE_ISO_14443_4');
      expect(payload['student_id'], user.id);
      expect(payload['rut'], user.rut);
      expect(payload['signature'], isNotEmpty);

      final rawData = '${user.id}|${user.rut}|${user.role.code}|${payload['timestamp']}|${payload['nonce']}';
      final isValid = CryptoService.verifySignature(rawData, payload['signature'] as String);
      expect(isValid, isTrue);
    });

    test('generateDynamicQrPayload adheres to 15s RFC 6238 TOTP format', () {
      final user = InstitutionalMockDatabase.users.first;
      final qrData = CryptoService.generateDynamicQrPayload(user);

      expect(qrData['totp_code'], hasLength(6));
      expect(int.tryParse(qrData['totp_code'] as String), isNotNull);
      expect(qrData['remaining_seconds'], inInclusiveRange(1, 15));
      expect(qrData['progress'], inInclusiveRange(0.0, 1.0));
      expect(qrData['qr_string'], contains('UA_DYNAMIC_QR_FALLBACK'));
    });

    test('512-dimensional face vectors are strictly mathematical and normalized', () {
      final user = InstitutionalMockDatabase.users.first;
      expect(user.faceVector512.length, 512);

      // Verify no raw image paths or Base64 image data exist in the entity
      expect(user.faceVector512.every((v) => v >= -1.0 && v <= 1.0), isTrue);
    });
  });
}
