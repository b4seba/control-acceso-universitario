import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';
import '../widgets/live_camera_widget.dart';
import '../widgets/turnstile_barrier_widget.dart';
import '../../data/outbox/outbox_worker.dart';
import '../../domain/fsm/turnstile_state.dart';
import 'guard_panel_view.dart';

class KioskMainView extends StatefulWidget {
  const KioskMainView({super.key});

  @override
  State<KioskMainView> createState() => _KioskMainViewState();
}

class _KioskMainViewState extends State<KioskMainView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final _qrInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _qrInputController.dispose();
    super.dispose();
  }

  void _processPastedPayload(String rawText) {
    if (rawText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingrese o pegue la trama de credencial (RUT o JSON de la app).'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    context.read<KioskViewModel>().process2FAVerification(rawText.trim());
  }

  @override
  Widget build(BuildContext context) {
    final kioskVm = context.watch<KioskViewModel>();
    final outboxWorker = context.watch<OutboxWorker>();
    final currentState = kioskVm.currentState;
    final haloColor = currentState.haloColor;

    return Scaffold(
      backgroundColor: KioskTheme.industrialBlack,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final double glowSpread = currentState.type == TurnstileStateType.accessGranted
                ? 10.0 + (12.0 * _pulseController.value)
                : 6.0;

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: haloColor.withValues(
                    alpha: currentState.type == TurnstileStateType.accessGranted
                        ? 0.7 + (0.3 * _pulseController.value)
                        : 0.85,
                  ),
                  width: currentState.type == TurnstileStateType.idle ? 4 : 8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: haloColor.withValues(
                      alpha: currentState.type == TurnstileStateType.accessGranted
                          ? 0.4 + (0.3 * _pulseController.value)
                          : 0.25,
                    ),
                    blurRadius: 30,
                    spreadRadius: glowSpread,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabecera Industrial del Kiosko Edge
              _buildIndustrialHeader(context, kioskVm, outboxWorker),

              // 2. Visor Central y Halos Cromáticos de la FSM
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: _buildFsmStateCenter(context, currentState, kioskVm),
                    ),
                  ),
                ),
              ),

              // 3. Barra Inferior: Diagnóstico, Modo Isla y Disparadores Demo
              _buildBottomActionToolbar(context, kioskVm, outboxWorker),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndustrialHeader(
      BuildContext context, KioskViewModel kioskVm, OutboxWorker outboxWorker) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: KioskTheme.industrialSurface,
        border: Border(bottom: BorderSide(color: KioskTheme.industrialBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: KioskTheme.haloIdle.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.meeting_room_rounded,
                    color: KioskTheme.haloIdle, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'UNIVERSIDAD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: KioskTheme.textWhite,
                    ),
                  ),
                  Text(
                    '${kioskVm.campusId} • NODO: ${kioskVm.turnstileId} (EDGE 7")',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: KioskTheme.haloFaceScanning,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Indicador de Modo Isla
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: outboxWorker.isIslandMode
                      ? KioskTheme.haloDenied.withValues(alpha: 0.2)
                      : KioskTheme.haloGranted.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: outboxWorker.isIslandMode
                        ? KioskTheme.haloDenied
                        : KioskTheme.haloGranted,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      outboxWorker.isIslandMode ? Icons.cloud_off : Icons.cloud_done,
                      size: 14,
                      color: outboxWorker.isIslandMode
                          ? KioskTheme.haloDenied
                          : KioskTheme.haloGranted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      outboxWorker.isIslandMode ? 'MODO ISLA (72h)' : 'CLOUD CONECTADO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: outboxWorker.isIslandMode
                            ? KioskTheme.haloDenied
                            : KioskTheme.haloGranted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Contador de Outbox PENDING
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: KioskTheme.haloNfcReading.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KioskTheme.haloNfcReading),
                ),
                child: Text(
                  'OUTBOX: ${outboxWorker.pendingCount} PENDING',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: KioskTheme.haloNfcReading,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Botón Panel Guardia
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_rounded,
                    color: KioskTheme.textWhite, size: 24),
                tooltip: 'Panel de Supervisor / Guardia',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardPanelView()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFsmStateCenter(
      BuildContext context, TurnstileState state, KioskViewModel kioskVm) {
    switch (state.type) {
      case TurnstileStateType.idle:
        return _buildIdleVisual(state, kioskVm);
      case TurnstileStateType.nfcReading:
        return _buildNfcReadingVisual(state);
      case TurnstileStateType.faceScanning:
        return _buildFaceScanningVisual(state as FaceScanningState, kioskVm);
      case TurnstileStateType.accessGranted:
        return _buildAccessGrantedVisual(state as AccessGrantedState);
      case TurnstileStateType.accessDenied:
        return _buildAccessDeniedVisual(state as AccessDeniedState);
    }
  }

  Widget _buildIdleVisual(TurnstileState state, KioskViewModel kioskVm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kioskVm.isLiveCameraEnabled)
          const LiveCameraWidget(
            width: 260,
            height: 260,
            haloColor: KioskTheme.haloIdle,
          )
        else
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: KioskTheme.haloIdle.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: KioskTheme.haloIdle, width: 3),
              boxShadow: [
                BoxShadow(
                  color: KioskTheme.haloIdle.withValues(alpha: 0.3),
                  blurRadius: 30,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.nfc_rounded, size: 65, color: KioskTheme.haloIdle),
            ),
          ),
        const SizedBox(height: 16),

        // Bloque de Estado del Torniquete (CERRADO)
        const TurnstileBarrierWidget(
          isOpen: false,
          isCompact: false,
        ),

        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: kioskVm.toggleLiveCamera,
          icon: Icon(
            kioskVm.isLiveCameraEnabled ? Icons.nfc_rounded : Icons.videocam_rounded,
            size: 16,
            color: KioskTheme.haloIdle,
          ),
          label: Text(
            kioskVm.isLiveCameraEnabled ? 'Modo Solo NFC / QR' : 'Activar Sensor Facial',
            style: const TextStyle(
              fontSize: 11,
              color: KioskTheme.haloIdle,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: KioskTheme.haloIdle.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildNfcReadingVisual(TurnstileState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: KioskTheme.haloNfcReading.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: KioskTheme.haloNfcReading, width: 3),
          ),
          child: const Center(
            child: SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: KioskTheme.haloNfcReading,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          state.statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: KioskTheme.haloNfcReading,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Validando credencial en lista blanca SQLite WAL: ${state.studentId}',
          style: const TextStyle(fontSize: 13, color: KioskTheme.textGrey),
        ),
      ],
    );
  }

  Widget _buildFaceScanningVisual(
      FaceScanningState state, KioskViewModel kioskVm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visor de Cámara Real con Retícula Biométrica de 512 Dimensiones
        const LiveCameraWidget(
          width: 290,
          height: 290,
          haloColor: KioskTheme.haloFaceScanning,
        ),
        const SizedBox(height: 18),
        Text(
          state.student.fullName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: KioskTheme.textWhite,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${state.student.career} • RUT: ${state.student.rut}',
          style: const TextStyle(fontSize: 13, color: KioskTheme.haloFaceScanning),
        ),
        const SizedBox(height: 8),
        const Text(
          'Comparando vector matemático contra base de datos local SQLite WAL (Zero-Trust)',
          style: TextStyle(fontSize: 11, color: KioskTheme.textGrey),
        ),
      ],
    );
  }

  Widget _buildAccessGrantedVisual(AccessGrantedState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bloque de Estado del Torniquete (ABIERTO)
        TurnstileBarrierWidget(
          isOpen: true,
          studentName: state.studentName ?? state.studentId ?? 'Estudiante',
          studentRut: state.studentRut ?? '21.460.709-3',
          latencyMs: state.latencyMs,
        ),
        const SizedBox(height: 16),

        // Cronómetro de Latencia Visible (SLA <= 500 ms)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: KioskTheme.industrialSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: KioskTheme.haloGranted, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_rounded, size: 18, color: KioskTheme.haloGranted),
              const SizedBox(width: 8),
              Text(
                'VALIDADO EN ${state.latencyMs} ms | SLA <= 500 ms (CUMPLIDO)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: KioskTheme.haloGranted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Evento persistido en SQLite WAL (PENDING) • Sincronización Transactional Outbox',
          style: TextStyle(fontSize: 11, color: KioskTheme.textGrey),
        ),
      ],
    );
  }

  Widget _buildAccessDeniedVisual(AccessDeniedState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            color: KioskTheme.haloDenied.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: KioskTheme.haloDenied, width: 4),
            boxShadow: [
              BoxShadow(
                color: KioskTheme.haloDenied.withValues(alpha: 0.5),
                blurRadius: 30,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.cancel_rounded, size: 76, color: KioskTheme.haloDenied),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ACCESO DENEGADO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: KioskTheme.haloDenied,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: KioskTheme.haloDenied.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KioskTheme.haloDenied),
          ),
          child: Text(
            state.denialReason ?? 'Credencial inválida o biometría no coincidente',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: KioskTheme.haloDenied,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (state.latencyMs > 0)
          Text(
            'Tiempo de respuesta: ${state.latencyMs} ms',
            style: const TextStyle(fontSize: 11, color: KioskTheme.textGrey),
          ),
      ],
    );
  }

  Widget _buildBottomActionToolbar(
      BuildContext context, KioskViewModel kioskVm, OutboxWorker outboxWorker) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: KioskTheme.industrialSurface,
        border: Border(top: BorderSide(color: KioskTheme.industrialBorder)),
      ),
      child: Column(
        children: [
          // Fila 1: Pegar Payload o Trama de la App Estudiante
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _qrInputController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Pegue aquí la trama copiada desde la App Móvil (NFC, QR TOTP o RUT)...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: const Icon(Icons.qr_code_scanner, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 16),
                        tooltip: 'Pegar desde portapapeles y procesar',
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null && data!.text!.trim().isNotEmpty) {
                            final text = data.text!.trim();
                            setState(() {
                              _qrInputController.text = text;
                            });
                            _processPastedPayload(text);
                          }
                        },
                      ),
                    ),
                    onChanged: (val) {
                      final trimmed = val.trim();
                      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
                          (trimmed.length >= 10 && RegExp(r'\d{1,2}\.?\d{3}\.?\d{3}-?[\dkK]').hasMatch(trimmed))) {
                        _processPastedPayload(trimmed);
                      }
                    },
                    onSubmitted: _processPastedPayload,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KioskTheme.haloGranted,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                onPressed: () => _processPastedPayload(_qrInputController.text),
                label: const Text('PROCESAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Fila 2: Botones de Prueba Rápida para Demostración
          Row(
            children: [
              const Text(
                'Accesos rápidos:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: KioskTheme.textGrey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.verified_user_rounded, size: 14, color: KioskTheme.haloGranted),
                        label: const Text('RUT Sebastián Freire', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setState(() {
                            _qrInputController.text = '21.460.709-3';
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.play_arrow_rounded, size: 14, color: KioskTheme.haloGranted),
                        label: const Text('Procesar Sebastián Freire (2FA OK)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          _qrInputController.text = '21.460.709-3';
                          _processPastedPayload('21.460.709-3');
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.block, size: 14, color: KioskTheme.haloDenied),
                        label: const Text('RUT No Registrado (Denegado)', style: TextStyle(fontSize: 11, color: KioskTheme.haloDenied)),
                        onPressed: () {
                          _qrInputController.text = '99.999.999-9';
                          _processPastedPayload('99.999.999-9');
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.face_retouching_off, size: 14, color: KioskTheme.haloDenied),
                        label: const Text('Rostro Divergente (2FA)', style: TextStyle(fontSize: 11, color: KioskTheme.haloDenied)),
                        onPressed: () {
                          kioskVm.handleNfcOrQrDetected({
                            'student_id': 'ua-stu-2026-001',
                            'rut': '21.460.709-3',
                          }, autoSimulateFace: false);
                          Future.delayed(const Duration(milliseconds: 300), () {
                            kioskVm.handleFaceMismatchSimulation();
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.clear, size: 14, color: KioskTheme.textGrey),
                        label: const Text('Limpiar', style: TextStyle(fontSize: 11, color: KioskTheme.textGrey)),
                        onPressed: () {
                          setState(() {
                            _qrInputController.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.timer_off_rounded, size: 14, color: KioskTheme.haloNfcReading),
                        label: const Text('Timeout 3.5s', style: TextStyle(fontSize: 11, color: KioskTheme.haloNfcReading)),
                        onPressed: () {
                          kioskVm.handleNfcOrQrDetected({
                            'student_id': 'ua-stu-2026-001',
                            'rut': '20.456.789-K',
                          }, autoSimulateFace: false);
                          Future.delayed(const Duration(milliseconds: 300), () {
                            kioskVm.handleTimeoutForceSimulation();
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.restart_alt, size: 14, color: KioskTheme.textWhite),
                        label: const Text('Reset IDLE', style: TextStyle(fontSize: 11)),
                        onPressed: () => kioskVm.resetToIdle(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
