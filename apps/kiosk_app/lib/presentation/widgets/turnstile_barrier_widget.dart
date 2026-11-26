import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

/// Bright transit/airport turnstile signage block with bold semantic headers.
class TurnstileBarrierWidget extends StatefulWidget {
  final bool isOpen;
  final String? studentName;
  final String? studentRut;
  final int latencyMs;
  final bool isCompact;

  const TurnstileBarrierWidget({
    super.key,
    required this.isOpen,
    this.studentName,
    this.studentRut,
    this.latencyMs = 80,
    this.isCompact = false,
  });

  @override
  State<TurnstileBarrierWidget> createState() => _TurnstileBarrierWidgetState();
}

class _TurnstileBarrierWidgetState extends State<TurnstileBarrierWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.isOpen) {
      _timerController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(TurnstileBarrierWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _timerController.forward(from: 0.0);
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _timerController.reset();
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isOpen
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.isCompact ? 380 : 600),
            child: _buildOpenSignage(),
          )
        : _buildClosedSignage();
  }

  Widget _buildOpenSignage() {
    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, _) {
        final progress = (1.0 - _timerController.value).clamp(0.0, 1.0);
        final secondsLeft = (2.0 * progress).toStringAsFixed(1);

        return Container(
          decoration: BoxDecoration(
            color: KioskTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KioskTheme.signalGranted, width: 2),
            boxShadow: KioskTheme.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Solid vivid green transit header
              Container(
                color: KioskTheme.signalGranted,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TORNIQUETE ABIERTO',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Paso habilitado · Adelante',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        'CIERRE ${secondsLeft}s',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: KioskTheme.signalGrantedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: KioskTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: KioskTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: KioskTheme.signalGrantedBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 20,
                          color: KioskTheme.signalGrantedText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentName ?? 'Estudiante',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: KioskTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.studentRut ?? '',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                                fontFamilyFallback: KioskTheme.monoFallback,
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: KioskTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: KioskTheme.signalGrantedBg,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${widget.latencyMs} ms',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            fontFamilyFallback: KioskTheme.monoFallback,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: KioskTheme.signalGrantedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: KioskTheme.surfaceMuted,
                valueColor: const AlwaysStoppedAnimation<Color>(KioskTheme.signalGranted),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClosedSignage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: KioskTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KioskTheme.border),
        boxShadow: KioskTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KioskTheme.signalDeniedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 22,
              color: KioskTheme.signalDeniedText,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TORNIQUETE CERRADO',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: KioskTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Esperando credencial NFC / QR (2FA)',
                  style: TextStyle(
                    fontSize: 12,
                    color: KioskTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: KioskTheme.signalDenied,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Text(
              'BLOQUEADO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
