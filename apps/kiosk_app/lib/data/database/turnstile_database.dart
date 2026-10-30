import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../domain/models/turnstile_event.dart';
import '../../domain/models/whitelist_student.dart';

class TurnstileDatabase {
  static TurnstileDatabase? _instance;
  static Database? _database;

  TurnstileDatabase._internal();

  static TurnstileDatabase get instance {
    _instance ??= TurnstileDatabase._internal();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Si corre en Windows / Linux / macOS desktop, inicializar FFI
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path = join(await getDatabasesPath(), 'ua_turnstile_edge.db');

    // Comprobar si existe la base de datos maestra compartida con Python en la raíz del proyecto
    final candidatePaths = [
      'ua_turnstile_edge.db',
      '../ua_turnstile_edge.db',
      '../../ua_turnstile_edge.db',
      'C:/Users/HP/Documents/U/ARQ SOFTWARE/EV 2/ua_turnstile_edge.db',
      'C:\\Users\\HP\\Documents\\U\\ARQ SOFTWARE\\EV 2\\ua_turnstile_edge.db',
    ];

    for (final candidate in candidatePaths) {
      if (File(candidate).existsSync()) {
        path = File(candidate).absolute.path;
        break;
      }
    }

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        // Habilitar Modo WAL (Write-Ahead Logging) obligatorio según ADR-003
        await db.execute('PRAGMA journal_mode = WAL;');
        await db.execute('PRAGMA synchronous = NORMAL;');
      },
    );

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabla Whitelist Local de Usuarios
    await db.execute('''
      CREATE TABLE IF NOT EXISTS whitelist_users (
        student_id TEXT PRIMARY KEY,
        rut TEXT NOT NULL,
        full_name TEXT NOT NULL,
        career TEXT NOT NULL,
        campus TEXT NOT NULL,
        role TEXT NOT NULL,
        status TEXT NOT NULL,
        face_vector_json TEXT NOT NULL
      )
    ''');

    // 2. Tabla Transactional Outbox (Eventos de acceso persistentes en disco)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_uuid TEXT UNIQUE NOT NULL,
        turnstile_id TEXT NOT NULL,
        campus_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        student_rut TEXT NOT NULL,
        access_timestamp TEXT NOT NULL,
        access_result TEXT NOT NULL,
        denial_reason TEXT,
        latency_ms INTEGER NOT NULL,
        payload_hash TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        retry_count INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT,
        ack_hash TEXT
      )
    ''');

    // Índices B-Tree para optimización de consultas en < 3 ms
    await db.execute('CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox_events(status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_whitelist_rut ON whitelist_users(rut);');

    // Poblar lista blanca inicial con estudiantes de prueba institucional
    await _seedInitialWhitelist(db);
  }

  Future<void> _seedInitialWhitelist(Database db) async {
    final students = [
      WhitelistStudent(
        studentId: 'ua-stu-2026-001',
        rut: '20.456.789-K',
        fullName: 'Sebastián Freire',
        career: 'Ingeniería Civil Informática',
        campus: 'Campus Providencia',
        role: 'ESTUDIANTE',
        status: 'VIGENTE',
        faceVector512: WhitelistStudent.generateDeterministicVector('freire-face-seed-2026'),
      ),
      WhitelistStudent(
        studentId: 'ua-stu-2026-002',
        rut: '20.123.456-7',
        fullName: 'Luciano Valenzuela',
        career: 'Ingeniería Civil Informática',
        campus: 'Campus Providencia',
        role: 'ESTUDIANTE',
        status: 'VIGENTE',
        faceVector512: WhitelistStudent.generateDeterministicVector('valenzuela-face-seed-2026'),
      ),
      WhitelistStudent(
        studentId: 'ua-aca-2026-003',
        rut: '15.678.910-1',
        fullName: 'Cristofher Rojas Rojas',
        career: 'Facultad de Ingeniería',
        campus: 'Campus Providencia',
        role: 'ACADEMICO',
        status: 'VIGENTE',
        faceVector512: WhitelistStudent.generateDeterministicVector('rojas-face-seed-2026'),
      ),
      WhitelistStudent(
        studentId: 'ua-stu-2026-004',
        rut: '19.876.543-2',
        fullName: 'Matías González (Sancionado)',
        career: 'Derecho',
        campus: 'Campus El Llano Subercaseaux',
        role: 'ESTUDIANTE',
        status: 'SUSPENDIDO',
        faceVector512: WhitelistStudent.generateDeterministicVector('gonzalez-face-seed-2026'),
      ),
    ];

    for (final s in students) {
      await db.insert('whitelist_users', s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<WhitelistStudent?> findStudentByIdOrRut(String query) async {
    final db = await database;
    final clean = query.replaceAll('.', '').replaceAll('-', '').trim().toUpperCase();

    final results = await db.query(
      'whitelist_users',
      where: "student_id = ? OR rut = ? OR UPPER(REPLACE(REPLACE(rut, '.', ''), '-', '')) = ?",
      whereArgs: [query, query, clean],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return WhitelistStudent.fromMap(results.first);
    }
    return null;
  }

  /// Reconcilia la lista blanca local contra la fuente central de verdad (PostgreSQL 16).
  /// Elimina atómicamente de SQLite a cualquier estudiante que haya sido borrado en PostgreSQL
  /// e inserta o actualiza a los estudiantes vigentes.
  Future<int> reconcileWhitelist(List<WhitelistStudent> centralStudents) async {
    final db = await database;
    int deletedCount = 0;

    await db.transaction((txn) async {
      if (centralStudents.isEmpty) {
        deletedCount = await txn.delete('whitelist_users');
        return;
      }

      // 1. Recopilar identificadores válidos desde el backend central
      final validIds = <String>{};
      for (final s in centralStudents) {
        if (s.studentId.isNotEmpty) validIds.add(s.studentId);
        if (s.rut.isNotEmpty) {
          validIds.add(s.rut);
          validIds.add(s.rut.replaceAll('.', '').replaceAll('-', '').trim().toUpperCase());
        }
      }

      // 2. Consultar registros actuales en SQLite
      final currentRows = await txn.query('whitelist_users', columns: ['student_id', 'rut']);

      // 3. Eliminar huérfanos que ya no están en PostgreSQL
      for (final row in currentRows) {
        final sid = row['student_id'] as String? ?? '';
        final rut = row['rut'] as String? ?? '';
        final cleanRut = rut.replaceAll('.', '').replaceAll('-', '').trim().toUpperCase();

        final existsInCentral = validIds.contains(sid) ||
            validIds.contains(rut) ||
            validIds.contains(cleanRut);

        if (!existsInCentral) {
          await txn.delete(
            'whitelist_users',
            where: 'student_id = ? OR rut = ?',
            whereArgs: [sid, rut],
          );
          deletedCount++;
        }
      }

      // 4. Actualizar o insertar los estudiantes vigentes
      for (final student in centralStudents) {
        await txn.insert(
          'whitelist_users',
          student.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    return deletedCount;
  }

  Future<void> insertOrUpdateStudent(WhitelistStudent student) async {
    final db = await database;
    await db.insert('whitelist_users', student.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Inserta atómicamente un nuevo evento en el Transactional Outbox
  Future<int> insertOutboxEvent(TurnstileOutboxEvent event) async {
    final db = await database;
    return await db.insert('outbox_events', event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Recupera los eventos en estado PENDING para sincronización por lotes
  Future<List<TurnstileOutboxEvent>> getPendingEvents({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'outbox_events',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'id ASC',
      limit: limit,
    );
    return results.map((m) => TurnstileOutboxEvent.fromMap(m)).toList();
  }

  /// Actualiza a SYNCED atómicamente tras recibir el hash ACK del backend central
  Future<int> markEventsAsSynced(Map<String, String> ackHashMap) async {
    final db = await database;
    int updatedCount = 0;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      for (final entry in ackHashMap.entries) {
        final count = await txn.update(
          'outbox_events',
          {
            'status': 'SYNCED',
            'synced_at': now,
            'ack_hash': entry.value,
          },
          where: 'event_uuid = ?',
          whereArgs: [entry.key],
        );
        updatedCount += count;
      }
    });

    return updatedCount;
  }

  /// Obtiene estadísticas en tiempo real: PENDING vs SYNCED
  Future<Map<String, int>> getOutboxStats() async {
    final db = await database;
    final pendingRes = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM outbox_events WHERE status = 'PENDING'");
    final syncedRes = await db.rawQuery(
        "SELECT COUNT(*) as cnt FROM outbox_events WHERE status = 'SYNCED'");

    final pendingCount = Sqflite.firstIntValue(pendingRes) ?? 0;
    final syncedCount = Sqflite.firstIntValue(syncedRes) ?? 0;

    return {
      'pending': pendingCount,
      'synced': syncedCount,
      'total': pendingCount + syncedCount,
    };
  }

  /// Recupera los eventos más recientes para el panel de auditoría del guardia
  Future<List<TurnstileOutboxEvent>> getRecentEvents({int limit = 30}) async {
    final db = await database;
    final results = await db.query(
      'outbox_events',
      orderBy: 'id DESC',
      limit: limit,
    );
    return results.map((m) => TurnstileOutboxEvent.fromMap(m)).toList();
  }
}
