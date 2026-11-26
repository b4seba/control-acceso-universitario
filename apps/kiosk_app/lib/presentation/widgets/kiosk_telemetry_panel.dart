import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';

/// Light high-contrast biometric telemetry & Anti-Spoofing sensor status card.
class KioskTelemetryPanel extends StatelessWidget {
  final KioskViewModel kioskVm;
  final double? height;

  const KioskTelemetryPanel({
    super.key,
    required this.kioskVm,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFace = kioskVm.liveFaceDetected;
    final bool isRealFace = kioskVm.liveIsRealFace;
    final bool isSpoof = hasFace && !isRealFace;
    final activeStudent = kioskVm.active2FAStudent;
    final double? sim = kioskVm.active2FASimilarity;
    final bool isMatch = isRealFace && sim != null && sim >= 0.65;

    final Color borderColor = isSpoof
        ? KioskTheme.signalDenied.withValues(alpha: 0.7)
        : isMatch
            ? KioskTheme.signalGranted.withValues(alpha: 0.65)
            : (hasFace
                ? KioskTheme.signalScanning.withValues(alpha: 0.5)
                : KioskTheme.border);

    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KioskTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: KioskTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KioskTheme.brandCrimsonSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 19,
                  color: KioskTheme.brandCrimson,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TELEMETRÍA BIOMÉTRICA 512D',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: KioskTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'YuNet + MobileFaceNet + Anti-Spoofing',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontFamilyFallback: KioskTheme.monoFallback,
                        color: KioskTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSpoof
                      ? KioskTheme.signalDenied
                      : (hasFace ? KioskTheme.signalGranted : KioskTheme.borderStrong),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Face Detection & Anti-Spoofing Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSpoof
                  ? KioskTheme.signalDeniedBg
                  : (hasFace ? KioskTheme.signalGrantedBg : KioskTheme.surfaceSubtle),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSpoof
                    ? KioskTheme.signalDenied.withValues(alpha: 0.4)
                    : (hasFace
                        ? KioskTheme.signalGranted.withValues(alpha: 0.35)
                        : KioskTheme.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSpoof
                      ? Icons.gpp_bad_rounded
                      : (hasFace ? Icons.verified_user_rounded : Icons.face_rounded),
                  size: 18,
                  color: isSpoof
                      ? KioskTheme.signalDeniedText
                      : (hasFace ? KioskTheme.signalGrantedText : KioskTheme.textMuted),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    isSpoof
                        ? 'ANTI-SPOOFING: FOTO / PANTALLA DETECTADA'
                        : (hasFace
                            ? 'ROSTRO VIVO VERIFICADO (${(kioskVm.liveLivenessScore * 100).toStringAsFixed(0)}%)'
                            : 'BUSCANDO ROSTRO EN ENCUADRE...'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSpoof
                          ? KioskTheme.signalDeniedText
                          : (hasFace ? KioskTheme.signalGrantedText : KioskTheme.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Active 2FA Status or Instruction
          if (activeStudent != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMatch ? KioskTheme.signalGrantedBg : KioskTheme.signalScanningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isMatch ? KioskTheme.signalGranted : KioskTheme.signalScanning)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeStudent.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: KioskTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sim != null
                        ? 'Similitud 1:1: ${(sim * 100).toStringAsFixed(1)}% (Umbral 65%)'
                        : 'Contrastando rostro contra vector 512D...',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isMatch
                          ? KioskTheme.signalGrantedText
                          : KioskTheme.signalScanningDark,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: KioskTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KioskTheme.border),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFace ? Icons.qr_code_scanner_rounded : Icons.info_outline_rounded,
                    size: 16,
                    color: hasFace ? KioskTheme.signalScanningDark : KioskTheme.textMuted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      isSpoof
                          ? 'Retire el teléfono o imagen y mire directamente a la cámara.'
                          : hasFace
                              ? 'Rostro listo. Presente su QR dinámico o RUT abajo.'
                              : 'Ubique su rostro frente al visor y presente su credencial.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KioskTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // 4. Camera Release Toggle
          OutlinedButton.icon(
            onPressed: kioskVm.toggleLiveCamera,
            icon: const Icon(Icons.videocam_off_rounded, size: 16, color: KioskTheme.signalDeniedText),
            label: const Text(
              'DESACTIVAR CÁMARA',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: KioskTheme.signalDeniedText,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: KioskTheme.signalDeniedBg,
              side: BorderSide(color: KioskTheme.signalDenied.withValues(alpha: 0.3)),
              minimumSize: const Size.fromHeight(42),
            ),
          ),
        ],
      ),
    );
  }
}
