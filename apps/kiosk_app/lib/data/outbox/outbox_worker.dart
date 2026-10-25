import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/turnstile_database.dart';

class OutboxWorker extends ChangeNotifier {
  final TurnstileDatabase database;
  String backendBaseUrl;

  bool _isIslandMode = false;
  bool _isSyncing = false;
  Timer? _syncTimer;

  int _pendingCount = 0;
  int _syncedCount = 0;
  String _lastSyncMessage = 'Inicializado en espera';
  DateTime? _lastSyncTime;

  OutboxWorker({
    required this.database,
    this.backendBaseUrl = 'http://127.0.0.1:8080',
  }) {
    _startSyncLoop();
    refreshStats();
  }

  bool get isIslandMode => _isIslandMode;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  int get syncedCount => _syncedCount;
  String get lastSyncMessage => _lastSyncMessage;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Conmuta el switch "Modo Isla" (Simulador de Corte de Fibra Óptica 72h)
  void toggleIslandMode() {
    _isIslandMode = !_isIslandMode;
    if (_isIslandMode) {
      _lastSyncMessage = 'MODO ISLA ACTIVO: Red WAN desconectada. Eventos se retienen en SQLite local.';
    } else {
      _lastSyncMessage = 'MODO EN LÍNEA: Conectividad restaurada. Despachando lotes acumulados...';
      triggerSyncNow();
    }
    notifyListeners();
  }

  void setIslandMode(bool active) {
    if (_isIslandMode != active) {
      _isIslandMode = active;
      if (_isIslandMode) {
        _lastSyncMessage = 'MODO ISLA ACTIVO: Red WAN desconectada.';
      } else {
        _lastSyncMessage = 'MODO EN LÍNEA: Sincronizando Outbox con Central Go...';
        triggerSyncNow();
      }
      notifyListeners();
    }
  }

  void _startSyncLoop() {
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isIslandMode && !_isSyncing) {
        _dispatchPendingBatch();
      } else {
        refreshStats();
      }
    });
  }

  Future<void> refreshStats() async {
    try {
      final stats = await database.getOutboxStats();
      _pendingCount = stats['pending'] ?? 0;
      _syncedCount = stats['synced'] ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> triggerSyncNow() async {
    if (!_isSyncing) {
      await _dispatchPendingBatch();
    }
  }

  Future<void> _dispatchPendingBatch() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final pendingEvents = await database.getPendingEvents(limit: 50);
      if (pendingEvents.isEmpty) {
        _isSyncing = false;
        await refreshStats();
        return;
      }

      // Preparar payload de lote (Batch)
      final batchPayload = {
        'turnstile_id': pendingEvents.first.turnstileId,
        'campus_id': pendingEvents.first.campusId,
        'dispatch_timestamp': DateTime.now().toUtc().toIso8601String(),
        'events_count': pendingEvents.length,
        'events': pendingEvents.map((e) => e.toMap()).toList(),
      };

      final endpoint = Uri.parse('$backendBaseUrl/api/v1/ingest/batch');

      http.Response? response;
      try {
        response = await http
            .post(
              endpoint,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer UA_EDGE_TOKEN_2026_JWT',
              },
              body: jsonEncode(batchPayload),
            )
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        // Si el backend físico aún no está levantado, el Transactional Outbox
        // mantiene los eventos seguros en SQLite local (Modo Isla automático)
        _lastSyncMessage = 'Backend central no alcanzable. Reintento en 3s (Backoff).';
      }

      if (response != null && response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['status'] == 'ACK_CONFIRMED' && body['ack_map'] != null) {
          final rawMap = body['ack_map'] as Map<String, dynamic>;
          final ackMap = rawMap.map((k, v) => MapEntry(k, v.toString()));

          final updated = await database.markEventsAsSynced(ackMap);
          _lastSyncTime = DateTime.now();
          _lastSyncMessage = 'Lote de $updated eventos sincronizado con confirmación ACK forense.';
        }
      }
    } catch (e) {
      _lastSyncMessage = 'Error en despacho outbox: $e';
    } finally {
      _isSyncing = false;
      await refreshStats();
    }
  }

  /// Método de simulación para pruebas de defensa y video si se ejecuta offline
  Future<void> simulateLocalAckForDemo() async {
    final pending = await database.getPendingEvents(limit: 50);
    if (pending.isEmpty) return;

    final mockAck = <String, String>{};
    for (final ev in pending) {
      mockAck[ev.eventUuid] = 'ACK-${ev.payloadHash.substring(0, 16)}';
    }
    final updated = await database.markEventsAsSynced(mockAck);
    _lastSyncTime = DateTime.now();
    _lastSyncMessage = 'Simulación: $updated eventos marcados como SYNCED con ACK local.';
    await refreshStats();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
