import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/guard_viewmodel.dart';
import '../../data/outbox/outbox_worker.dart';

class GuardPanelView extends StatefulWidget {
  const GuardPanelView({super.key});

  @override
  State<GuardPanelView> createState() => _GuardPanelViewState();
}

class _GuardPanelViewState extends State<GuardPanelView> {
  final _userController = TextEditingController(text: 'guardia');
  final _passController = TextEditingController(text: 'ua2026');

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
      backgroundColor: KioskTheme.industrialBlack,
      appBar: AppBar(
        backgroundColor: KioskTheme.industrialSurface,
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: KioskTheme.haloFaceScanning),
            const SizedBox(width: 10),
            const Text(
              'PANEL DE CONTROL DE GUARDIA / SUPERVISOR',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            if (guardVm.isLoggedIn)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: KioskTheme.haloFaceScanning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: KioskTheme.haloFaceScanning),
                    ),
                    child: Text(
                      guardVm.guardName,
                      style: const TextStyle(fontSize: 12, color: KioskTheme.haloFaceScanning),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: KioskTheme.textGrey),
                    onPressed: () => guardVm.logout(),
                    tooltip: 'Cerrar Sesión Guardia',
                  ),
                ],
              ),
          ],
        ),
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
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      size: 54, color: KioskTheme.haloIdle),
                  const SizedBox(height: 16),
                  const Text(
                    'Autenticación de Guardia / Operador',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingrese credenciales para configurar Modo Isla y auditar outbox_events en SQLite local.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: KioskTheme.textGrey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario Operador',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña de Seguridad',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (guardVm.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: KioskTheme.haloDenied.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: KioskTheme.haloDenied),
                      ),
                      child: Text(
                        guardVm.errorMessage!,
                        style: const TextStyle(color: KioskTheme.haloDenied, fontSize: 12),
                      ),
                    ),
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
      ),
    );
  }

  Widget _buildAdminDashboard(
      BuildContext context, GuardViewModel guardVm, OutboxWorker outboxWorker) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Switch Interactivo de Modo Isla (Simulador de Corte de Fibra 72h)
          Card(
            color: outboxWorker.isIslandMode
                ? const Color(0xFF2C1518)
                : const Color(0xFF0D2538),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: outboxWorker.isIslandMode
                    ? KioskTheme.haloDenied
                    : KioskTheme.haloGranted,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    outboxWorker.isIslandMode
                        ? Icons.cloud_off_rounded
                        : Icons.cloud_done_rounded,
                    size: 38,
                    color: outboxWorker.isIslandMode
                        ? KioskTheme.haloDenied
                        : KioskTheme.haloGranted,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          outboxWorker.isIslandMode
                              ? 'MODO ISLA ACTIVO (CORTE DE FIBRA ÓPTICA SIMULADO)'
                              : 'MODO CONECTADO A CENTRAL (FIBRA EN LÍNEA)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: outboxWorker.isIslandMode
                                ? KioskTheme.haloDenied
                                : KioskTheme.haloGranted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outboxWorker.isIslandMode
                              ? 'La red WAN está cortada. Los accesos se validan y almacenan en disco local SQLite WAL sin pérdida de datos.'
                              : 'Conectividad restaurada. El OutboxWorker despacha eventos al microservicio Golang central.',
                          style: const TextStyle(fontSize: 12, color: KioskTheme.textGrey),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: outboxWorker.isIslandMode,
                    activeThumbColor: KioskTheme.haloDenied,
                    activeTrackColor: KioskTheme.haloDenied.withValues(alpha: 0.3),
                    inactiveThumbColor: KioskTheme.haloGranted,
                    inactiveTrackColor: KioskTheme.haloGranted.withValues(alpha: 0.3),
                    onChanged: (val) {
                      outboxWorker.setIslandMode(val);
                      guardVm.loadRecentEvents();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 2. Tarjetas de Estadísticas de Transactional Outbox
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'EN COLA OUTBOX (PENDING)',
                  count: outboxWorker.pendingCount,
                  color: KioskTheme.haloNfcReading,
                  icon: Icons.pending_actions_rounded,
                  subtitle: 'Retenidos en SQLite WAL',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'SINCRONIZADOS (SYNCED)',
                  count: outboxWorker.syncedCount,
                  color: KioskTheme.haloGranted,
                  icon: Icons.task_alt_rounded,
                  subtitle: 'Confirmados con ACK Hash',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'TOTAL REGISTROS LOCALES',
                  count: outboxWorker.pendingCount + outboxWorker.syncedCount,
                  color: KioskTheme.haloFaceScanning,
                  icon: Icons.storage_rounded,
                  subtitle: 'Tabla outbox_events',
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 3. Barra de Acciones de Sincronización y Diagnóstico
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado del Outbox Worker:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: KioskTheme.textGrey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          outboxWorker.lastSyncMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: KioskTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: outboxWorker.isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('SINCRONIZAR AHORA'),
                    onPressed: outboxWorker.isSyncing
                        ? null
                        : () => guardVm.triggerOutboxSync(),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: KioskTheme.haloFaceScanning),
                    ),
                    icon: const Icon(Icons.offline_pin_rounded,
                        size: 18, color: KioskTheme.haloFaceScanning),
                    label: const Text('SIMULAR ACK LOCAL (DEMO)',
                        style: TextStyle(color: KioskTheme.haloFaceScanning, fontSize: 12)),
                    onPressed: () => guardVm.triggerDemoLocalAck(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 4. Visor en Vivo de la Tabla outbox_events en SQLite WAL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BITÁCORA TRANSACCIONAL EN DISCO (SQLite WAL: outbox_events)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: KioskTheme.haloFaceScanning,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: KioskTheme.haloFaceScanning),
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
                color: KioskTheme.industrialSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KioskTheme.industrialBorder),
              ),
              child: const Center(
                child: Text(
                  'No hay eventos registrados aún. Realice lecturas en la pantalla del torniquete.',
                  style: TextStyle(color: KioskTheme.textMuted),
                ),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  headingRowColor: WidgetStateProperty.all(KioskTheme.industrialCard),
                  columns: const [
                    DataColumn(label: Text('UUID Evento', style: TextStyle(fontWeight: FontWeight.w800))),
                    DataColumn(label: Text('Estudiante / RUT', style: TextStyle(fontWeight: FontWeight.w800))),
                    DataColumn(label: Text('Fecha / Hora UTC', style: TextStyle(fontWeight: FontWeight.w800))),
                    DataColumn(label: Text('Resultado', style: TextStyle(fontWeight: FontWeight.w800))),
                    DataColumn(label: Text('Latencia', style: TextStyle(fontWeight: FontWeight.w800))),
                    DataColumn(label: Text('Estado Outbox', style: TextStyle(fontWeight: FontWeight.w800))),
                    DataColumn(label: Text('Hash SHA-256 Inmutable', style: TextStyle(fontWeight: FontWeight.w800))),
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
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        )),
                        DataCell(Text(
                          '${e.studentId}\n${e.studentRut}',
                          style: const TextStyle(fontSize: 11),
                        )),
                        DataCell(Text(
                          e.accessTimestamp.replaceAll('T', ' ').substring(0, 19),
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isGranted ? KioskTheme.haloGranted : KioskTheme.haloDenied)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isGranted ? KioskTheme.haloGranted : KioskTheme.haloDenied,
                            ),
                          ),
                          child: Text(
                            e.accessResult.code,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isGranted ? KioskTheme.haloGranted : KioskTheme.haloDenied,
                            ),
                          ),
                        )),
                        DataCell(Text(
                          '${e.latencyMs} ms',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: e.latencyMs <= 500
                                ? KioskTheme.haloGranted
                                : KioskTheme.haloDenied,
                          ),
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isSynced ? KioskTheme.haloGranted : KioskTheme.haloNfcReading)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e.status.code,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSynced ? KioskTheme.haloGranted : KioskTheme.haloNfcReading,
                            ),
                          ),
                        )),
                        DataCell(Text(
                          '${e.payloadHash.substring(0, 12)}...',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: KioskTheme.textGrey,
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
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: KioskTheme.textGrey,
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: KioskTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
