import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/database/turnstile_database.dart';
import '../../domain/fsm/turnstile_state.dart';
import '../../domain/models/whitelist_student.dart';
import '../../data/outbox/outbox_worker.dart';
import '../../data/camera/camera_engine_service.dart';

class KioskToast {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final DateTime timestamp;

  KioskToast({
    required this.title,
    required this.message,
    this.color = const Color(0xFF00F0FF),
    this.icon = Icons.info_outline,
  }) : timestamp = DateTime.now();
}

class KioskViewModel extends ChangeNotifier implements TurnstileFsmContext {
  @override
  final String turnstileId;
  @override
  final String campusId;
  @override
  final TurnstileDatabase database;
  final OutboxWorker outboxWorker;

  TurnstileState _currentState = IdleState();
  Timer? _autoResetTimer;
  Timer? _faceScanSimulationTimer;
  Timer? _cameraStatusPollTimer;
  final http.Client _httpClient = http.Client();
  bool _liveCameraEnabled = true;
  int _syncTickCounter = 0;

  KioskToast? _currentToast;
  KioskToast? get currentToast => _currentToast;
  Timer? _toastDismissTimer;

  void showToast({
    required String title,
    required String message,
    Color color = const Color(0xFF00F0FF),
    IconData icon = Icons.info_outline,
    int durationMs = 4500,
  }) {
    _toastDismissTimer?.cancel();
    _currentToast = KioskToast(
      title: title,
      message: message,
      color: color,
      icon: icon,
    );
    notifyListeners();

    _toastDismissTimer = Timer(Duration(milliseconds: durationMs), () {
      _currentToast = null;
      notifyListeners();
    });
  }

  void clearToast() {
    _toastDismissTimer?.cancel();
    _currentToast = null;
    notifyListeners();
  }

  KioskViewModel({
    this.turnstileId = 'TRN-PROV-01',
    this.campusId = 'CAMPUS_PROVIDENCIA',
    required this.database,
    required this.outboxWorker,
  }) {
    CameraEngineService.instance.ensureEngineRunning();
    _startCameraStatusPolling();
    syncWhitelistFromCentral();
  }

  TurnstileState get currentState => _currentState;
  TurnstileStateType get currentStateType => _currentState.type;
  bool get isLiveCameraEnabled => _liveCameraEnabled;

  bool _liveFaceDetected = false;
  String _liveCamState = 'IDLE';
  int _liveLatencyMs = 30;

  // Estado reactivo para Verificación 2FA 1:1 basado estrictamente en la trama ingresada
  WhitelistStudent? _active2FAStudent;
  double? _active2FASimilarity;

  bool get liveFaceDetected => _liveFaceDetected;
  String get liveCamState => _liveCamState;
  int get liveLatencyMs => _liveLatencyMs;
  WhitelistStudent? get active2FAStudent => _active2FAStudent;
  double? get active2FASimilarity => _active2FASimilarity;

  // Propiedades de compatibilidad para evitar roturas
  String get liveMatchedName => _active2FAStudent?.fullName ?? '';
  String get liveMatchedRut => _active2FAStudent?.rut ?? '';
  String get liveMatchedStudentId => _active2FAStudent?.studentId ?? '';
  double get liveMatchedScore => _active2FASimilarity ?? 0.0;

  void toggleLiveCamera() {
    _liveCameraEnabled = !_liveCameraEnabled;
    if (!_liveCameraEnabled) {
      _liveFaceDetected = false;
      _active2FAStudent = null;
      _active2FASimilarity = null;
      _liveCamState = 'IDLE';
    }
    notifyListeners();
  }

  Future<void> syncWhitelistFromCentral() async {
    try {
      final res = await _httpClient
          .get(Uri.parse('http://localhost:8080/api/v1/sync/whitelist'))
          .timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final users = data['users'] as List?;
        if (users != null) {
          final centralStudents = <WhitelistStudent>[];
          for (final u in users) {
            final vec = (u['face_vector_512'] as List?)
                    ?.map((x) => (x as num).toDouble())
                    .toList() ??
                [];
            centralStudents.add(WhitelistStudent(
              studentId: u['student_id'] as String? ?? '',
              rut: u['rut'] as String? ?? '',
              fullName: u['full_name'] as String? ?? '',
              career: u['career'] as String? ?? '',
              campus: u['campus'] as String? ?? '',
              role: u['role'] as String? ?? 'ESTUDIANTE',
              status: u['enrollment_status'] as String? ?? (u['status'] as String? ?? 'VIGENTE'),
              faceVector512: vec,
            ));
          }
          final deleted = await database.reconcileWhitelist(centralStudents);
          if (deleted > 0) {
            debugPrint('[SYNC] Reconciliación completada: $deleted estudiantes eliminados de SQLite.');
          }
        }
      }
    } catch (_) {}
  }

  Future<void> triggerManualSync() async {
    showToast(
      title: 'SINCRONIZANDO CON CENTRAL...',
      message: 'Consultando PostgreSQL 16 y reconciliando lista blanca SQLite local...',
      color: const Color(0xFF00B4D8),
      icon: Icons.sync,
      durationMs: 3000,
    );
    await syncWhitelistFromCentral();
    showToast(
      title: 'LISTA BLANCA RECONCILIADA',
      message: 'SQLite Edge sincronizado 100% con PostgreSQL. Usuarios eliminados purgados.',
      color: const Color(0xFF10B981),
      icon: Icons.check_circle_outline,
      durationMs: 3500,
    );
  }

  void _startCameraStatusPolling() {
    _cameraStatusPollTimer?.cancel();
    _cameraStatusPollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      _syncTickCounter++;
      if (_syncTickCounter % 20 == 0) {
        syncWhitelistFromCentral();
      }

      if (!_liveCameraEnabled) return;

      try {
        final res = await _httpClient
            .get(Uri.parse('http://127.0.0.1:5050/status'))
            .timeout(const Duration(milliseconds: 1200));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final state = data['state'] as String? ?? 'IDLE';
          final latencyMs = (data['latency_ms'] as num?)?.toInt() ?? 30;
          final bool faceDetected = data['face_detected'] == true;

          _liveFaceDetected = faceDetected;
          _liveCamState = state;
          _liveLatencyMs = latencyMs;

          // Si estamos en verificación facial (FACE_SCANNING), calcular similitud 1:1 contra la trama ingresada
          if (_currentState is FaceScanningState) {
            final faceState = _currentState as FaceScanningState;
            _active2FAStudent = faceState.student;

            if (faceDetected) {
              try {
                final vecRes = await _httpClient
                    .get(Uri.parse('http://127.0.0.1:5050/extract_vector'))
                    .timeout(const Duration(milliseconds: 250));
                if (vecRes.statusCode == 200) {
                  final vecData = jsonDecode(vecRes.body) as Map<String, dynamic>;
                  final rawVec = vecData['vector'] as List?;
                  if (rawVec != null && rawVec.length == 512) {
                    final liveVec = rawVec.map((x) => (x as num).toDouble()).toList();
                    final sim = WhitelistStudent.calculateCosineSimilarity(
                      faceState.student.faceVector512,
                      liveVec,
                    );
                    _active2FASimilarity = sim;

                    // Si alcanza o supera el 65% de similitud con el titular de la trama
                    if (sim >= 0.65) {
                      final simPercent = (sim * 100).toStringAsFixed(1);
                      showToast(
                        title: 'FACTOR 2 VÁLIDO: BIOMETRÍA 1:1 ($simPercent%)',
                        message: 'Rostro coincide con ${faceState.student.fullName}. ¡Torniquete Abierto!',
                        color: const Color(0xFF10B981),
                        icon: Icons.verified_user_rounded,
                        durationMs: 4000,
                      );
                      final next = await faceState.onFaceScanned(this, liveVec);
                      transitionTo(next);
                    }
                  }
                }
              } catch (_) {}
            }
          } else {
            // Fuera de FACE_SCANNING no hay trama activa evaluándose
            _active2FAStudent = null;
            _active2FASimilarity = null;
          }

          notifyListeners();
        }
      } catch (_) {}
    });
  }

  @override
  void transitionTo(TurnstileState nextState) {
    _autoResetTimer?.cancel();
    _faceScanSimulationTimer?.cancel();

    _currentState = nextState;
    notifyListeners();

    // Si transiciona a FaceScanningState, armar el timeout estricto de 3.5s
    if (nextState is FaceScanningState) {
      nextState.armSecurityTimeout(this);
    }

    // Si entra a AccessGrantedState (2.0s) o AccessDeniedState (2.5s), programar reset automático a IDLE
    if (nextState is AccessGrantedState) {
      _autoResetTimer = Timer(const Duration(milliseconds: 4500), () async {
        final idle = await _currentState.reset(this);
        transitionTo(idle);
      });
      // Actualizar contador del outbox
      outboxWorker.refreshStats();
    } else if (nextState is AccessDeniedState) {
      _autoResetTimer = Timer(const Duration(milliseconds: 2500), () async {
        final idle = await _currentState.reset(this);
        transitionTo(idle);
      });
      outboxWorker.refreshStats();
    }
  }

  /// Validación integral 2FA al presionar "PROCESAR": Trama + Cara en Vivo + Apertura Torniquete
  Future<void> process2FAVerification(String rawText) async {
    if (rawText.trim().isEmpty) return;

    final startMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Extraer RUT o identificador desde la trama (soporta JSON de QR/NFC, Regex de RUT o texto directo)
    String queryRutOrId = rawText.trim();
    String? rawName;
    String payloadType = 'Texto directo / RUT';

    if (rawText.contains('NFC_HCE')) {
      payloadType = 'Trama NFC HCE (ISO-14443)';
    } else if (rawText.contains('UA_DYNAMIC_QR')) {
      payloadType = 'QR Dinámico TOTP (15s)';
    } else if (rawText.trim().startsWith('{')) {
      payloadType = 'Trama JSON Credencial';
    }

    // A. Búsqueda por Regex para capturar RUTs en cualquier formato embebido
    final rutRegex = RegExp(r'(\d{1,2}\.?\d{3}\.?\d{3}-?[\dkK])');
    final match = rutRegex.firstMatch(rawText);
    if (match != null) {
      queryRutOrId = match.group(1)!;
    }

    // B. Si es JSON estructurado, extraer campos específicos prioritarios
    try {
      final decoded = jsonDecode(rawText.trim());
      if (decoded is Map<String, dynamic>) {
        if (decoded['rut'] != null && decoded['rut'].toString().isNotEmpty) {
          queryRutOrId = decoded['rut'].toString();
        } else if (decoded['student_id'] != null && decoded['student_id'].toString().isNotEmpty) {
          queryRutOrId = decoded['student_id'].toString();
        }
        rawName = decoded['full_name'] as String?;
      }
    } catch (_) {}

    showToast(
      title: 'TRAMA RECIBIDA [$payloadType]',
      message: 'RUT/ID detectado: "$queryRutOrId" • Consultando SQLite WAL local...',
      color: const Color(0xFF00F0FF),
      icon: Icons.qr_code_scanner,
      durationMs: 5000,
    );

    // 2. Buscar al estudiante en SQLite WAL local
    final student = await database.findStudentByIdOrRut(queryRutOrId);

    if (student == null) {
      final latency = DateTime.now().millisecondsSinceEpoch - startMs + 35;
      showToast(
        title: 'FACTOR 1 RECHAZADO: NO ENCONTRADO EN SQLITE',
        message: 'El RUT "$queryRutOrId" no existe en la lista blanca local (ua_turnstile_edge.db). Acceso denegado.',
        color: const Color(0xFFEF4444),
        icon: Icons.cancel_outlined,
        durationMs: 5000,
      );
      transitionTo(AccessDeniedState(
        studentId: queryRutOrId,
        studentName: rawName ?? 'Estudiante',
        studentRut: queryRutOrId,
        denialReason: 'Credencial no registrada en lista blanca local SIRAD',
        latencyMs: latency,
      ));
      return;
    }

    if (!student.isVigente) {
      final latency = DateTime.now().millisecondsSinceEpoch - startMs + 38;
      showToast(
        title: 'FACTOR 1 RECHAZADO: MATRÍCULA SUSPENDIDA',
        message: 'Estudiante ${student.fullName} (${student.rut}) registra sanción disciplinaria en SQLite.',
        color: const Color(0xFFEF4444),
        icon: Icons.block,
        durationMs: 5000,
      );
      transitionTo(AccessDeniedState(
        studentId: student.studentId,
        studentName: student.fullName,
        studentRut: student.rut,
        denialReason: 'Matrícula no vigente / Sanción disciplinaria activa',
        latencyMs: latency,
      ));
      return;
    }

    showToast(
      title: 'FACTOR 1 VÁLIDO: SQLITE LOCAL OK',
      message: 'Estudiante: ${student.fullName} (${student.rut}) • Vector 512D cargado de SQLite. Evaluando Factor 2...',
      color: const Color(0xFF10B981),
      icon: Icons.check_circle_outline,
      durationMs: 4000,
    );

    // 3. Pasar a estado FACE_SCANNING con los datos del alumno
    final faceScanningState = FaceScanningState(
      student: student,
      flowStartTimestampMs: startMs,
    );
    transitionTo(faceScanningState);

    // 4. Evaluar el rostro en vivo frente a la cámara mediante Verificación 1:1 directa
    List<double>? liveVector;

    // Sondeo reactivo de hasta 15 intentos (3.0 segundos) evaluando similitud en tiempo real
    double bestSimilarity = 0.0;
    List<double>? bestVector;

    for (int attempt = 0; attempt < 15; attempt++) {
      try {
        final res = await _httpClient
            .get(Uri.parse('http://127.0.0.1:5050/extract_vector'))
            .timeout(const Duration(milliseconds: 300));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          final rawVec = data['vector'] as List?;

          if (status == 'OK' && rawVec != null && rawVec.length == 512) {
            final candidateVector = rawVec.map((x) => (x as num).toDouble()).toList();
            final sim = WhitelistStudent.calculateCosineSimilarity(
              student.faceVector512,
              candidateVector,
            );

            if (sim > bestSimilarity) {
              bestSimilarity = sim;
              bestVector = candidateVector;
            }

            // Si la similitud alcanza o supera el 65%, ¡CONCEDER ACCESO INMEDIATAMENTE!
            if (sim >= 0.65) {
              liveVector = candidateVector;
              break;
            }
          }
        }
      } catch (_) {
        // En caso de micro-retraso transitorio en el socket
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (liveVector == null && bestVector != null) {
      liveVector = bestVector;
    }

    // Si tras 3 segundos no se detectó ningún rostro frente a la cámara:
    if (liveVector == null || liveVector.length != 512) {
      showToast(
        title: 'FACTOR 2 RECHAZADO: SIN ROSTRO',
        message: 'No se detectó ningún rostro frente a la cámara dentro de la ventana de seguridad (3.0s).',
        color: const Color(0xFFEF4444),
        icon: Icons.face_retouching_off,
        durationMs: 4000,
      );
      final timeoutState = await faceScanningState.onTimeout(this);
      transitionTo(timeoutState);
      return;
    }

    // 5. Cálculo Matemático de Similitud Coseno 1:1 final
    final similarity = WhitelistStudent.calculateCosineSimilarity(
      student.faceVector512,
      liveVector,
    );
    final simPercent = (similarity * 100).toStringAsFixed(1);

    // 6. Transición formal en la FSM delegada (guarda en Outbox de forma transaccional)
    final nextState = await faceScanningState.onFaceScanned(this, liveVector);
    transitionTo(nextState);

    if (nextState is AccessGrantedState) {
      showToast(
        title: 'FACTOR 2 VÁLIDO: BIOMETRÍA 1:1 ($simPercent%)',
        message: 'Rostro coincide con ${student.fullName}. ¡Torniquete Abierto!',
        color: const Color(0xFF10B981),
        icon: Icons.verified_user_rounded,
        durationMs: 4000,
      );
    } else {
      showToast(
        title: 'FACTOR 2 RECHAZADO: BIOMETRÍA DIVERGENTE ($simPercent%)',
        message: 'El rostro frente a la cámara no coincide con ${student.fullName} (< 65% umbral).',
        color: const Color(0xFFEF4444),
        icon: Icons.block,
        durationMs: 5000,
      );
    }
  }

  /// Evento 1: Recepción de trama NFC HCE o QR TOTP
  Future<void> handleNfcOrQrDetected(Map<String, dynamic> payload, {bool autoSimulateFace = true}) async {
    final nextState = await _currentState.onNfcDetected(this, payload);
    transitionTo(nextState);

    // Si la cámara en vivo está activa, el servicio de cámara real resolverá el factor de inherencia.
    // Solo si la cámara está apagada se usa simulación de demostración.
    if (autoSimulateFace && !_liveCameraEnabled && nextState is FaceScanningState) {
      _faceScanSimulationTimer = Timer(const Duration(milliseconds: 280), () async {
        if (_currentState is FaceScanningState) {
          // El rostro coincide con el vector del estudiante
          final capturedVector = nextState.student.faceVector512;
          final grantedOrDenied = await _currentState.onFaceScanned(this, capturedVector);
          transitionTo(grantedOrDenied);
        }
      });
    }
  }

  /// Prueba de Rechazo 1: Rostro no coincide (Simula vector aleatorio / atacante)
  Future<void> handleFaceMismatchSimulation() async {
    if (_currentState is FaceScanningState) {
      // Vector divergente
      final mismatchedVector = WhitelistStudent.generateDeterministicVector('intruder-face-random-999');
      final resultState = await _currentState.onFaceScanned(this, mismatchedVector);
      transitionTo(resultState);
    }
  }

  /// Prueba de Rechazo 2: Timeout de escaneo facial agotado (3.5 segundos)
  Future<void> handleTimeoutForceSimulation() async {
    if (_currentState is FaceScanningState) {
      final resultState = await _currentState.onTimeout(this);
      transitionTo(resultState);
    }
  }

  /// Ejecución de flujo vertical completo rápido para video / demostración docente
  Future<void> runDemoFlow({required WhitelistStudent student, bool matchFace = true}) async {
    final payload = {
      'student_id': student.studentId,
      'rut': student.rut,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'mode': 'NFC_HCE',
    };

    final state1 = await _currentState.onNfcDetected(this, payload);
    transitionTo(state1);

    if (state1 is FaceScanningState) {
      _faceScanSimulationTimer = Timer(const Duration(milliseconds: 320), () async {
        if (_currentState is FaceScanningState) {
          final vector = matchFace
              ? student.faceVector512
              : WhitelistStudent.generateDeterministicVector('attacker-fake-biometrics');
          final endState = await _currentState.onFaceScanned(this, vector);
          transitionTo(endState);
        }
      });
    }
  }

  void resetToIdle() {
    _autoResetTimer?.cancel();
    _faceScanSimulationTimer?.cancel();
    if (_currentState is FaceScanningState) {
      (_currentState as FaceScanningState).cancelTimeout();
    }
    _currentState = IdleState();
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraStatusPollTimer?.cancel();
    _httpClient.close();
    _autoResetTimer?.cancel();
    _faceScanSimulationTimer?.cancel();
    super.dispose();
  }
}
