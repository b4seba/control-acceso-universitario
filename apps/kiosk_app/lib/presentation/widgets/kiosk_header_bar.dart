import 'package:flutter/material.dart';
import '../../data/outbox/outbox_worker.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';
import '../views/guard_panel_view.dart';

/// Matte industrial top bar showing terminal identity, Island Mode state,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: KioskTheme.industrialSurface,
        border: Border(bottom: BorderSide(color: KioskTheme.industrialBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;

          final brandSection = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KioskTheme.brandCrimson,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.meeting_room_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UNIVERSIDAD · CONTROL DE ACCESO',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: KioskTheme.textWhite,
                      ),
                    ),
                    Text(
                      '${kioskVm.campusId} · ${kioskVm.turnstileId}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontFamilyFallback: KioskTheme.monoFallback,
                        color: KioskTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final statusAndActions = Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isIsland ? KioskTheme.signalDeniedBg : KioskTheme.signalGrantedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isIsland ? KioskTheme.signalDenied : KioskTheme.signalGranted)
                        .withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIsland ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                      size: 14,
                      color: isIsland ? KioskTheme.signalDenied : KioskTheme.signalGrantedText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isIsland ? 'MODO ISLA (72h)' : 'CLOUD EN LÍNEA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isIsland ? KioskTheme.signalDenied : KioskTheme.signalGrantedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: KioskTheme.industrialCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KioskTheme.industrialBorderStrong),
                ),
                child: Text(
                  'OUTBOX: ${outboxWorker.pendingCount} PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    fontFamilyFallback: KioskTheme.monoFallback,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: outboxWorker.pendingCount > 0
                        ? KioskTheme.signalAmber
                        : KioskTheme.textGrey,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sync_rounded, color: KioskTheme.textWhite, size: 20),
                tooltip: 'Sincronizar lista blanca con PostgreSQL (Anti-Entropy)',
                onPressed: () => kioskVm.triggerManualSync(),
                style: IconButton.styleFrom(
                  backgroundColor: KioskTheme.industrialCard,
                  minimumSize: const Size(40, 40),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_rounded,
                    color: KioskTheme.textWhite, size: 20),
                tooltip: 'Panel de Supervisor / Guardia',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardPanelView()),
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: KioskTheme.industrialCard,
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
                const SizedBox(height: 10),
                statusAndActions,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: brandSection),
              const SizedBox(width: 12),
              statusAndActions,
            ],
          );
        },
      ),
    );
  }
}
