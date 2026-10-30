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

# Silenciar advertencias de drivers y stream negotiation de OpenCV en Windows
os.environ["OPENCV_LOG_LEVEL"] = "ERROR"
os.environ["OPENCV_VIDEOIO_PRIORITY_MSMF"] = "0"
try:
    cv2.utils.logging.setLogLevel(cv2.utils.logging.LOG_LEVEL_ERROR)
except Exception:
    pass

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(PROJECT_ROOT, "ua_turnstile_edge.db")
CASCADE_PATH = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
YUNET_PATH = os.path.join(PROJECT_ROOT, "scripts", "models", "face_detection_yunet_2023mar.onnx")

yunet_detector = None
if hasattr(cv2, 'FaceDetectorYN') and os.path.exists(YUNET_PATH):
    try:
        yunet_detector = cv2.FaceDetectorYN.create(
            YUNET_PATH, "", (640, 480), score_threshold=0.5, nms_threshold=0.3
        )
        print(f"[+] Detector YuNet ONNX cargado exitosamente: {YUNET_PATH}")
    except Exception as e:
        print(f"[!] Error inicializando YuNet: {e}")
# Inicialización de Modelo MobileFaceNet 512D en OpenCV DNN
CANDIDATE_MODEL_PATHS = [
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "models", "mobilefacenet.onnx"),
    os.path.join(PROJECT_ROOT, "apps", "web_enrollment", "public", "models", "mobilefacenet.onnx"),
]
MODEL_PATH = None
for p in CANDIDATE_MODEL_PATHS:
    if os.path.exists(p):
        MODEL_PATH = p
        break

if MODEL_PATH:
    print(f"[*] Cargando red neuronal MobileFaceNet desde: {MODEL_PATH}")
    net = cv2.dnn.readNetFromONNX(MODEL_PATH)
    net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
    net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)
    print("[+] MobileFaceNet listo para inferencia facial 512D en Kiosko.")
else:
    print("[!] AVISO: No se encontró mobilefacenet.onnx en rutas candidatas.")
    net = None

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
raw_frame_lock = threading.Lock()
latest_live_vector = None
latest_raw_frame = None

def extract_512d_vector(face_img):
    """
    Inferencia de MobileFaceNet 512D con Flip-Fusion usando OpenCV DNN.
    Preprocesamiento idéntico al de vectorExtractor.js (Web):
    - Escala a 112x112
    - Valores de píxel crudos [0, 255] (la red tiene Sub(127.5) y Mul(1/128.0) internos)
    - Pasa recorte directo y espejado horizontalmente (Flip-Fusion)
    - Fusión vectorial: v_fused = v1 + v2
    - Normalización Euclidiana L2 = 1.0 (Invariante a orientación y asimetrías)
    """
    if face_img is None or face_img.size == 0 or net is None:
        return np.zeros(512, dtype=np.float32)

    try:
        # Inferencia 1: Recorte directo
        blob1 = cv2.dnn.blobFromImage(
            face_img,
            scalefactor=1.0,
            size=(112, 112),
            mean=(0, 0, 0),
            swapRB=True,
            crop=False
        )
        net.setInput(blob1)
        v1 = net.forward().flatten().astype(np.float32)

        # Inferencia 2: Recorte espejado horizontalmente (Flip-Fusion)
        face_flipped = cv2.flip(face_img, 1)
        blob2 = cv2.dnn.blobFromImage(
            face_flipped,
            scalefactor=1.0,
            size=(112, 112),
            mean=(0, 0, 0),
            swapRB=True,
            crop=False
        )
        net.setInput(blob2)
        v2 = net.forward().flatten().astype(np.float32)

        # Fusión y normalización L2
        vec = v1 + v2
        norm = np.linalg.norm(vec)
        if norm > 0:
            vec = vec / norm
        else:
            vec = np.zeros(512, dtype=np.float32)

        return vec
    except Exception as e:
        print(f"[!] Error en inferencia MobileFaceNet con Flip-Fusion: {e}")
        return np.zeros(512, dtype=np.float32)

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
    # En Windows, DirectShow (CAP_DSHOW) es nativo, más rápido y no genera advertencias de stream MSMF
    if sys.platform == "win32":
        for idx in [0, 1]:
            try:
                cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW)
                if cap.isOpened():
                    ret, test_f = cap.read()
                    if ret and test_f is not None and test_f.size > 0:
                        print(f"[+] Cámara web conectada exitosamente en índice {idx} (DirectShow).")
                        return cap
                    cap.release()
            except Exception:
                pass

    # Fallback para Linux/macOS o si DirectShow no está disponible
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
    return None

def biometric_ai_worker():
    """
    HILO ASÍNCRONO DE INFERENCIA BIOMÉTRICA (~4-5 Hz)
    Doble estrategia: Detección Dinámica + Fallback Infalible al Encuadre 4:5 (Idéntico a Web).
    Se ejecuta en segundo plano sin frenar el flujo continuo de video a 30 FPS.
    """
    global current_status, latest_live_vector
    
    face_cascade = None
    if hasattr(cv2, 'CascadeClassifier') and os.path.exists(CASCADE_PATH):
        try:
            face_cascade = cv2.CascadeClassifier(CASCADE_PATH)
        except Exception:
            face_cascade = None

    students = load_enrolled_students()
    last_reload_time = time.time()
    THRESHOLD = 0.65

    while True:
        frame = None
        with raw_frame_lock:
            if latest_raw_frame is not None:
                frame = latest_raw_frame.copy()

        if frame is None:
            time.sleep(0.04)
            continue

        now = time.time()
        # Recargar lista blanca de SQLite cada 4 segundos
        if now - last_reload_time > 4.0:
            students = load_enrolled_students()
            last_reload_time = now

        start_eval = time.time()
        h, w = frame.shape[:2]

        # 1. Definir Encuadre Biométrico Estandarizado 4:5 (Coincidente con el visor y la Web de Enrolamiento)
        crop_h = int(min(h * 0.72, w * 0.9))
        crop_w = int(crop_h * 0.8)
        start_x = max(0, (w - crop_w) // 2)
        start_y = max(0, int((h - crop_h) * 0.42))

        # 2. Detección Facial Ligera con YuNet ONNX y Alineamiento Canónico ArcFace (5 Puntos)
        face_detected = False
        face_crop = None

        if yunet_detector is not None:
            try:
                yunet_detector.setInputSize((w, h))
                _, detected_faces = yunet_detector.detect(frame)
                if detected_faces is not None and len(detected_faces) > 0:
                    best_face = detected_faces[0]
                    score = float(best_face[14])
                    if score >= 0.45:
                        face_detected = True
                        # Puntos canónicos ArcFace en 112x112:
                        # Ojo derecho (38.29, 51.70), Ojo izquierdo (73.53, 51.50), Nariz (56.03, 71.74)
                        # Comisura der (41.55, 92.37), Comisura izq (70.73, 92.20)
                        src_pts = np.array([
                            [best_face[4], best_face[5]],
                            [best_face[6], best_face[7]],
                            [best_face[8], best_face[9]],
                            [best_face[10], best_face[11]],
                            [best_face[12], best_face[13]]
                        ], dtype=np.float32)

                        dst_pts = np.array([
                            [38.2946, 51.6963],
                            [73.5318, 51.5014],
                            [56.0252, 71.7366],
                            [41.5493, 92.3655],
                            [70.7299, 92.2041]
                        ], dtype=np.float32)

                        M, _ = cv2.estimateAffinePartial2D(src_pts, dst_pts, method=cv2.LMEDS)
                        if M is not None:
                            face_crop = cv2.warpAffine(frame, M, (112, 112), borderValue=0.0)
            except Exception as e:
                pass

        # Fallback B: Si YuNet no detectó el rostro, usar encuadre 4:5 central estandarizado
        if face_crop is None or face_crop.size == 0:
            fallback_crop = frame[start_y:start_y + crop_h, start_x:start_x + crop_w]
            if fallback_crop.size > 0 and np.std(fallback_crop) > 18:
                face_crop = fallback_crop
                face_detected = True

        detected_state = "IDLE"
        latency_ms = 0

        if face_detected and face_crop is not None and face_crop.size > 0:
            # Inferencia 512D con Flip-Fusion (Sensor Pasivo Puro para Verificación 1:1)
            live_vec = extract_512d_vector(face_crop)
            with vector_lock:
                latest_live_vector = live_vec.tolist()
            latency_ms = int((time.time() - start_eval) * 1000) + 10
            detected_state = "FACE_DETECTED"
        else:
            with vector_lock:
                latest_live_vector = None
            detected_state = "IDLE"

        with status_lock:
            current_status = {
                "state": detected_state,
                "face_detected": face_detected,
                "latency_ms": latency_ms if latency_ms > 0 else 30,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }

        # Cadencia asíncrona: ~5 evaluaciones por segundo (cada 200 ms)
        time.sleep(0.18)

def camera_loop():
    """
    HILO DE CAPTURA Y STREAMING EXCLUSIVO A 30 FPS CONSTANTES
    Garantiza video 100% fluido en Kiosk App sin bloqueos por IA.
    """
    global current_frame_jpeg, latest_raw_frame

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

    try:
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
    except Exception:
        pass

    print("[+] Cámara web lista y activa para streaming continuo a 30 FPS.")

    # Lanzar trabajador asíncrono de inferencia biométrica en segundo plano
    ai_thread = threading.Thread(target=biometric_ai_worker, daemon=True)
    ai_thread.start()
    print("[+] Motor de inferencia biométrica asíncrona iniciado en hilo dedicado.")

    consecutive_failed_frames = 0

    while True:
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
            time.sleep(0.02)
            continue

        consecutive_failed_frames = 0

        # Espejado horizontal
        frame = cv2.flip(frame, 1)

        # Actualizar último frame crudo para el hilo de IA
        with raw_frame_lock:
            latest_raw_frame = frame

        # Codificación JPEG optimizada (calidad 60 genera ~25-30 KB para transferencia ultrarrápida)
        _, jpeg = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 60])
        with frame_lock:
            current_frame_jpeg = jpeg.tobytes()

        # ~30 FPS constantes (~30-33 ms)
        time.sleep(0.025)

class StreamingServer(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        # Silenciar desconexiones normales de clientes (WinError 10054 / BrokenPipe)
        exc_type, exc_val, _ = sys.exc_info()
        if exc_type in (ConnectionResetError, BrokenPipeError, ConnectionAbortedError):
            return
        if isinstance(exc_val, OSError) and getattr(exc_val, 'winerror', None) in (10054, 10053):
            return
        super().handle_error(request, client_address)

class StreamingHandler(BaseHTTPRequestHandler):
    def handle(self):
        try:
            super().handle()
        except (ConnectionResetError, BrokenPipeError, ConnectionAbortedError, OSError):
            pass

    def finish(self):
        try:
            super().finish()
        except (ConnectionResetError, BrokenPipeError, ConnectionAbortedError, OSError):
            pass
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
                self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
                self.send_header("Connection", "keep-alive")
                self.send_header("Keep-Alive", "timeout=5, max=1000")
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
                clean_rut = rut.replace(".", "").replace("-", "").strip().upper()

                conn = sqlite3.connect(DB_PATH)
                cur = conn.cursor()
                cur.execute("PRAGMA journal_mode = WAL;")
                cur.execute("""
                DELETE FROM whitelist_users 
                WHERE rut = ? 
                   OR student_id = ? 
                   OR UPPER(REPLACE(REPLACE(rut, '.', ''), '-', '')) = ?
                """, (rut, student_id, clean_rut))
                conn.commit()
                deleted_rows = cur.rowcount
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

    server = StreamingServer(("127.0.0.1", 5050), StreamingHandler)
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
