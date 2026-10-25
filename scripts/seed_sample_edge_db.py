#!/usr/bin/env python3
"""
Genera y puebla una base de datos de prueba SQLite WAL con el esquema exacto del Kiosko Edge
Universidad - Evaluación Sumativa 2
"""
import sqlite3
import os
import json
import hashlib
from datetime import datetime, timezone

def generate_deterministic_vector(seed):
    h = hashlib.sha256(seed.encode('utf-8')).digest()
    vec = []
    for i in range(512):
        byte_val = h[i % len(h)]
        val = ((byte_val + (i * 7)) % 256) / 128.0 - 1.0
        vec.append(round(val, 4))
    return vec

def seed():
    db_path = "ua_turnstile_edge.db"
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # Habilitar WAL
    cur.execute("PRAGMA journal_mode = WAL;")
    cur.execute("PRAGMA synchronous = NORMAL;")

    # 1. Tabla Whitelist
    cur.execute("""
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
    """)

    # 2. Tabla Outbox Events
    cur.execute("""
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
    """)

    # Índices B-Tree
    cur.execute("CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox_events(status);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_whitelist_rut ON whitelist_users(rut);")

    # Poblar alumnos si la tabla está vacía
    cur.execute("SELECT count(*) FROM whitelist_users WHERE rut = '21.460.709-3'")
    already_enrolled = cur.fetchone()[0] > 0

    if not already_enrolled:
        cur.execute("SELECT count(*) FROM whitelist_users")
        total = cur.fetchone()[0]
        if total == 0:
            students = [
                ("ua-stu-2026-001", "21.460.709-3", "Sebastián Freire", "Ingeniería Civil Informática", "Campus Alameda", "ESTUDIANTE", "VIGENTE", json.dumps(generate_deterministic_vector("freire-face-seed-2026"))),
            ]
            cur.executemany("""
            INSERT OR REPLACE INTO whitelist_users VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, students)
    else:
        print("[+] Estudiante real Sebastián Freire (RUT 21.460.709-3) preservado en SQLite WAL.")

    # Poblar transacciones iniciales para demostrar Modo Isla y Outbox
    now = datetime.now(timezone.utc).isoformat()
    events = [
        ("evt-seed-001", "TRN-PROV-01", "CAMPUS_PROVIDENCIA", "ua-stu-2026-001", "20.456.789-K", now, "GRANTED", None, 94, "hash-seed-freire-001", "SYNCED", 0, now, "ACK-hash-confirm-001"),
        ("evt-seed-002", "TRN-PROV-01", "CAMPUS_PROVIDENCIA", "ua-stu-2026-004", "19.876.543-2", now, "DENIED", "Matrícula no vigente / Sanción activa", 32, "hash-seed-matias-002", "SYNCED", 0, now, "ACK-hash-confirm-002"),
        ("evt-seed-003", "TRN-PROV-01", "CAMPUS_PROVIDENCIA", "ua-stu-2026-002", "20.123.456-7", now, "GRANTED", None, 108, "hash-seed-valenzuela-003", "PENDING", 0, None, None),
    ]

    cur.executemany("""
    INSERT OR REPLACE INTO outbox_events (event_uuid, turnstile_id, campus_id, student_id, student_rut, access_timestamp, access_result, denial_reason, latency_ms, payload_hash, status, retry_count, synced_at, ack_hash)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, events)

    conn.commit()
    conn.close()
    print("[+] Base de datos SQLite 'ua_turnstile_edge.db' generada y poblada exitosamente en modo WAL.")

if __name__ == "__main__":
    seed()
