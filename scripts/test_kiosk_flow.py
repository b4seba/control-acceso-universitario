import sqlite3

for db_path in [
    'ua_turnstile_edge.db',
    'apps/kiosk_app/.dart_tool/sqflite_common_ffi/databases/ua_turnstile_edge.db'
]:
    print("Checking DB:", db_path)
    try:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        q = '21.460.709-3'
        clean = '214607093'
        cur.execute('''
            SELECT student_id, rut, full_name, status 
            FROM whitelist_users 
            WHERE student_id = ? OR UPPER(REPLACE(REPLACE(rut, '.', ''), '-', '')) = ?
        ''', (q, clean))
        rows = cur.fetchall()
        print("  Found rows for 21.460.709-3:", rows)
        
        # Test student_id 'ua-stu-2026-001'
        cur.execute('''
            SELECT student_id, rut, full_name, status 
            FROM whitelist_users 
            WHERE student_id = ? OR UPPER(REPLACE(REPLACE(rut, '.', ''), '-', '')) = ?
        ''', ('ua-stu-2026-001', 'UASTU2026001'))
        rows2 = cur.fetchall()
        print("  Found rows for ua-stu-2026-001:", rows2)
    except Exception as e:
        print("  Error:", e)
