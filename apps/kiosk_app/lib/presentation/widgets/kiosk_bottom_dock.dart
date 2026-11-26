import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';

/// Clean light bottom dock for 2FA credential submission plus progressive-disclosure QA triggers.
class KioskBottomDock extends StatefulWidget {
  final TextEditingController controller;
  final KioskViewModel kioskVm;
  final ValueChanged<String> onSubmitPayload;

  const KioskBottomDock({
    super.key,
    required this.controller,
    required this.kioskVm,
    required this.onSubmitPayload,
  });

  @override
  State<KioskBottomDock> createState() => _KioskBottomDockState();
}

class _KioskBottomDockState extends State<KioskBottomDock> {
  bool _showDemoTools = false;

  Future<void> _pasteAndSubmit() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final text = data.text!.trim();
      widget.controller.text = text;
      widget.onSubmitPayload(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KioskTheme.surface,
        border: Border(top: BorderSide(color: KioskTheme.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 540;

                    final inputField = SizedBox(
                      height: 46,
                      child: TextField(
                        controller: widget.controller,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontFamily: 'monospace',
                          fontFamilyFallback: KioskTheme.monoFallback,
                          color: KioskTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Pegue trama NFC/QR o ingrese RUT...',
                          prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste_rounded, size: 18),
                            tooltip: 'Pegar desde portapapeles y procesar',
                            onPressed: _pasteAndSubmit,
                          ),
                        ),
                        onChanged: (val) {
                          final trimmed = val.trim();
                          if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
                              (trimmed.length >= 11 &&
                                  trimmed.contains('-') &&
                                  RegExp(r'^\d{1,2}\.?\d{3}\.?\d{3}-[\dkK]$')
                                      .hasMatch(trimmed))) {
                            widget.onSubmitPayload(trimmed);
                          }
                        },
                        onSubmitted: widget.onSubmitPayload,
                      ),
                    );

                    final processButton = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KioskTheme.signalGranted,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(165, 46),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      onPressed: () => widget.onSubmitPayload(widget.controller.text),
                      label: const Text(
                        'PROCESAR 2FA',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          inputField,
                          const SizedBox(height: 10),
                          processButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: inputField),
                        const SizedBox(width: 12),
                        processButton,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showDemoTools = !_showDemoTools),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showDemoTools
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_right_rounded,
                              size: 18,
                              color: KioskTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Herramientas de Simulación / QA (4)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: KioskTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.kioskVm.resetToIdle,
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Reset IDLE', style: TextStyle(fontSize: 11.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: KioskTheme.textSecondary,
                        minimumSize: const Size(40, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ),
                  ],
                ),
                if (_showDemoTools) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildQaChip(
                        icon: Icons.block_rounded,
                        iconColor: KioskTheme.signalDeniedText,
                        label: 'RUT No Registrado (Denegado)',
                        textColor: KioskTheme.signalDeniedText,
                        onPressed: () {
                          widget.controller.text = '00.000.000-0';
                          widget.onSubmitPayload('00.000.000-0');
                        },
                      ),
                      _buildQaChip(
                        icon: Icons.face_retouching_off_rounded,
                        iconColor: KioskTheme.signalDeniedText,
                        label: 'Rostro Divergente (2FA)',
                        textColor: KioskTheme.signalDeniedText,
                        onPressed: () => widget.kioskVm.simulateDivergentFace(widget.controller.text),
                      ),
                      _buildQaChip(
                        icon: Icons.timer_off_rounded,
                        iconColor: KioskTheme.signalAmberText,
                        label: 'Timeout 3.5s',
                        textColor: KioskTheme.signalAmberText,
                        onPressed: () => widget.kioskVm.simulateTimeout(widget.controller.text),
                      ),
                      _buildQaChip(
                        icon: Icons.clear_rounded,
                        iconColor: KioskTheme.textSecondary,
                        label: 'Limpiar entrada',
                        onPressed: () => widget.controller.clear(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQaChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color textColor = KioskTheme.textPrimary,
    required VoidCallback onPressed,
  }) {
    return ActionChip(
      backgroundColor: KioskTheme.surfaceSubtle,
      side: const BorderSide(color: KioskTheme.borderStrong),
      avatar: Icon(icon, size: 15, color: iconColor),
      label: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
      ),
      onPressed: onPressed,
    );
  }
}
