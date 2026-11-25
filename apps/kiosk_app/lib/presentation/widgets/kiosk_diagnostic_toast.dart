import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';

/// Restrained diagnostic feedback banner for 2FA verification steps.
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
    0xFF10B981: KioskTheme.signalGrantedText,
    0xFFEF4444: KioskTheme.signalDenied,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _signalMap[toast.color.toARGB32()] ?? toast.color;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: KioskTheme.industrialSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KioskTheme.industrialBorderStrong, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(toast.icon, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            toast.title,
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            toast.message,
                            style: const TextStyle(
                              color: KioskTheme.textWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onDismiss != null)
                      IconButton(
                        tooltip: 'Cerrar aviso',
                        icon: const Icon(Icons.close_rounded, size: 16, color: KioskTheme.textGrey),
                        onPressed: onDismiss,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
