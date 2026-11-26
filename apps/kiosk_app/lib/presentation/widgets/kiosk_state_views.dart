import 'package:flutter/material.dart';
import '../../domain/fsm/turnstile_state.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';
import 'kiosk_telemetry_panel.dart';
import 'live_camera_widget.dart';
import 'turnstile_barrier_widget.dart';

/// Renders the active FSM turnstile state in a bright, balanced, wide-screen-aware layout.
class KioskStateCenter extends StatelessWidget {
  final TurnstileState state;
  final KioskViewModel kioskVm;

  const KioskStateCenter({
    super.key,
    required this.state,
    required this.kioskVm,
  });

  @override
  Widget build(BuildContext context) {
    switch (state.type) {
      case TurnstileStateType.idle:
        return _buildIdleVisual(kioskVm);
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

  Widget _buildIdleVisual(KioskViewModel kioskVm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 720;

        if (!kioskVm.isLiveCameraEnabled) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCameraDisabledCard(kioskVm),
                const SizedBox(height: 16),
                TurnstileBarrierWidget(isOpen: false, isCompact: !isWide),
              ],
            ),
          );
        }

        if (isWide) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LiveCameraWidget(
                    width: 360,
                    height: 360,
                    haloColor: kioskVm.liveFaceDetected && !kioskVm.liveIsRealFace
                        ? KioskTheme.signalDenied
                        : KioskTheme.signalIdle,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: KioskTelemetryPanel(kioskVm: kioskVm)),
                        const SizedBox(height: 16),
                        const TurnstileBarrierWidget(isOpen: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: LiveCameraWidget(
                  width: 280,
                  height: 240,
                  haloColor: kioskVm.liveFaceDetected && !kioskVm.liveIsRealFace
                      ? KioskTheme.signalDenied
                      : KioskTheme.signalIdle,
                ),
              ),
              const SizedBox(height: 16),
              KioskTelemetryPanel(kioskVm: kioskVm),
              const SizedBox(height: 16),
              const TurnstileBarrierWidget(isOpen: false, isCompact: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraDisabledCard(KioskViewModel kioskVm) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: KioskTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KioskTheme.border),
        boxShadow: KioskTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: KioskTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KioskTheme.border),
            ),
            child: const Icon(
              Icons.videocam_off_rounded,
              size: 28,
              color: KioskTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'VISOR DE CÁMARA EN PAUSA',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: KioskTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'La webcam física fue liberada en :5050. Puede reactivarla en cualquier momento para validar 2FA.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: KioskTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: kioskVm.toggleLiveCamera,
            icon: const Icon(Icons.videocam_rounded, size: 18),
            label: const Text('ACTIVAR CÁMARA EN VIVO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: KioskTheme.signalGranted,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNfcReadingVisual(TurnstileState state) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: KioskTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KioskTheme.signalAmber.withValues(alpha: 0.55), width: 1.5),
          boxShadow: KioskTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: KioskTheme.signalAmberBg,
                shape: BoxShape.circle,
                border: Border.all(color: KioskTheme.signalAmber, width: 2),
              ),
              child: const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: KioskTheme.signalAmber,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: KioskTheme.signalAmberText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Validando credencial en SQLite WAL: ${state.studentId ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontFamilyFallback: KioskTheme.monoFallback,
                color: KioskTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceScanningVisual(FaceScanningState state, KioskViewModel kioskVm) {
    final double? liveSim = kioskVm.active2FASimilarity;
    final bool isSpoof = kioskVm.liveFaceDetected && !kioskVm.liveIsRealFace;
    final bool isPassing = !isSpoof && liveSim != null && liveSim >= 0.65;
    final Color accentColor = isSpoof
        ? KioskTheme.signalDenied
        : (isPassing ? KioskTheme.signalGranted : KioskTheme.signalScanning);

    final verificationCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KioskTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.45), width: 1.5),
        boxShadow: KioskTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSpoof ? KioskTheme.signalDeniedBg : KioskTheme.signalScanningBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              isSpoof ? 'ALERTA ANTI-SPOOFING ACTIVA' : 'VERIFICACIÓN BIOMÉTRICA 1:1',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isSpoof ? KioskTheme.signalDeniedText : KioskTheme.signalScanningDark,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            state.student.fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: KioskTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.student.career} · RUT ${state.student.rut}',
            style: const TextStyle(fontSize: 13.5, color: KioskTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSpoof
                  ? KioskTheme.signalDeniedBg
                  : (isPassing ? KioskTheme.signalGrantedBg : KioskTheme.surfaceSubtle),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                if (isSpoof)
                  const Icon(Icons.gpp_bad_rounded, size: 20, color: KioskTheme.signalDeniedText)
                else if (isPassing)
                  const Icon(Icons.verified_user_rounded, size: 20, color: KioskTheme.signalGrantedText)
                else
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: KioskTheme.signalScanning,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isSpoof
                        ? 'Foto o pantalla detectada. Presente un rostro vivo.'
                        : (liveSim != null
                            ? 'Similitud: ${(liveSim * 100).toStringAsFixed(1)}% (Umbral 65%)'
                            : 'Mire a la cámara para validar prueba de vida y vector 512D...'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isSpoof
                          ? KioskTheme.signalDeniedText
                          : (isPassing
                              ? KioskTheme.signalGrantedText
                              : KioskTheme.signalScanningDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        if (isWide) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LiveCameraWidget(
                  width: 310,
                  height: 280,
                  haloColor: accentColor,
                ),
                const SizedBox(width: 24),
                Expanded(child: verificationCard),
              ],
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveCameraWidget(width: 260, height: 230, haloColor: accentColor),
              const SizedBox(height: 16),
              verificationCard,
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccessGrantedVisual(AccessGrantedState state) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TurnstileBarrierWidget(
            isOpen: true,
            studentName: state.studentName ?? state.studentId ?? 'Estudiante',
            studentRut: state.studentRut ?? '',
            latencyMs: state.latencyMs,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: KioskTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KioskTheme.border),
              boxShadow: KioskTheme.cardShadow,
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 19, color: KioskTheme.signalGrantedText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Validado en ${state.latencyMs} ms · SLA <= 500 ms · Persistido en SQLite WAL Outbox',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: KioskTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedVisual(AccessDeniedState state) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        decoration: BoxDecoration(
          color: KioskTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KioskTheme.signalDenied, width: 2),
          boxShadow: KioskTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              color: KioskTheme.signalDenied,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_rounded, size: 30, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'ACCESO DENEGADO',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: KioskTheme.signalDeniedBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: KioskTheme.signalDenied.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      state.denialReason ?? 'Credencial inválida o biometría no coincidente',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KioskTheme.signalDeniedText,
                      ),
                    ),
                  ),
                  if (state.latencyMs > 0) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Tiempo de evaluación: ${state.latencyMs} ms · Evento auditado en Outbox',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontFamilyFallback: KioskTheme.monoFallback,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: KioskTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
