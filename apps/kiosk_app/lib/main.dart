import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database/turnstile_database.dart';
import 'data/outbox/outbox_worker.dart';
import 'presentation/theme/kiosk_theme.dart';
import 'presentation/viewmodels/kiosk_viewmodel.dart';
import 'presentation/viewmodels/guard_viewmodel.dart';
import 'presentation/views/kiosk_main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Base de Datos SQLite en modo WAL
  final database = TurnstileDatabase.instance;
  await database.database;

  // Inicializar Worker asíncrono de Transactional Outbox
  final outboxWorker = OutboxWorker(database: database);

  runApp(TurnstileKioskApp(
    database: database,
    outboxWorker: outboxWorker,
  ));
}

class TurnstileKioskApp extends StatelessWidget {
  final TurnstileDatabase database;
  final OutboxWorker outboxWorker;

  const TurnstileKioskApp({
    super.key,
    required this.database,
    required this.outboxWorker,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: outboxWorker),
        ChangeNotifierProvider(
          create: (_) => KioskViewModel(
            turnstileId: 'TRN-PROV-01',
            campusId: 'CAMPUS_PROVIDENCIA',
            database: database,
            outboxWorker: outboxWorker,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => GuardViewModel(
            database: database,
            outboxWorker: outboxWorker,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'UA Kiosko Torniquete Edge',
        debugShowCheckedModeBanner: false,
        theme: KioskTheme.industrialTheme,
        home: const KioskMainView(),
      ),
    );
  }
}
