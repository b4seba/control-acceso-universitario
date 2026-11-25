import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../viewmodels/credential_viewmodel.dart';

/// Boarding-pass style high-contrast dynamic 15s TOTP QR code panel.
class DynamicQrPanel extends StatelessWidget {
  final CredentialViewModel credVm;

  const DynamicQrPanel({super.key, required this.credVm});

  @override
  Widget build(BuildContext context) {
    final isExpiring = credVm.remainingSeconds <= 4;
    final progressColor = isExpiring ? AppTheme.statusDenied : AppTheme.institutionalCrimson;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Text(
            'Pase Dinámico QR (TOTP 15s)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enfoque el código al lector óptico si el terminal NFC no está disponible.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // High-contrast QR container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            child: QrImageView(
              data: credVm.qrString,
              version: QrVersions.auto,
              size: 192.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppTheme.textPrimary,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Tabular 6-digit TOTP numeric readout
          Text(
            credVm.totpCode,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 5.0,
              fontFamily: 'monospace',
              fontFamilyFallback: AppTheme.monoFallback,
              fontFeatures: [FontFeature.tabularFigures()],
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: credVm.progress,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rotación TOTP RFC 6238',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                'Expira en ${credVm.remainingSeconds} s',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isExpiring ? AppTheme.statusDenied : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
