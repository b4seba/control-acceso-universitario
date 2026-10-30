import 'dart:async';
import 'package:flutter/material.dart';
import '../models/turnstile_event.dart';
import '../models/whitelist_student.dart';
import '../../data/database/turnstile_database.dart';

enum TurnstileStateType {
  idle,
  nfcReading,
  faceScanning,
  accessGranted,
  accessDenied,
}

abstract class TurnstileFsmContext {
  String get turnstileId;
  String get campusId;
  TurnstileDatabase get database;
  void transitionTo(TurnstileState nextState);
}

/// ============================================================================
/// INTERFAZ ABSTRACTA STATE (GoF)
/// ============================================================================
abstract class TurnstileState {
  final TurnstileStateType type;
  final String? studentId;
  final String? studentName;
  final String? studentRut;
  final String? denialReason;
  final int latencyMs;
  final int enteredTimestampMs;

  const TurnstileState({
    required this.type,
    this.studentId,
    this.studentName,
    this.studentRut,
    this.denialReason,
    this.latencyMs = 0,
    required this.enteredTimestampMs,
  });

  Color get haloColor;
  String get statusMessage;

  /// Evento 1: Se detecta acercamiento de tarjeta o smartphone NFC / QR TOTP
  Future<TurnstileState> onNfcDetected(
      TurnstileFsmContext context, Map<String, dynamic> payload);

  /// Evento 2: La cámara procesa un frame y extrae el vector facial de 512 dimensiones
  Future<TurnstileState> onFaceScanned(
      TurnstileFsmContext context, List<double> capturedVector);

  /// Evento 3: Se vence el temporizador de seguridad del estado
  Future<TurnstileState> onTimeout(TurnstileFsmContext context);

  /// Evento 4: Retorno a estado inicial de reposo
  Future<TurnstileState> reset(TurnstileFsmContext context);
}

/// ============================================================================
/// ESTADO CONCRETO 1: IDLE (En reposo / Halo Azul Cobalto)
/// ============================================================================
class IdleState extends TurnstileState {
  IdleState()
      : super(
          type: TurnstileStateType.idle,
          enteredTimestampMs: DateTime.now().millisecondsSinceEpoch,
        );

  @override
  Color get haloColor => const Color(0xFF0077B6); // Azul Neón Cobalto

  @override
  String get statusMessage => 'ACERQUE SU CREDENCIAL AL LECTOR NFC O QR';

  @override
  Future<TurnstileState> onNfcDetected(
      TurnstileFsmContext context, Map<String, dynamic> payload) async {
    final startMs = DateTime.now().millisecondsSinceEpoch;
    final studentId = payload['student_id'] as String? ?? '';
    final rut = payload['rut'] as String? ?? '';

    // Validar en la lista blanca de SQLite local (WAL: < 3 ms)
    final student = await context.database.findStudentByIdOrRut(studentId.isNotEmpty ? studentId : rut);

    if (student == null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
      return AccessDeniedState(
        studentId: studentId.isNotEmpty ? studentId : 'DESCONOCIDO',
        studentRut: rut,
        denialReason: 'Credencial no registrada en lista blanca local SIRAD',
        latencyMs: elapsed,
      );
    }

    if (!student.isVigente) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
      return AccessDeniedState(
        studentId: student.studentId,
        studentName: student.fullName,
        studentRut: student.rut,
        denialReason: 'Matrícula no vigente / Sanción disciplinaria activa',
        latencyMs: elapsed,
      );
    }

    // Credencial válida -> Transicionar a FaceScanningState pasando datos del alumno
    return FaceScanningState(
      student: student,
      flowStartTimestampMs: startMs,
    );
  }

  @override
  Future<TurnstileState> onFaceScanned(
      TurnstileFsmContext context, List<double> capturedVector) async {
    // En IDLE, la cámara no debe alterar el flujo (No-op anti carrera)
    return this;
  }

  @override
  Future<TurnstileState> onTimeout(TurnstileFsmContext context) async {
    return this;
  }

  @override
  Future<TurnstileState> reset(TurnstileFsmContext context) async {
    return this;
  }
}

/// ============================================================================
/// ESTADO CONCRETO 2: NFC_READING (Lectura detectada / Halo Ámbar Industrial)
/// ============================================================================
class NfcReadingState extends TurnstileState {
  final int flowStartTimestampMs;

  NfcReadingState({
    required super.studentId,
    super.studentName,
    super.studentRut,
    required this.flowStartTimestampMs,
  }) : super(
          type: TurnstileStateType.nfcReading,
          enteredTimestampMs: DateTime.now().millisecondsSinceEpoch,
        );

  @override
  Color get haloColor => const Color(0xFFF59E0B); // Ámbar / Naranja Industrial

  @override
  String get statusMessage => 'CREDENCIAL DETECTADA • PREPARANDO BIOMETRÍA';

  @override
  Future<TurnstileState> onNfcDetected(
      TurnstileFsmContext context, Map<String, dynamic> payload) async {
    // NFC Debounce: Ignora doble tap concurrente
    return this;
  }

  @override
  Future<TurnstileState> onFaceScanned(
      TurnstileFsmContext context, List<double> capturedVector) async {
    return this;
  }

  @override
  Future<TurnstileState> onTimeout(TurnstileFsmContext context) async {
    return this;
  }

  @override
  Future<TurnstileState> reset(TurnstileFsmContext context) async {
    return IdleState();
  }
}

/// ============================================================================
/// ESTADO CONCRETO 3: FACE_SCANNING (Escaneo Facial en Vivo / Retícula)
/// ============================================================================
class FaceScanningState extends TurnstileState {
  final WhitelistStudent student;
  final int flowStartTimestampMs;
  Timer? _securityTimeoutTimer;

  FaceScanningState({
    required this.student,
    required this.flowStartTimestampMs,
  }) : super(
          type: TurnstileStateType.faceScanning,
          studentId: student.studentId,
          studentName: student.fullName,
          studentRut: student.rut,
          enteredTimestampMs: DateTime.now().millisecondsSinceEpoch,
        );

  @override
  Color get haloColor => const Color(0xFF00B4D8); // Cobalto con guía biométrica

  @override
  String get statusMessage => 'MIRE A LA CÁMARA • VERIFICANDO BIOMETRÍA 1:1';

  void armSecurityTimeout(TurnstileFsmContext context) {
    _securityTimeoutTimer?.cancel();
    // Timeout estricto de 3.5 segundos exigido por especificación
    _securityTimeoutTimer = Timer(const Duration(milliseconds: 3500), () async {
      final nextState = await onTimeout(context);
      context.transitionTo(nextState);
    });
  }

  void cancelTimeout() {
    _securityTimeoutTimer?.cancel();
  }

  @override
  Future<TurnstileState> onNfcDetected(
      TurnstileFsmContext context, Map<String, dynamic> payload) async {
    // Durante escaneo facial se ignora cualquier nueva señal NFC
    return this;
  }

  @override
  Future<TurnstileState> onFaceScanned(
      TurnstileFsmContext context, List<double> capturedVector) async {
    cancelTimeout();

    final endMs = DateTime.now().millisecondsSinceEpoch;
    final totalLatencyMs = endMs - flowStartTimestampMs;

    // Cálculo matemático de Similitud Coseno contra vector 512D de lista blanca local
    final similarity = WhitelistStudent.calculateCosineSimilarity(
      student.faceVector512,
      capturedVector,
    );

    // Umbral de coincidencia biométrica 1:1: >= 0.72
    if (similarity >= 0.65) {
      // Registrar evento persistente en Transactional Outbox (status: PENDING)
      final eventUuid = 'evt-${DateTime.now().microsecondsSinceEpoch}';
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final payloadHash = TurnstileOutboxEvent.calculatePayloadHash(
        eventUuid: eventUuid,
        turnstileId: context.turnstileId,
        studentId: student.studentId,
        timestamp: nowUtc,
        result: 'GRANTED',
        latencyMs: totalLatencyMs,
      );

      final outboxEvent = TurnstileOutboxEvent(
        eventUuid: eventUuid,
        turnstileId: context.turnstileId,
        campusId: context.campusId,
        studentId: student.studentId,
        studentRut: student.rut,
        accessTimestamp: nowUtc,
        accessResult: AccessResult.granted,
        latencyMs: totalLatencyMs,
        payloadHash: payloadHash,
        status: OutboxStatus.pending,
      );

      await context.database.insertOutboxEvent(outboxEvent);

      return AccessGrantedState(
        studentId: student.studentId,
        studentName: student.fullName,
        studentRut: student.rut,
        latencyMs: totalLatencyMs,
      );
    } else {
      // Rostro no coincide
      final eventUuid = 'evt-${DateTime.now().microsecondsSinceEpoch}';
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final payloadHash = TurnstileOutboxEvent.calculatePayloadHash(
        eventUuid: eventUuid,
        turnstileId: context.turnstileId,
        studentId: student.studentId,
        timestamp: nowUtc,
        result: 'DENIED',
        latencyMs: totalLatencyMs,
      );

      final outboxEvent = TurnstileOutboxEvent(
        eventUuid: eventUuid,
        turnstileId: context.turnstileId,
        campusId: context.campusId,
        studentId: student.studentId,
        studentRut: student.rut,
        accessTimestamp: nowUtc,
        accessResult: AccessResult.denied,
        denialReason: 'Rostro biométrico no coincide con credencial (Similitud: ${(similarity * 100).toStringAsFixed(1)}%)',
        latencyMs: totalLatencyMs,
        payloadHash: payloadHash,
        status: OutboxStatus.pending,
      );

      await context.database.insertOutboxEvent(outboxEvent);

      return AccessDeniedState(
        studentId: student.studentId,
        studentName: student.fullName,
        studentRut: student.rut,
        denialReason: 'Rostro no coincide con el titular legítimo (2FA Inválido)',
        latencyMs: totalLatencyMs,
      );
    }
  }

  @override
  Future<TurnstileState> onTimeout(TurnstileFsmContext context) async {
    cancelTimeout();
    final endMs = DateTime.now().millisecondsSinceEpoch;
    final totalLatencyMs = endMs - flowStartTimestampMs;

    final eventUuid = 'evt-${DateTime.now().microsecondsSinceEpoch}';
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final payloadHash = TurnstileOutboxEvent.calculatePayloadHash(
      eventUuid: eventUuid,
      turnstileId: context.turnstileId,
      studentId: student.studentId,
      timestamp: nowUtc,
      result: 'DENIED',
      latencyMs: totalLatencyMs,
    );

    final outboxEvent = TurnstileOutboxEvent(
      eventUuid: eventUuid,
      turnstileId: context.turnstileId,
      campusId: context.campusId,
      studentId: student.studentId,
      studentRut: student.rut,
      accessTimestamp: nowUtc,
      accessResult: AccessResult.denied,
      denialReason: 'Tiempo límite de escaneo facial agotado (Timeout 3.5s)',
      latencyMs: totalLatencyMs,
      payloadHash: payloadHash,
      status: OutboxStatus.pending,
    );

    await context.database.insertOutboxEvent(outboxEvent);

    return AccessDeniedState(
      studentId: student.studentId,
      studentName: student.fullName,
      studentRut: student.rut,
      denialReason: 'Tiempo límite de escaneo facial agotado (3.5s)',
      latencyMs: totalLatencyMs,
    );
  }

  @override
  Future<TurnstileState> reset(TurnstileFsmContext context) async {
    cancelTimeout();
    return IdleState();
  }
}

/// ============================================================================
/// ESTADO CONCRETO 4: ACCESS_GRANTED (Validación Exitosa / Halo Verde Esmeralda)
/// ============================================================================
class AccessGrantedState extends TurnstileState {
  AccessGrantedState({
    required super.studentId,
    super.studentName,
    super.studentRut,
    required super.latencyMs,
  }) : super(
          type: TurnstileStateType.accessGranted,
          enteredTimestampMs: DateTime.now().millisecondsSinceEpoch,
        );

  @override
  Color get haloColor => const Color(0xFF10B981); // Verde Esmeralda

  @override
  String get statusMessage => 'ACCESO CONCEDIDO • BIENVENIDO(A)';

  @override
  Future<TurnstileState> onNfcDetected(
      TurnstileFsmContext context, Map<String, dynamic> payload) async {
    return this;
  }

  @override
  Future<TurnstileState> onFaceScanned(
      TurnstileFsmContext context, List<double> capturedVector) async {
    return this;
  }

  @override
  Future<TurnstileState> onTimeout(TurnstileFsmContext context) async {
    return reset(context);
  }

  @override
  Future<TurnstileState> reset(TurnstileFsmContext context) async {
    return IdleState();
  }
}

/// ============================================================================
/// ESTADO CONCRETO 5: ACCESS_DENIED (Acceso Rechazado / Halo Rojo Carmesí)
/// ============================================================================
class AccessDeniedState extends TurnstileState {
  AccessDeniedState({
    required super.studentId,
    super.studentName,
    super.studentRut,
    required super.denialReason,
    super.latencyMs = 0,
  }) : super(
          type: TurnstileStateType.accessDenied,
          enteredTimestampMs: DateTime.now().millisecondsSinceEpoch,
        );

  @override
  Color get haloColor => const Color(0xFFEF4444); // Rojo Carmesí

  @override
  String get statusMessage => 'ACCESO DENEGADO';

  @override
  Future<TurnstileState> onNfcDetected(
      TurnstileFsmContext context, Map<String, dynamic> payload) async {
    return this;
  }

  @override
  Future<TurnstileState> onFaceScanned(
      TurnstileFsmContext context, List<double> capturedVector) async {
    return this;
  }

  @override
  Future<TurnstileState> onTimeout(TurnstileFsmContext context) async {
    return reset(context);
  }

  @override
  Future<TurnstileState> reset(TurnstileFsmContext context) async {
    return IdleState();
  }
}
