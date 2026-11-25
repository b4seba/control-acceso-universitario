import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

/// Airport/transit-inspired software turnstile wayfinding signage block.
/// Displays crisp OPEN (granted) or CLOSED (standby) status without neon glows.
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
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.isCompact ? 360 : 520),
      child: widget.isOpen ? _buildOpenSignage() : _buildClosedSignage(),
    );
  }

  Widget _buildOpenSignage() {
    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, _) {
        final progress = (1.0 - _timerController.value).clamp(0.0, 1.0);
        final secondsLeft = (2.0 * progress).toStringAsFixed(1);

        return Container(
          decoration: BoxDecoration(
            color: KioskTheme.signalGrantedBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KioskTheme.signalGranted.withValues(alpha: 0.6), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_open_rounded, size: 16, color: KioskTheme.signalGrantedText),
                            SizedBox(width: 8),
                            Text(
                              'CONTROL DE ACCESO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: KioskTheme.signalGrantedText,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KioskTheme.signalGranted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'CIERRE ${secondsLeft}s',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: Color(0xFF090A0D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: KioskTheme.signalGranted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 28,
                            color: Color(0xFF090A0D),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: KioskTheme.signalGrantedText,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Paso habilitado · Adelante',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: KioskTheme.textWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: KioskTheme.industrialBlack.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: KioskTheme.signalGranted.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.studentName ?? 'Estudiante',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: KioskTheme.textWhite,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.studentRut ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontFamilyFallback: KioskTheme.monoFallback,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                    color: KioskTheme.signalGrantedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: KioskTheme.industrialBlack,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: KioskTheme.industrialSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KioskTheme.industrialBorderStrong, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: KioskTheme.signalDeniedBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KioskTheme.signalDenied.withValues(alpha: 0.35)),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 20,
              color: KioskTheme.signalDenied,
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
                    letterSpacing: 0.6,
                    color: KioskTheme.textWhite,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Esperando credencial NFC / QR (2FA)',
                  style: TextStyle(
                    fontSize: 12,
                    color: KioskTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: KioskTheme.signalDeniedBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: KioskTheme.signalDenied.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'BLOQUEADO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: KioskTheme.signalDenied,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
