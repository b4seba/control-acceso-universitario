import 'package:flutter/material.dart';
import '../theme/kiosk_theme.dart';

/// Bloque de Estado del Torniquete (100% Software)
/// Indica de forma clara, moderna y sin representaciones mecánicas físicas
/// cuando el torniquete está CERRADO y cuando está ABIERTO.
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
    return widget.isOpen ? _buildOpenBlock() : _buildClosedBlock();
  }

  /// Bloque: TORNIQUETE ABIERTO (Paso Habilitado)
  Widget _buildOpenBlock() {
    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, child) {
        final progress = 1.0 - _timerController.value;
        final secondsLeft = (2.0 * progress).toStringAsFixed(1);

        return Container(
          width: widget.isCompact ? 320 : 420,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF032219),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: KioskTheme.haloGranted,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: KioskTheme.haloGranted.withValues(alpha: 0.45),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra superior: Etiqueta de software
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: KioskTheme.haloGranted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CONTROL ELECTRÓNICO DE ACCESO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: KioskTheme.haloGranted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: KioskTheme.haloGranted.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: KioskTheme.haloGranted, width: 1),
                    ),
                    child: Text(
                      'CIERRE EN ${secondsLeft}s',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: KioskTheme.haloGranted,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Icono Central de Desbloqueo y Texto Enorme
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: KioskTheme.haloGranted.withValues(alpha: 0.2),
                      border: Border.all(color: KioskTheme.haloGranted, width: 2),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      size: 36,
                      color: KioskTheme.haloGranted,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TORNIQUETE ABIERTO',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          color: KioskTheme.haloGranted,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'PASO HABILITADO • ADELANTE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Datos del Estudiante Verificado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: KioskTheme.haloGranted.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.studentName ?? 'Sebastián Freire',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.studentRut ?? '21.460.709-3',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: KioskTheme.haloGranted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: KioskTheme.haloGranted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.latencyMs} ms',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: KioskTheme.haloGranted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Barra de Tiempo de Paso Restante
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(KioskTheme.haloGranted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bloque: TORNIQUETE CERRADO (En espera)
  Widget _buildClosedBlock() {
    return Container(
      width: widget.isCompact ? 320 : 420,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CONTROL ELECTRÓNICO DE ACCESO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1),
                ),
                child: const Text(
                  'BLOQUEADO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 1.5),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 28,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TORNIQUETE CERRADO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ESPERANDO CREDENCIAL (2FA)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
