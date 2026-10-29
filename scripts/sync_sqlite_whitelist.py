#!/usr/bin/env python3
"""
Script de Reconciliación Anti-Entropy para SQLite Edge (Kiosko)
Lee la lista blanca autorizada desde el Microservicio Go (PostgreSQL 16 SSOT + Qdrant)
y actualiza atómicamente ua_turnstile_edge.db
"""
import os
import sys
import json
import sqlite3
import urllib.request

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(PROJECT_ROOT, "ua_turnstile_edge.db")
API_URL = "http://localhost:8080/api/v1/sync/whitelist"

def reconcile_sqlite():
    print(f"[*] Consultando lista blanca autorizada en {API_URL}...")
    try:
        req = urllib.request.Request(API_URL, headers={"User-Agent": "SIRAD-AntiEntropy/1.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        print(f"[ERROR] No se pudo conectar con el microservicio Go: {e}")
        return False

    users = data.get("users", [])
    print(f"[+] Recibidos {len(users)} usuarios autorizados desde PostgreSQL 16.")

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("PRAGMA journal_mode = WAL;")

    # Asegurar tabla
    cur.execute("""
    CREATE TABLE IF NOT EXISTS whitelist_users (
        student_id TEXT PRIMARY KEY,
        rut TEXT UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        career TEXT,
        campus TEXT,
        role TEXT DEFAULT 'ESTUDIANTE',
        status TEXT DEFAULT 'VIGENTE',
        face_vector_json TEXT
    );
    """)

    cur.execute("DELETE FROM whitelist_users;")
    for u in users:
        sid = u.get("student_id", "")
        rut = u.get("rut", "")
        fn = u.get("full_name", "")
        car = u.get("career", "")
        cam = u.get("campus", "")
        role = u.get("role", "ESTUDIANTE")
        st = u.get("enrollment_status") or u.get("status") or "VIGENTE"
        vec = u.get("face_vector_512", [])

        cur.execute("""
        INSERT OR REPLACE INTO whitelist_users 
        (student_id, rut, full_name, career, campus, role, status, face_vector_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (sid, rut, fn, car, cam, role, st, json.dumps(vec)))

    conn.commit()
    cur.execute("SELECT COUNT(*) FROM whitelist_users;")
    count = cur.fetchone()[0]
    conn.close()

    print(f"[✓] SQLite Edge ({DB_PATH}) reconciliado exitosamente. Total registros activos: {count}")
    return True

if __name__ == "__main__":
    reconcile_sqlite()

