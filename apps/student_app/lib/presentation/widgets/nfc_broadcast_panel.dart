import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Clean, restrained NFC HCE emission panel without neon glows.
class NfcBroadcastPanel extends StatelessWidget {
  final Animation<double> waveAnimation;

  const NfcBroadcastPanel({super.key, required this.waveAnimation});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: waveAnimation,
            builder: (context, _) {
              final progress = reduceMotion ? 0.35 : waveAnimation.value;
              return SizedBox(
                width: 128,
                height: 128,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 68 + (56 * progress),
                      height: 68 + (56 * progress),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.institutionalCrimson.withValues(
                            alpha: (1.0 - progress) * 0.45,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.institutionalCrimson.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AppTheme.institutionalCrimson.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                    ),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.institutionalCrimson,
                      ),
                      child: const Icon(
                        Icons.nfc_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            'Listo para lectura por proximidad',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Acerque el teléfono al lector NFC (13.56 MHz) del torniquete y mire hacia la cámara frontal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppTheme.institutionalCrimson),
                SizedBox(width: 6),
                Text(
                  'Token HMAC-SHA256 activo · HCE ISO-14443',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
