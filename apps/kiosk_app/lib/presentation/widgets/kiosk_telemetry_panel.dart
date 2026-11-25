import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';

/// Real-time 1:1 facial telemetry and camera control panel paired with LiveCameraWidget.
class KioskTelemetryPanel extends StatelessWidget {
  final KioskViewModel kioskVm;
  final double height;

  const KioskTelemetryPanel({
    super.key,
    required this.kioskVm,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFace = kioskVm.liveFaceDetected;
    final activeStudent = kioskVm.active2FAStudent;
    final double? sim = kioskVm.active2FASimilarity;
    final bool isMatch = sim != null && sim >= 0.65;

    final Color borderColor = isMatch
        ? KioskTheme.signalGranted
        : (hasFace ? KioskTheme.signalScanning.withValues(alpha: 0.7) : KioskTheme.industrialBorderStrong);

    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KioskTheme.industrialSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Header
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: KioskTheme.industrialCard,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: KioskTheme.industrialBorderStrong),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 16,
                  color: hasFace ? KioskTheme.signalScanning : KioskTheme.textGrey,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TELEMETRÍA BIOMÉTRICA 512D',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: KioskTheme.textWhite,
                      ),
                    ),
                    Text(
                      'MobileFaceNet Edge · 127.0.0.1:5050',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontFamilyFallback: KioskTheme.monoFallback,
                        color: KioskTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasFace ? KioskTheme.signalGranted : KioskTheme.textMuted,
                ),
              ),
            ],
          ),

          // 2. Face Detection Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: KioskTheme.industrialCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFace
                    ? KioskTheme.signalScanning.withValues(alpha: 0.45)
                    : KioskTheme.industrialBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasFace ? Icons.face_unlock_rounded : Icons.face_rounded,
                  size: 16,
                  color: hasFace ? KioskTheme.signalScanning : KioskTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasFace ? 'ROSTRO EN ENCUADRE' : 'BUSCANDO ROSTRO...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasFace ? KioskTheme.signalScanning : KioskTheme.textGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Active 2FA 1:1 Verification Indicator
          if (activeStudent != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMatch ? KioskTheme.signalGrantedBg : KioskTheme.industrialCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMatch
                      ? KioskTheme.signalGranted.withValues(alpha: 0.5)
                      : KioskTheme.signalScanning.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isMatch ? Icons.verified_user_rounded : Icons.security_rounded,
                        size: 14,
                        color: isMatch ? KioskTheme.signalGrantedText : KioskTheme.signalScanning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'VALIDACIÓN 2FA (1:1)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isMatch ? KioskTheme.signalGrantedText : KioskTheme.signalScanning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activeStudent.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: KioskTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sim != null
                        ? 'Similitud: ${(sim * 100).toStringAsFixed(1)}% (Umbral 65%)'
                        : 'Contrastando rostro contra credencial...',
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isMatch ? KioskTheme.signalGrantedText : KioskTheme.textGrey,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: KioskTheme.industrialBlack.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KioskTheme.industrialBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFace ? Icons.qr_code_scanner_rounded : Icons.info_outline_rounded,
                    size: 15,
                    color: hasFace ? KioskTheme.signalScanning : KioskTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasFace
                          ? 'Rostro detectado. Presente credencial QR/NFC o RUT.'
                          : 'Sitúese frente al sensor e ingrese su credencial.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: KioskTheme.textGrey,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Camera Release Toggle
          OutlinedButton.icon(
            onPressed: kioskVm.toggleLiveCamera,
            icon: const Icon(Icons.videocam_off_rounded, size: 15, color: KioskTheme.signalDenied),
            label: const Text(
              'DESACTIVAR CÁMARA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: KioskTheme.signalDenied,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: KioskTheme.signalDeniedBg,
              side: BorderSide(color: KioskTheme.signalDenied.withValues(alpha: 0.35)),
              minimumSize: const Size.fromHeight(38),
            ),
          ),
        ],
      ),
    );
  }
}
