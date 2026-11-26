import 'package:flutter/material.dart';
import '../../data/outbox/outbox_worker.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';
import '../views/guard_panel_view.dart';

/// Clean bright header bar displaying terminal identity, Island Mode status,
/// Outbox queue count, manual whitelist sync, and guard console entry.
class KioskHeaderBar extends StatelessWidget {
  final KioskViewModel kioskVm;
  final OutboxWorker outboxWorker;

  const KioskHeaderBar({
    super.key,
    required this.kioskVm,
    required this.outboxWorker,
  });

  @override
  Widget build(BuildContext context) {
    final isIsland = outboxWorker.isIslandMode;
    final hasPending = outboxWorker.pendingCount > 0;

    return Container(
      decoration: const BoxDecoration(
        color: KioskTheme.surface,
        border: Border(bottom: BorderSide(color: KioskTheme.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 740;

                final brandSection = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: KioskTheme.brandCrimson,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sensor_door_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UNIVERSIDAD · CONTROL DE ACCESO',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: KioskTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'NODO PERIMETRAL · ${kioskVm.turnstileId}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                              fontFamilyFallback: KioskTheme.monoFallback,
                              color: KioskTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final statusAndActions = Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isIsland ? KioskTheme.signalDeniedBg : KioskTheme.signalGrantedBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isIsland ? KioskTheme.signalDenied : KioskTheme.signalGranted)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isIsland ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                            size: 15,
                            color: isIsland
                                ? KioskTheme.signalDeniedText
                                : KioskTheme.signalGrantedText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isIsland ? 'MODO ISLA (72h)' : 'CLOUD EN LÍNEA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isIsland
                                  ? KioskTheme.signalDeniedText
                                  : KioskTheme.signalGrantedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: hasPending ? KioskTheme.signalAmberBg : KioskTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasPending
                              ? KioskTheme.signalAmber.withValues(alpha: 0.45)
                              : KioskTheme.borderStrong,
                        ),
                      ),
                      child: Text(
                        'OUTBOX: ${outboxWorker.pendingCount} PENDING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          fontFamilyFallback: KioskTheme.monoFallback,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: hasPending
                              ? KioskTheme.signalAmberText
                              : KioskTheme.textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync_rounded, color: KioskTheme.textPrimary, size: 20),
                      tooltip: 'Sincronizar lista blanca con Central (gRPC / REST)',
                      onPressed: () => kioskVm.triggerManualSync(),
                      style: IconButton.styleFrom(
                        backgroundColor: KioskTheme.surfaceSubtle,
                        side: const BorderSide(color: KioskTheme.borderStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: KioskTheme.brandCrimson,
                        size: 20,
                      ),
                      tooltip: 'Consola de Guardia / Supervisor',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const GuardPanelView()),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: KioskTheme.brandCrimsonSoft,
                        side: BorderSide(color: KioskTheme.brandCrimson.withValues(alpha: 0.25)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        minimumSize: const Size(40, 40),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      brandSection,
                      const SizedBox(height: 12),
                      statusAndActions,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: brandSection),
                    const SizedBox(width: 16),
                    statusAndActions,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
