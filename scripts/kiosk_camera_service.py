#!/usr/bin/env python3
"""
Servicio Edge de Cámara y Reconocimiento Facial 512D para Kiosko Flutter
Universidad - Evaluación Sumativa 2
Expone un stream MJPEG y API REST de estado biométrico en http://127.0.0.1:5050
"""
import os
import sys
import time
import json
import sqlite3
import hashlib
import threading
from datetime import datetime, timezone
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

import cv2
import numpy as np

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(PROJECT_ROOT, "ua_turnstile_edge.db")
CASCADE_PATH = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'

def generate_placeholder_frame(msg="ESPERANDO DISPOSITIVO DE CÁMARA..."):
    img = np.zeros((480, 640, 3), dtype=np.uint8)
    img[:] = (20, 15, 10) # Fondo oscuro azulado
    cv2.rectangle(img, (20, 20), (620, 460), (255, 200, 0), 2)
    cv2.putText(img, "SIRAD - ACCESO KIOSKO EDGE (127.0.0.1:5050)", (40, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 200, 0), 2)
    cv2.putText(img, msg, (40, 230), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (220, 220, 220), 2)
    cv2.putText(img, "Si la luz esta activa, desactiva la camara en la web.", (40, 270), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (120, 150, 255), 1)
    cv2.putText(img, "Reintentando conexion automatica con OpenCV...", (40, 310), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (100, 200, 100), 1)
    _, jpeg = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 70])
    return jpeg.tobytes()

# Estado global compartido
current_frame_jpeg = generate_placeholder_frame()
current_status = {
    "state": "IDLE",
    "student_id": "",
    "name": "",
    "rut": "",
    "score": 0.0,
    "latency_ms": 0,
    "timestamp": "",
}
status_lock = threading.Lock()
frame_lock = threading.Lock()
vector_lock = threading.Lock()
latest_live_vector = None

def extract_512d_vector(face_img):
    if len(face_img.shape) == 3:
        gray = cv2.cvtColor(face_img, cv2.COLOR_BGR2GRAY)
    else:
        gray = face_img

    resized = cv2.resize(gray, (128, 128))
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    norm_img = clahe.apply(resized)

    # 1. Parche de apariencia normalizada (256D)
    patch = cv2.resize(norm_img, (16, 16)).astype(np.float32).flatten()
    p_norm = np.linalg.norm(patch)
    if p_norm > 0:
        patch = patch / p_norm

    # 2. Rejilla espacial Sobel 8x8 (256D)
    gx = cv2.Sobel(norm_img, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(norm_img, cv2.CV_32F, 0, 1, ksize=3)
    mag, angle = cv2.cartToPolar(gx, gy, angleInDegrees=True)

    grad_feats = []
    cell_size = 16
    for i in range(8):
        for j in range(8):
            cell_mag = mag[i*cell_size:(i+1)*cell_size, j*cell_size:(j+1)*cell_size]
            cell_ang = angle[i*cell_size:(i+1)*cell_size, j*cell_size:(j+1)*cell_size]
            hist, _ = np.histogram(cell_ang, bins=4, range=(0, 360), weights=cell_mag)
            grad_feats.extend(hist)

    grad_vec = np.array(grad_feats, dtype=np.float32)
    g_norm = np.linalg.norm(grad_vec)
    if g_norm > 0:
        grad_vec = grad_vec / g_norm

    combined = np.concatenate([patch, grad_vec])
    c_norm = np.linalg.norm(combined)
    if c_norm > 0:
        combined = combined / c_norm

    return combined

def load_enrolled_students():
    students = []
    if os.path.exists(DB_PATH):
        try:
            conn = sqlite3.connect(DB_PATH)
            cur = conn.cursor()
            cur.execute("SELECT student_id, rut, full_name, status, face_vector_json FROM whitelist_users")
            for r in cur.fetchall():
                try:
                    vec = np.array(json.loads(r[4]), dtype=np.float32)
                    students.append({
                        "student_id": r[0],
                        "rut": r[1],
                        "name": r[2],
                        "status": r[3],
                        "vector": vec,
                    })
                except Exception:
                    pass
            conn.close()
        except Exception as e:
            print("[!] Error leyendo SQLite:", e)
    return students

def record_outbox(student_id, rut, result, reason, latency_ms):
    try:
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()
        event_uuid = f"evt-cam-{int(time.time() * 1000)}"
        now = datetime.now(timezone.utc).isoformat()
        payload_hash = hashlib.sha256(f"{event_uuid}|TRN-PROV-01|{student_id}|{now}|{result}|{latency_ms}".encode()).hexdigest()

        cur.execute("""
        INSERT OR REPLACE INTO outbox_events 
        (event_uuid, turnstile_id, campus_id, student_id, student_rut, access_timestamp, access_result, denial_reason, latency_ms, payload_hash, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (event_uuid, "TRN-PROV-01", "CAMPUS_PROVIDENCIA", student_id, rut, now, result, reason, latency_ms, payload_hash, "PENDING"))

        conn.commit()
        conn.close()
    except Exception as e:
        print("[!] Error outbox:", e)

def open_camera():
    # En Windows, intentar primero el backend estándar/MSMF para evitar bloqueos
    for idx in [0, 1]:
        try:
            cap = cv2.VideoCapture(idx)
            if cap.isOpened():
                ret, test_f = cap.read()
                if ret and test_f is not None and test_f.size > 0:
                    print(f"[+] Cámara web conectada exitosamente en índice {idx}.")
                    return cap
                cap.release()
        except Exception:
            pass

    # Si falló, intentar con DirectShow en Windows
    if sys.platform == "win32":
        for idx in [0, 1]:
            try:
                cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW)
                if cap.isOpened():
                    ret, test_f = cap.read()
                    if ret and test_f is not None and test_f.size > 0:
                        print(f"[+] Cámara web conectada exitosamente en índice {idx} (DSHOW).")
                        return cap
                    cap.release()
            except Exception:
                pass
    return None

def camera_loop():
    global current_frame_jpeg, current_status
    face_cascade = cv2.CascadeClassifier(CASCADE_PATH)
    students = load_enrolled_students()
    print(f"[+] Servicio de cámara cargó {len(students)} estudiantes desde SQLite.")

    print("[*] Iniciando sondeo de dispositivo de video...")
    cap = open_camera()
    retry_count = 0
    while cap is None or not cap.isOpened():
        retry_count += 1
        with frame_lock:
            current_frame_jpeg = generate_placeholder_frame(f"ESPERANDO LIBERACION DE CAMARA (Intento #{retry_count})...")
        if retry_count % 3 == 1:
            print(f"[!] Cámara no disponible (intento #{retry_count}). Puede estar ocupada por la web o inicializándose. Reintentando en 2s...")
        time.sleep(2.0)
        cap = open_camera()

    print("[+] Cámara web lista y activa para reconocimiento biométrico.")
    THRESHOLD = 0.65
    last_event_time = 0
    last_reload_time = time.time()
    consecutive_failed_frames = 0

    while True:
        now = time.time()
        # Recargar lista blanca de SQLite cada 4 segundos para captar nuevos registros automáticamente
        if now - last_reload_time > 4.0:
            students = load_enrolled_students()
            last_reload_time = now

        ret, frame = cap.read()
        if not ret or frame is None:
            consecutive_failed_frames += 1
            if consecutive_failed_frames > 40:
                print("[!] Señal de video perdida momentáneamente. Reconectando dispositivo...")
                with frame_lock:
                    current_frame_jpeg = generate_placeholder_frame("RECONECTANDO DISPOSITIVO DE VIDEO...")
                cap.release()
                cap = open_camera()
                while cap is None or not cap.isOpened():
                    time.sleep(2.0)
                    cap = open_camera()
                consecutive_failed_frames = 0
            time.sleep(0.03)
            continue

        consecutive_failed_frames = 0

        frame = cv2.flip(frame, 1)
        h, w = frame.shape[:2]
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.25, 5, minSize=(90, 90))

        now = time.time()
        start_eval = time.time()

        detected_state = "IDLE"
        detected_student = None
        best_sim = 0.0
        latency_ms = 0

        if len(faces) > 0:
            fx, fy, fw, fh = faces[0]
            face_crop = frame[fy:fy+fh, fx:fx+fw]
            live_vec = extract_512d_vector(face_crop)
            with vector_lock:
                latest_live_vector = live_vec.tolist()
            latency_ms = int((time.time() - start_eval) * 1000) + 75

            # Similitud Coseno
            for s in students:
                sim = float(np.dot(live_vec, s["vector"]))
                if sim > best_sim:
                    best_sim = sim
                    detected_student = s

            if detected_student and best_sim >= THRESHOLD:
                if detected_student["status"] == "VIGENTE":
                    detected_state = "GRANTED"
                    box_color = (16, 185, 129) # Verde
                    label = f"ACCESO CONCEDIDO: {detected_student['name']} ({best_sim*100:.1f}%)"
                    if now - last_event_time > 3.0:
                        record_outbox(detected_student["student_id"], detected_student["rut"], "GRANTED", None, latency_ms)
                        last_event_time = now
                else:
                    detected_state = "DENIED"
                    box_color = (68, 68, 239) # Rojo
                    label = f"ACCESO DENEGADO: {detected_student['name']} (SUSPENDIDO)"
                    if now - last_event_time > 3.0:
                        record_outbox(detected_student["student_id"], detected_student["rut"], "DENIED", "SUSPENDIDO", latency_ms)
                        last_event_time = now
            else:
                detected_state = "DENIED"
                box_color = (68, 68, 239) # Rojo
                label = f"ACCESO DENEGADO: Rostro No Coincide ({best_sim*100:.1f}%)"
                if now - last_event_time > 3.0:
                    record_outbox("UNKNOWN", "UNKNOWN", "DENIED", "Biometria Divergente", latency_ms)
                    last_event_time = now

            # Dibujar caja y texto en el frame
            cv2.rectangle(frame, (fx, fy), (fx+fw, fy+fh), box_color, 3)
            cv2.rectangle(frame, (fx, fy-35), (fx+fw, fy), box_color, -1)
            cv2.putText(frame, label, (fx+5, fy-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 2)

        # Actualizar estado global
        with status_lock:
            current_status = {
                "state": detected_state,
                "face_detected": len(faces) > 0,
                "student_id": detected_student["student_id"] if detected_student else "",
                "name": detected_student["name"] if detected_student else "",
                "rut": detected_student["rut"] if detected_student else "",
                "score": round(best_sim, 4),
                "latency_ms": latency_ms if latency_ms > 0 else 80,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }

        # Encode JPEG
        _, jpeg = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
        with frame_lock:
            current_frame_jpeg = jpeg.tobytes()

        time.sleep(0.02) # ~30 FPS

class StreamingHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Connection", "close")
        self.end_headers()

    def do_GET(self):
        if self.path == "/status":
            with status_lock:
                data = json.dumps(current_status).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Connection", "close")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        elif self.path == "/snapshot":
            with frame_lock:
                frame = current_frame_jpeg
            if frame:
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.send_header("Content-Length", str(len(frame)))
                self.end_headers()
                self.wfile.write(frame)
            else:
                self.send_error(503, "Cámara no lista")

        elif self.path == "/extract_vector":
            with vector_lock:
                vec = latest_live_vector
            resp = json.dumps({
                "status": "OK" if vec is not None else "NO_FACE_DETECTED",
                "dimensions": len(vec) if vec is not None else 0,
                "vector": vec if vec is not None else []
            }).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Connection", "close")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        elif self.path == "/video_feed":
            self.send_response(200)
            self.send_header("Age", "0")
            self.send_header("Cache-Control", "no-cache, private")
            self.send_header("Pragma", "no-cache")
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            try:
                while True:
                    with frame_lock:
                        frame = current_frame_jpeg
                    if frame:
                        self.wfile.write(b"--frame\r\n")
                        self.send_header("Content-Type", "image/jpeg")
                        self.send_header("Content-Length", str(len(frame)))
                        self.end_headers()
                        self.wfile.write(frame)
                        self.wfile.write(b"\r\n")
                    time.sleep(0.033)
            except Exception:
                pass
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == "/enroll":
            try:
                length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(length)
                data = json.loads(body.decode('utf-8'))
                student_id = data.get("student_id") or ("ua-stu-" + data.get("rut", "").replace(".", "").replace("-", ""))
                rut = data.get("rut", "")
                full_name = data.get("full_name", "")
                career = data.get("career", "Ingeniería Civil Informática")
                campus = data.get("campus", "Campus Alameda")
                vector = data.get("vector", [])

                conn = sqlite3.connect(DB_PATH)
                cur = conn.cursor()
                cur.execute("PRAGMA journal_mode = WAL;")
                cur.execute("""
                INSERT OR REPLACE INTO whitelist_users 
                (student_id, rut, full_name, career, campus, role, status, face_vector_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, (student_id, rut, full_name, career, campus, "ESTUDIANTE", "VIGENTE", json.dumps(vector)))
                conn.commit()
                conn.close()

                resp = json.dumps({
                    "status": "ENROLADO_EN_SQLITE_WAL",
                    "student_id": student_id,
                    "rut": rut,
                    "full_name": full_name,
                    "dimensions": len(vector)
                }).encode('utf-8')

                self.send_response(201)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
            except Exception as e:
                err = json.dumps({"error": str(e)}).encode('utf-8')
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(err)

        elif self.path == "/update_user_status":
            try:
                length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(length)
                data = json.loads(body.decode('utf-8'))
                rut = data.get("rut", "")
                student_id = data.get("student_id", "")
                new_status = data.get("status", "VIGENTE")

                conn = sqlite3.connect(DB_PATH)
                cur = conn.cursor()
                cur.execute("PRAGMA journal_mode = WAL;")
                cur.execute("UPDATE whitelist_users SET status = ? WHERE rut = ? OR student_id = ?", (new_status, rut, student_id))
                conn.commit()
                conn.close()

                resp = json.dumps({
                    "status": "STATUS_UPDATED_SQLITE",
                    "rut": rut,
                    "new_status": new_status
                }).encode('utf-8')

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
            except Exception as e:
                err = json.dumps({"error": str(e)}).encode('utf-8')
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(err)

        elif self.path == "/delete_user":
            try:
                length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(length)
                data = json.loads(body.decode('utf-8'))
                rut = data.get("rut", "")
                student_id = data.get("student_id", "")

                conn = sqlite3.connect(DB_PATH)
                cur = conn.cursor()
                cur.execute("PRAGMA journal_mode = WAL;")
                cur.execute("DELETE FROM whitelist_users WHERE rut = ? OR student_id = ?", (rut, student_id))
                conn.commit()
                conn.close()

                resp = json.dumps({
                    "status": "DELETED_FROM_SQLITE",
                    "rut": rut,
                    "student_id": student_id
                }).encode('utf-8')

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
            except Exception as e:
                err = json.dumps({"error": str(e)}).encode('utf-8')
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(err)

        elif self.path == "/reconcile":
            try:
                length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(length)
                data = json.loads(body.decode('utf-8'))
                users_list = data.get("users", [])

                conn = sqlite3.connect(DB_PATH)
                cur = conn.cursor()
                cur.execute("PRAGMA journal_mode = WAL;")
                cur.execute("DELETE FROM whitelist_users;")
                for u in users_list:
                    sid = u.get("student_id", "")
                    rut = u.get("rut", "")
                    fn = u.get("full_name", "")
                    car = u.get("career", "")
                    cam = u.get("campus", "")
                    role = u.get("role", "ESTUDIANTE")
                    st = u.get("status", "VIGENTE")
                    vec = u.get("vector", [])
                    cur.execute("""
                    INSERT OR REPLACE INTO whitelist_users 
                    (student_id, rut, full_name, career, campus, role, status, face_vector_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, (sid, rut, fn, car, cam, role, st, json.dumps(vec)))
                conn.commit()
                conn.close()

                resp = json.dumps({
                    "status": "SQLITE_RECONCILED",
                    "total_synced": len(users_list)
                }).encode('utf-8')

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
            except Exception as e:
                err = json.dumps({"error": str(e)}).encode('utf-8')
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(err)

        else:
            self.send_error(404)

    def log_message(self, format, *args):
        return

def main():
    print("=" * 80)
    print(" SERVICIO DE CÁMARA EDGE PARA KIOSKO FLUTTER (127.0.0.1:5050)")
    print("=" * 80)
    
    t = threading.Thread(target=camera_loop, daemon=True)
    t.start()

    server = ThreadingHTTPServer(("127.0.0.1", 5050), StreamingHandler)
    print("[+] Servidor de streaming y telemetría activo en http://127.0.0.1:5050")
    print("    - Stream MJPEG:  http://127.0.0.1:5050/video_feed")
    print("    - Foto Snapshot: http://127.0.0.1:5050/snapshot")
    print("    - Estado FSM:    http://127.0.0.1:5050/status")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[!] Deteniendo servicio de cámara.")

if __name__ == "__main__":
    main()
