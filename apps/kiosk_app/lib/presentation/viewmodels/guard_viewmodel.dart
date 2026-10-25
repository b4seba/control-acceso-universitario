import 'package:flutter/foundation.dart';
import '../../data/database/turnstile_database.dart';
import '../../data/outbox/outbox_worker.dart';
import '../../domain/models/turnstile_event.dart';

class GuardViewModel extends ChangeNotifier {
  final TurnstileDatabase database;
  final OutboxWorker outboxWorker;

  bool _isLoggedIn = false;
  String _guardName = 'Guardia Operador';
  String? _errorMessage;
  List<TurnstileOutboxEvent> _recentEvents = [];
  bool _isLoadingEvents = false;

  GuardViewModel({
    required this.database,
    required this.outboxWorker,
  });

  bool get isLoggedIn => _isLoggedIn;
  String get guardName => _guardName;
  String? get errorMessage => _errorMessage;
  List<TurnstileOutboxEvent> get recentEvents => _recentEvents;
  bool get isLoadingEvents => _isLoadingEvents;

  bool login(String username, String password) {
    if ((username.trim() == 'guardia' || username.trim() == 'admin') &&
        password.trim() == 'ua2026') {
      _isLoggedIn = true;
      _guardName = username == 'admin' ? 'Supervisor Central' : 'Guardia de Acceso Providencia';
      _errorMessage = null;
      loadRecentEvents();
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Credenciales de seguridad inválidas (Use: guardia / ua2026)';
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _isLoggedIn = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadRecentEvents() async {
    _isLoadingEvents = true;
    notifyListeners();
    try {
      _recentEvents = await database.getRecentEvents(limit: 40);
    } catch (_) {}
    _isLoadingEvents = false;
    notifyListeners();
  }

  Future<void> triggerOutboxSync() async {
    await outboxWorker.triggerSyncNow();
    await loadRecentEvents();
  }

  Future<void> triggerDemoLocalAck() async {
    await outboxWorker.simulateLocalAckForDemo();
    await loadRecentEvents();
  }
}
