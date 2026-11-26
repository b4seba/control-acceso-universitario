import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/outbox/outbox_worker.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/guard_viewmodel.dart';

class GuardPanelView extends StatefulWidget {
  const GuardPanelView({super.key});

  @override
  State<GuardPanelView> createState() => _GuardPanelViewState();
}

class _GuardPanelViewState extends State<GuardPanelView> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guardVm = context.watch<GuardViewModel>();
    final outboxWorker = context.watch<OutboxWorker>();

    return Scaffold(
      backgroundColor: KioskTheme.canvas,
      appBar: AppBar(
        backgroundColor: KioskTheme.surface,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: KioskTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: KioskTheme.brandCrimson, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'CONSOLA DE GUARDIA / SUPERVISOR',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: KioskTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (guardVm.isLoggedIn) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: KioskTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KioskTheme.borderStrong),
                ),
                child: Text(
                  guardVm.guardName,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: KioskTheme.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: KioskTheme.textSecondary),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => guardVm.logout(),
              tooltip: 'Cerrar Sesión Guardia',
            ),
          ],
        ],
      ),
      body: guardVm.isLoggedIn
          ? _buildAdminDashboard(context, guardVm, outboxWorker)
          : _buildGuardLoginForm(context, guardVm),
    );
  }

  Widget _buildGuardLoginForm(BuildContext context, GuardViewModel guardVm) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: KioskTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KioskTheme.border),
              boxShadow: KioskTheme.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: KioskTheme.brandCrimson,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Autenticación de Guardia / Operador',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: KioskTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Configure Modo Isla y audite la bitácora outbox_events en SQLite local.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: KioskTheme.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _userController,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 14, color: KioskTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Usuario Operador',
                    hintText: 'Ingrese usuario operador',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => guardVm.login(_userController.text, _passController.text),
                  style: const TextStyle(fontSize: 14, color: KioskTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Contraseña de Seguridad',
                    hintText: 'Ingrese contraseña',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: KioskTheme.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (guardVm.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: KioskTheme.signalDeniedBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: KioskTheme.signalDenied.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      guardVm.errorMessage!,
                      style: const TextStyle(
                        color: KioskTheme.signalDeniedText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                ElevatedButton(
                  onPressed: () {
                    guardVm.login(_userController.text, _passController.text);
                  },
                  child: const Text('INGRESAR AL PANEL'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminDashboard(
      BuildContext context, GuardViewModel guardVm, OutboxWorker outboxWorker) {
    final isIsland = outboxWorker.isIslandMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Island Mode Toggle Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isIsland ? KioskTheme.signalDeniedBg : KioskTheme.signalGrantedBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isIsland ? KioskTheme.signalDenied : KioskTheme.signalGranted)
                        .withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: KioskTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: KioskTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isIsland ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                        size: 26,
                        color: isIsland
                            ? KioskTheme.signalDeniedText
                            : KioskTheme.signalGrantedText,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIsland
                                ? 'MODO ISLA ACTIVO (CORTE DE FIBRA ÓPTICA SIMULADO)'
                                : 'MODO CONECTADO A CENTRAL (FIBRA EN LÍNEA)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: isIsland
                                  ? KioskTheme.signalDeniedText
                                  : KioskTheme.signalGrantedText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isIsland
                                ? 'Red WAN desconectada. Los accesos se validan y persisten en disco local SQLite WAL sin pérdida de eventos.'
                                : 'Conectividad activa. El OutboxWorker despacha eventos al microservicio central en Go.',
                            style: const TextStyle(fontSize: 12.5, color: KioskTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch.adaptive(
                      value: isIsland,
                      activeThumbColor: KioskTheme.signalDenied,
                      activeTrackColor: KioskTheme.signalDenied.withValues(alpha: 0.35),
                      inactiveThumbColor: KioskTheme.signalGranted,
                      inactiveTrackColor: KioskTheme.signalGranted.withValues(alpha: 0.35),
                      onChanged: (val) {
                        outboxWorker.setIslandMode(val);
                        guardVm.loadRecentEvents();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Responsive Outbox Metrics
              LayoutBuilder(
                builder: (context, constraints) {
                  final total = outboxWorker.pendingCount + outboxWorker.syncedCount;
                  final cards = [
                    _buildMetricCard(
                      title: 'EN COLA OUTBOX (PENDING)',
                      count: outboxWorker.pendingCount,
                      color: KioskTheme.signalAmberText,
                      bgColor: KioskTheme.signalAmberBg,
                      icon: Icons.pending_actions_rounded,
                      subtitle: 'Retenidos en SQLite WAL',
                    ),
                    _buildMetricCard(
                      title: 'SINCRONIZADOS (SYNCED)',
                      count: outboxWorker.syncedCount,
                      color: KioskTheme.signalGrantedText,
                      bgColor: KioskTheme.signalGrantedBg,
                      icon: Icons.task_alt_rounded,
                      subtitle: 'Confirmados con ACK Hash',
                    ),
                    _buildMetricCard(
                      title: 'TOTAL REGISTROS LOCALES',
                      count: total,
                      color: KioskTheme.signalScanningDark,
                      bgColor: KioskTheme.signalScanningBg,
                      icon: Icons.storage_rounded,
                      subtitle: 'Tabla outbox_events',
                    ),
                  ];

                  if (constraints.maxWidth < 680) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cards[0],
                        const SizedBox(height: 12),
                        cards[1],
                        const SizedBox(height: 12),
                        cards[2],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[2]),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // 3. Outbox Worker Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: KioskTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KioskTheme.border),
                  boxShadow: KioskTheme.cardShadow,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estado del Outbox Worker',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: KioskTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            outboxWorker.lastSyncMessage,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: KioskTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: outboxWorker.isSyncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 17),
                          label: const Text('SINCRONIZAR AHORA'),
                          onPressed: outboxWorker.isSyncing
                              ? null
                              : () => guardVm.triggerOutboxSync(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.offline_pin_rounded,
                            size: 17,
                            color: KioskTheme.signalScanningDark,
                          ),
                          label: const Text(
                            'SIMULAR ACK LOCAL (DEMO)',
                            style: TextStyle(color: KioskTheme.signalScanningDark, fontSize: 12),
                          ),
                          onPressed: () => guardVm.triggerDemoLocalAck(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 4. SQLite WAL Forensic Audit Log
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'BITÁCORA TRANSACCIONAL EN DISCO (SQLite WAL · outbox_events)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: KioskTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: KioskTheme.textPrimary),
                    tooltip: 'Refrescar registros',
                    onPressed: () => guardVm.loadRecentEvents(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (guardVm.recentEvents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: KioskTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KioskTheme.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No hay eventos registrados aún. Realice lecturas en la pantalla del torniquete.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KioskTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: KioskTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KioskTheme.border),
                    boxShadow: KioskTheme.cardShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 22,
                      headingRowColor: WidgetStateProperty.all(KioskTheme.surfaceSubtle),
                      dataTextStyle: const TextStyle(color: KioskTheme.textPrimary, fontSize: 12),
                      headingTextStyle: const TextStyle(
                        color: KioskTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      columns: const [
                        DataColumn(label: Text('UUID Evento')),
                        DataColumn(label: Text('Estudiante / RUT')),
                        DataColumn(label: Text('Fecha / Hora UTC')),
                        DataColumn(label: Text('Resultado')),
                        DataColumn(label: Text('Latencia')),
                        DataColumn(label: Text('Estado Outbox')),
                        DataColumn(label: Text('Hash SHA-256')),
                      ],
                      rows: guardVm.recentEvents.map((e) {
                        final isGranted = e.accessResult.code == 'GRANTED';
                        final isSynced = e.status.code == 'SYNCED';

                        return DataRow(
                          cells: [
                            DataCell(Text(
                              e.eventUuid.length > 14
                                  ? '...${e.eventUuid.substring(e.eventUuid.length - 12)}'
                                  : e.eventUuid,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontFamilyFallback: KioskTheme.monoFallback,
                                fontSize: 12,
                              ),
                            )),
                            DataCell(Text(
                              '${e.studentId}\n${e.studentRut}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            )),
                            DataCell(Text(
                              e.accessTimestamp.length >= 19
                                  ? e.accessTimestamp.replaceAll('T', ' ').substring(0, 19)
                                  : e.accessTimestamp,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontFamilyFallback: KioskTheme.monoFallback,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isGranted
                                    ? KioskTheme.signalGrantedBg
                                    : KioskTheme.signalDeniedBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                e.accessResult.code,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isGranted
                                      ? KioskTheme.signalGrantedText
                                      : KioskTheme.signalDeniedText,
                                ),
                              ),
                            )),
                            DataCell(Text(
                              '${e.latencyMs} ms',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                fontFamilyFallback: KioskTheme.monoFallback,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: e.latencyMs <= 500
                                    ? KioskTheme.signalGrantedText
                                    : KioskTheme.signalDeniedText,
                              ),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSynced
                                    ? KioskTheme.signalGrantedBg
                                    : KioskTheme.signalAmberBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                e.status.code,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSynced
                                      ? KioskTheme.signalGrantedText
                                      : KioskTheme.signalAmberText,
                                ),
                              ),
                            )),
                            DataCell(Text(
                              e.payloadHash.length > 12
                                  ? '${e.payloadHash.substring(0, 12)}...'
                                  : e.payloadHash,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontFamilyFallback: KioskTheme.monoFallback,
                                fontSize: 12,
                                color: KioskTheme.textSecondary,
                              ),
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KioskTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KioskTheme.border),
        boxShadow: KioskTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: KioskTheme.textSecondary,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: KioskTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
