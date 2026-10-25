import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/models/student_user.dart';
import '../../domain/services/crypto_service.dart';

enum CredentialMode { nfcHce, dynamicQr }

class CredentialViewModel extends ChangeNotifier {
  final StudentUser user;
  CredentialMode _mode = CredentialMode.nfcHce;
  Timer? _ticker;

  String _qrString = '';
  String _totpCode = '------';
  int _remainingSeconds = 15;
  double _progress = 1.0;

  bool _isNfcBroadcasting = true;
  String _lastNfcPayloadJson = '';

  CredentialViewModel({required this.user}) {
    _initCredential();
  }

  CredentialMode get mode => _mode;
  String get qrString => _qrString;
  String get totpCode => _totpCode;
  int get remainingSeconds => _remainingSeconds;
  double get progress => _progress;
  bool get isNfcBroadcasting => _isNfcBroadcasting;
  String get lastNfcPayloadJson => _lastNfcPayloadJson;

  void _initCredential() {
    _refreshNfcPayload();
    _refreshDynamicQr();

    // Ticker a 100 ms para actualizar barra regresiva fluida y rotar TOTP
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _tick();
    });
  }

  void switchMode(CredentialMode newMode) {
    if (_mode != newMode) {
      _mode = newMode;
      if (_mode == CredentialMode.dynamicQr) {
        _refreshDynamicQr();
      } else {
        _refreshNfcPayload();
      }
      notifyListeners();
    }
  }

  void _refreshNfcPayload() {
    final payloadMap = CryptoService.generateNfcHcePayload(user);
    _lastNfcPayloadJson = jsonEncode(payloadMap);
    _isNfcBroadcasting = true;
  }

  void _refreshDynamicQr() {
    final qrData = CryptoService.generateDynamicQrPayload(user);
    _qrString = qrData['qr_string'] as String;
    _totpCode = qrData['totp_code'] as String;
    _remainingSeconds = qrData['remaining_seconds'] as int;
    _progress = qrData['progress'] as double;
  }

  void _tick() {
    final now = DateTime.now().toUtc();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final remaining = CryptoService.totpIntervalSeconds -
        (epochSeconds % CryptoService.totpIntervalSeconds);
    final msRemainder = (now.millisecondsSinceEpoch % 1000);
    final totalRemainingMs = (remaining - 1) * 1000 + (1000 - msRemainder);
    final newProgress = totalRemainingMs / (CryptoService.totpIntervalSeconds * 1000.0);

    bool shouldNotify = false;

    if (remaining != _remainingSeconds) {
      _remainingSeconds = remaining;
      shouldNotify = true;
    }

    if (newProgress != _progress) {
      _progress = newProgress.clamp(0.0, 1.0);
      shouldNotify = true;
    }

    // Rotar si cambiamos de intervalo de 15 segundos
    if (remaining == CryptoService.totpIntervalSeconds && msRemainder < 150) {
      _refreshDynamicQr();
      _refreshNfcPayload();
      shouldNotify = true;
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
