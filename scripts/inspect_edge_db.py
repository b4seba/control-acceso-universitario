#!/usr/bin/env python3
"""
Script de Inspección Forense de la Base de Datos SQLite WAL del Kiosko Edge
Universidad - Evaluación Sumativa 2
"""
import os
import sys
import sqlite3
import glob

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

def find_edge_db():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    candidates = [
        os.path.join(project_root, "ua_turnstile_edge.db"),
        os.path.join(project_root, "apps", "kiosk_app", "ua_turnstile_edge.db"),
        "ua_turnstile_edge.db",
        "apps/kiosk_app/ua_turnstile_edge.db",
        os.path.expandvars(r"%LOCALAPPDATA%\ua_turnstile_edge.db"),
    ]
    # Buscar en subcarpetas de AppData y proyecto
    local_app_data = os.environ.get("LOCALAPPDATA", "")
    if local_app_data:
        candidates.extend(glob.glob(os.path.join(local_app_data, "*", "*", "ua_turnstile_edge.db")))
        candidates.extend(glob.glob(os.path.join(local_app_data, "*", "ua_turnstile_edge.db")))
    
    candidates.extend(glob.glob("**/ua_turnstile_edge.db", recursive=True))

    for path in candidates:
        if os.path.exists(path):
            return os.path.abspath(path)
    return None

def inspect():
    db_path = find_edge_db()
    print("=" * 80)
    print(" UNIVERSIDAD - AUDITORÍA DE PERSISTENCIA EDGE (SQLite WAL)")
    print("=" * 80)

    if not db_path:
        print("\n[!] No se ha generado 'ua_turnstile_edge.db' todavía.")
        print("    Inicia primero la aplicación del Kiosko (flutter run -d windows en apps/kiosk_app).")
        print("=" * 80)
        return

    print(f"\n[+] Archivo de Base de Datos Detectado:\n    {db_path}")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Verificar Modo WAL
    cursor.execute("PRAGMA journal_mode;")
    mode = cursor.fetchone()[0]
    print(f"[+] Modo Transaccional SQLite: {mode.upper()} (Write-Ahead Logging ACTIVO)")

    # 1. Inspeccionar Whitelist
    print("\n" + "-" * 80)
    print(" 1. TABLA: whitelist_users (Lista Blanca Local Desconectada - RAM)")
    print("-" * 80)
    cursor.execute("SELECT student_id, rut, full_name, career, status FROM whitelist_users")
    rows = cursor.fetchall()
    print(f"{'ID ESTUDIANTE':<18} | {'RUT':<13} | {'NOMBRE COMPLETO':<24} | {'ESTADO':<10}")
    print("-" * 80)
    for r in rows:
        print(f"{r[0]:<18} | {r[1]:<13} | {r[2]:<24} | {r[4]:<10}")

    # 2. Inspeccionar Transactional Outbox
    print("\n" + "-" * 80)
    print(" 2. TABLA: outbox_events (Eventos Retenidos / Sincronizados)")
    print("-" * 80)
    cursor.execute("""
        SELECT id, event_uuid, student_id, access_timestamp, access_result, latency_ms, status, payload_hash, ack_hash 
        FROM outbox_events ORDER BY id DESC LIMIT 20
    """)
    events = cursor.fetchall()
    if not events:
        print("    (Sin eventos aún. Realice accesos en el Kiosko para ver transacciones).")
    else:
        print(f"{'ID':<3} | {'ESTADO':<8} | {'RESULTADO':<8} | {'LATENCIA':<8} | {'ESTUDIANTE':<16} | {'HASH SHA-256':<20} | {'ACK CONFIRMACIÓN'}")
        print("-" * 80)
        for e in events:
            short_hash = e[7][:16] + "..." if e[7] else "-"
            short_ack = (e[8][:16] + "...") if e[8] else "(Pendiente ACK)"
            print(f"{e[0]:<3} | {e[6]:<8} | {e[4]:<8} | {str(e[5])+'ms':<8} | {e[2]:<16} | {short_hash:<20} | {short_ack}")

    # Conteo
    cursor.execute("SELECT COUNT(*) FROM outbox_events WHERE status = 'PENDING'")
    pending_cnt = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM outbox_events WHERE status = 'SYNCED'")
    synced_cnt = cursor.fetchone()[0]
    print("-" * 80)
    print(f"RESUMEN OUTBOX: {pending_cnt} PENDING (En cola local) | {synced_cnt} SYNCED (Confirmados en Central Go)")
    print("=" * 80)

    conn.close()

if __name__ == "__main__":
    inspect()
