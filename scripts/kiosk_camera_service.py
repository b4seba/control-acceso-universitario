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
from http.server import HTTPServer, BaseHTTPRequestHandler

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

# Estado global compartido
current_frame_jpeg = None
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

def camera_loop():
    global current_frame_jpeg, current_status
    face_cascade = cv2.CascadeClassifier(CASCADE_PATH)
    students = load_enrolled_students()
    print(f"[+] Servicio de cámara cargó {len(students)} estudiantes desde SQLite.")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] No se pudo abrir la cámara web en índice 0.")
        return

    THRESHOLD = 0.65
    last_event_time = 0
    last_reload_time = time.time()

    while True:
        now = time.time()
        # Recargar lista blanca de SQLite cada 4 segundos para captar nuevos registros automáticamente
        if now - last_reload_time > 4.0:
            students = load_enrolled_students()
            last_reload_time = now

        ret, frame = cap.read()
        if not ret:
            time.sleep(0.03)
            continue

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
    def do_GET(self):
        # Habilitar CORS
        if self.path == "/status":
            with status_lock:
                data = json.dumps(current_status).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
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
                self.send_header("Content-Length", str(len(frame)))
                self.end_headers()
                self.wfile.write(frame)
            else:
                self.send_error(503, "Cámara no lista")

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
                    time.sleep(0.033) # 30 FPS
            except Exception:
                pass
        else:
            self.send_error(404)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

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
                self.send_header("Content-Length", str(len(resp)))
                self.end_headers()
                self.wfile.write(resp)
            except Exception as e:
                err = json.dumps({"error": str(e)}).encode('utf-8')
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(err)
        else:
            self.send_error(404)

    def log_message(self, format, *args):
        return # Silenciar logs HTTP ruidosos

def main():
    print("=" * 80)
    print(" SERVICIO DE CÁMARA EDGE PARA KIOSKO FLUTTER (127.0.0.1:5050)")
    print("=" * 80)
    
    t = threading.Thread(target=camera_loop, daemon=True)
    t.start()

    server = HTTPServer(("127.0.0.1", 5050), StreamingHandler)
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
