import 'dart:convert';
import 'package:crypto/crypto.dart';

enum AccessResult {
  granted('GRANTED', 'Acceso Concedido'),
  denied('DENIED', 'Acceso Denegado');

  final String code;
  final String label;
  const AccessResult(this.code, this.label);
}

enum OutboxStatus {
  pending('PENDING', 'Pendiente de Sincronización'),
  synced('SYNCED', 'Sincronizado con Central');

  final String code;
  final String label;
  const OutboxStatus(this.code, this.label);
}

class TurnstileOutboxEvent {
  final int? id;
  final String eventUuid;
  final String turnstileId;
  final String campusId;
  final String studentId;
  final String studentRut;
  final String accessTimestamp;
  final AccessResult accessResult;
  final String? denialReason;
  final int latencyMs;
  final String payloadHash;
  final OutboxStatus status;
  final int retryCount;
  final String? syncedAt;
  final String? ackHash;

  const TurnstileOutboxEvent({
    this.id,
    required this.eventUuid,
    required this.turnstileId,
    required this.campusId,
    required this.studentId,
    required this.studentRut,
    required this.accessTimestamp,
    required this.accessResult,
    this.denialReason,
    required this.latencyMs,
    required this.payloadHash,
    required this.status,
    this.retryCount = 0,
    this.syncedAt,
    this.ackHash,
  });

  /// Genera el hash criptográfico SHA-256 del evento para garantizar inmutabilidad
  static String calculatePayloadHash({
    required String eventUuid,
    required String turnstileId,
    required String studentId,
    required String timestamp,
    required String result,
    required int latencyMs,
  }) {
    final raw = '$eventUuid|$turnstileId|$studentId|$timestamp|$result|$latencyMs';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'event_uuid': eventUuid,
      'turnstile_id': turnstileId,
      'campus_id': campusId,
      'student_id': studentId,
      'student_rut': studentRut,
      'access_timestamp': accessTimestamp,
      'access_result': accessResult.code,
      'denial_reason': denialReason,
      'latency_ms': latencyMs,
      'payload_hash': payloadHash,
      'status': status.code,
      'retry_count': retryCount,
      'synced_at': syncedAt,
      'ack_hash': ackHash,
    };
  }

  factory TurnstileOutboxEvent.fromMap(Map<String, dynamic> map) {
    return TurnstileOutboxEvent(
      id: map['id'] as int?,
      eventUuid: map['event_uuid'] as String,
      turnstileId: map['turnstile_id'] as String,
      campusId: map['campus_id'] as String? ?? 'CAMPUS_PROVIDENCIA',
      studentId: map['student_id'] as String,
      studentRut: map['student_rut'] as String? ?? '',
      accessTimestamp: map['access_timestamp'] as String,
      accessResult: map['access_result'] == 'GRANTED'
          ? AccessResult.granted
          : AccessResult.denied,
      denialReason: map['denial_reason'] as String?,
      latencyMs: map['latency_ms'] as int? ?? 0,
      payloadHash: map['payload_hash'] as String,
      status: map['status'] == 'SYNCED' ? OutboxStatus.synced : OutboxStatus.pending,
      retryCount: map['retry_count'] as int? ?? 0,
      syncedAt: map['synced_at'] as String?,
      ackHash: map['ack_hash'] as String?,
    );
  }
}
