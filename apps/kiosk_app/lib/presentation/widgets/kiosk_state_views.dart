import 'package:flutter/material.dart';
import '../../domain/fsm/turnstile_state.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';
import 'kiosk_telemetry_panel.dart';
import 'live_camera_widget.dart';
import 'turnstile_barrier_widget.dart';

/// Renders the active FSM turnstile state with responsive sizing for 7" and desktop screens.
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
        final bool isWide = constraints.maxWidth >= 580;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kioskVm.isLiveCameraEnabled)
              isWide
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const LiveCameraWidget(
                            width: 240,
                            height: 240,
                            haloColor: KioskTheme.signalIdle,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: KioskTelemetryPanel(kioskVm: kioskVm, height: 240),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LiveCameraWidget(
                          width: 220,
                          height: 220,
                          haloColor: KioskTheme.signalIdle,
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: KioskTelemetryPanel(kioskVm: kioskVm, height: 230),
                        ),
                      ],
                    )
            else
              _buildCameraDisabledCard(kioskVm),

            const SizedBox(height: 16),

            TurnstileBarrierWidget(
              isOpen: false,
              isCompact: !isWide,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCameraDisabledCard(KioskViewModel kioskVm) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: KioskTheme.industrialSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KioskTheme.industrialBorderStrong, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: KioskTheme.industrialCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KioskTheme.industrialBorderStrong),
              ),
              child: const Icon(
                Icons.videocam_off_rounded,
                size: 26,
                color: KioskTheme.textGrey,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'VISOR DE CÁMARA EN PAUSA',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: KioskTheme.textWhite,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'El motor MobileFaceNet permanece listo en :5050. Puede validar por trama o reactivar el visor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: KioskTheme.textGrey, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: kioskVm.toggleLiveCamera,
              icon: const Icon(Icons.videocam_rounded, size: 17),
              label: const Text('ACTIVAR CÁMARA EN VIVO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: KioskTheme.signalGranted,
                foregroundColor: const Color(0xFF090A0D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNfcReadingVisual(TurnstileState state) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: KioskTheme.industrialSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KioskTheme.signalAmber.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
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
                    strokeWidth: 3,
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
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: KioskTheme.signalAmber,
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
                color: KioskTheme.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceScanningVisual(FaceScanningState state, KioskViewModel kioskVm) {
    final double? liveSim = kioskVm.active2FASimilarity;
    final bool isPassing = liveSim != null && liveSim >= 0.65;
    final Color accentColor = isPassing ? KioskTheme.signalGrantedText : KioskTheme.signalScanning;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveCameraWidget(
            width: 264,
            height: 264,
            haloColor: KioskTheme.signalScanning,
          ),
          const SizedBox(height: 16),
          Text(
            state.student.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: KioskTheme.textWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.student.career} · RUT ${state.student.rut}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: KioskTheme.textGrey),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isPassing ? KioskTheme.signalGrantedBg : KioskTheme.industrialSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isPassing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KioskTheme.signalScanning,
                    ),
                  )
                else
                  const Icon(
                    Icons.verified_user_rounded,
                    size: 17,
                    color: KioskTheme.signalGrantedText,
                  ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    liveSim != null
                        ? 'FACTOR 2 (1:1): ${(liveSim * 100).toStringAsFixed(1)}% SIMILITUD (UMBRAL 65%)'
                        : 'FACTOR 2: VERIFICANDO ROSTRO CONTRA VECTOR 512D...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: accentColor,
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

  Widget _buildAccessGrantedVisual(AccessGrantedState state) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: KioskTheme.industrialSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KioskTheme.industrialBorderStrong),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: KioskTheme.signalGrantedText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Validado en ${state.latencyMs} ms · SLA <= 500 ms · Persistido en SQLite WAL Outbox',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: KioskTheme.textWhite,
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
      constraints: const BoxConstraints(maxWidth: 480),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: KioskTheme.signalDeniedBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KioskTheme.signalDenied.withValues(alpha: 0.65), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: KioskTheme.signalDenied.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: KioskTheme.signalDenied, width: 2),
              ),
              child: const Icon(
                Icons.block_rounded,
                size: 36,
                color: KioskTheme.signalDenied,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ACCESO DENEGADO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: KioskTheme.signalDenied,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: KioskTheme.industrialBlack.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KioskTheme.signalDenied.withValues(alpha: 0.35)),
              ),
              child: Text(
                state.denialReason ?? 'Credencial inválida o biometría no coincidente',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: KioskTheme.textWhite,
                ),
              ),
            ),
            if (state.latencyMs > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Tiempo de respuesta: ${state.latencyMs} ms',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontFamilyFallback: KioskTheme.monoFallback,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: KioskTheme.textGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
