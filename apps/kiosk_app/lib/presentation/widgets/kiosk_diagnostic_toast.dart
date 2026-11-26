import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';

/// Crisp high-contrast feedback banner for 2FA and Anti-Spoofing events.
class KioskDiagnosticToast extends StatelessWidget {
  final KioskToast toast;
  final VoidCallback? onDismiss;

  const KioskDiagnosticToast({
    super.key,
    required this.toast,
    this.onDismiss,
  });

  static const Map<int, Color> _signalMap = {
    0xFF00F0FF: KioskTheme.signalScanning,
    0xFF00B4D8: KioskTheme.signalScanning,
    0xFF10B981: KioskTheme.signalGranted,
    0xFFEF4444: KioskTheme.signalDenied,
  };

  Color _softBgFor(Color accent) {
    if (accent == KioskTheme.signalGranted) return KioskTheme.signalGrantedBg;
    if (accent == KioskTheme.signalDenied) return KioskTheme.signalDeniedBg;
    return KioskTheme.signalScanningBg;
  }

  Color _textColorFor(Color accent) {
    if (accent == KioskTheme.signalGranted) return KioskTheme.signalGrantedText;
    if (accent == KioskTheme.signalDenied) return KioskTheme.signalDeniedText;
    return KioskTheme.signalScanningDark;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _signalMap[toast.color.toARGB32()] ?? toast.color;
    final titleColor = _textColorFor(accent);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      decoration: BoxDecoration(
        color: KioskTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
        boxShadow: KioskTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _softBgFor(accent),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(toast.icon, color: titleColor, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            toast.title,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            toast.message,
                            style: const TextStyle(
                              color: KioskTheme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onDismiss != null)
                      IconButton(
                        tooltip: 'Cerrar aviso',
                        icon: const Icon(Icons.close_rounded, size: 17, color: KioskTheme.textMuted),
                        onPressed: onDismiss,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
