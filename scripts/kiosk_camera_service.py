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

# Modelos Anti-Spoofing (Silent-Face-Anti-Spoofing: MiniFASNetV2 2.7x + MiniFASNetV1SE 4.0x)
ANTISPOOF_SPECS = [
    ("2.7_80x80_MiniFASNetV2.onnx", 2.7),
    ("4_0_0_80x80_MiniFASNetV1SE.onnx", 4.0),
]
antispoof_nets = []
for model_file, scale in ANTISPOOF_SPECS:
    for candidate_dir in [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "models"),
        os.path.join(PROJECT_ROOT, "scripts", "models"),
    ]:
        model_full_path = os.path.join(candidate_dir, model_file)
        if os.path.exists(model_full_path):
            try:
                as_net = cv2.dnn.readNetFromONNX(model_full_path)
                as_net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
                as_net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)
                antispoof_nets.append((model_file, scale, as_net))
                print(f"[+] Modelo Anti-Spoofing cargado ({scale}x): {model_full_path}")
            except Exception as e:
                print(f"[!] Error cargando modelo Anti-Spoofing {model_file}: {e}")
            break

if not antispoof_nets:
    print("[!] AVISO: No se cargaron modelos Anti-Spoofing ONNX; operando solo con detección YuNet.")

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
camera_enabled = True
current_frame_jpeg = generate_placeholder_frame()
current_status = {
    "state": "IDLE",
    "student_id": "",
    "name": "",
    "rut": "",
    "score": 0.0,
    "latency_ms": 0,
    "face_detected": False,
    "is_live": False,
    "liveness_score": 0.0,
    "spoof_reason": "",
    "camera_enabled": True,
    "timestamp": "",
}
status_lock = threading.Lock()
frame_lock = threading.Lock()
vector_lock = threading.Lock()
raw_frame_lock = threading.Lock()
camera_state_lock = threading.Lock()
latest_live_vector = None
latest_liveness_info = {"is_live": False, "liveness_score": 0.0, "spoof_reason": ""}
latest_raw_frame = None


def is_camera_enabled():
    with camera_state_lock:
        return camera_enabled


def set_camera_enabled(enabled: bool):
    global camera_enabled, latest_live_vector, latest_liveness_info, latest_raw_frame, current_frame_jpeg, current_status
    with camera_state_lock:
        camera_enabled = enabled
    if not enabled:
        with raw_frame_lock:
            latest_raw_frame = None
        with vector_lock:
            latest_live_vector = None
            latest_liveness_info = {"is_live": False, "liveness_score": 0.0, "spoof_reason": ""}
        with frame_lock:
            current_frame_jpeg = generate_placeholder_frame("CAMARA DESACTIVADA POR EL OPERADOR")
        with status_lock:
            current_status = {
                "state": "CAMERA_OFF",
                "face_detected": False,
                "is_live": False,
                "liveness_score": 0.0,
                "spoof_reason": "",
                "camera_enabled": False,
                "latency_ms": 0,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
    else:
        with frame_lock:
            current_frame_jpeg = generate_placeholder_frame("ACTIVANDO CAMARA WEB...")
        with status_lock:
            current_status = {
                "state": "IDLE",
                "face_detected": False,
                "is_live": False,
                "liveness_score": 0.0,
                "spoof_reason": "",
                "camera_enabled": True,
                "latency_ms": 0,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }

def _get_antispoof_crop_box(src_w, src_h, bbox, scale):
    """Expande el bounding box facial alrededor de su centro respetando los bordes."""
    x, y, box_w, box_h = bbox
    safe_w = max(float(box_w), 1.0)
    safe_h = max(float(box_h), 1.0)
    bounded_scale = min((src_h - 1) / safe_h, min((src_w - 1) / safe_w, scale))

    new_w = safe_w * bounded_scale
    new_h = safe_h * bounded_scale
    cx = float(x) + safe_w / 2.0
    cy = float(y) + safe_h / 2.0

    x1 = cx - new_w / 2.0
    y1 = cy - new_h / 2.0
    x2 = cx + new_w / 2.0
    y2 = cy + new_h / 2.0

    if x1 < 0:
        x2 -= x1
        x1 = 0
    if y1 < 0:
        y2 -= y1
        y1 = 0
    if x2 > src_w - 1:
        x1 -= x2 - src_w + 1
        x2 = src_w - 1
    if y2 > src_h - 1:
        y1 -= y2 - src_h + 1
        y2 = src_h - 1

    return int(max(0, x1)), int(max(0, y1)), int(min(src_w - 1, x2)), int(min(src_h - 1, y2))

def evaluate_liveness(frame_bgr, bbox):
    """
    Evalúa prueba de vida pasiva (Anti-Spoofing) mediante MiniFASNetV2 (2.7x) + V1SE (4.0x).
    Preprocesamiento oficial Silent-Face-Anti-Spoofing: BGR crudo [0, 255] a 80x80.
    Clases: 0=Paper Photo, 1=Real Face, 2=Screen Photo.
    """
    h, w = frame_bgr.shape[:2]
    _, _, box_w, box_h = bbox

    if box_w < 64 or box_h < 64:
        return False, 0.0, "FACE_TOO_SMALL"

    # Evitar fotografías pegadas al lente para ocultar los bordes de la pantalla
    if box_h > h * 0.78 or box_w > w * 0.78:
        return False, 0.0, "CLOSE_FRAME_SPOOF_RISK"

    if not antispoof_nets:
        return True, 1.0, ""

    probs_list = []
    for _, scale, as_net in antispoof_nets:
        x1, y1, x2, y2 = _get_antispoof_crop_box(w, h, bbox, scale)
        crop = frame_bgr[y1:y2 + 1, x1:x2 + 1]
        if crop.size == 0:
            continue
        blob = cv2.dnn.blobFromImage(
            crop,
            scalefactor=1.0,
            size=(80, 80),
            mean=(0, 0, 0),
            swapRB=False,
            crop=False,
        )
        as_net.setInput(blob)
        logits = as_net.forward()[0]
        exp_logits = np.exp(logits - np.max(logits))
        probs = exp_logits / np.sum(exp_logits)
        probs_list.append(probs)

    if not probs_list:
        return False, 0.0, "LIVENESS_CROP_INVALID"

    avg_probs = np.mean(probs_list, axis=0)
    min_real = min(float(p[1]) for p in probs_list)
    paper_score = float(avg_probs[0])
    real_score = float(avg_probs[1])
    screen_score = float(avg_probs[2])

    is_live = (
        real_score >= 0.65
        and min_real >= 0.50
        and real_score > paper_score
        and real_score > screen_score
    )
    if is_live:
        return True, real_score, ""

    reason = "SCREEN_REPLAY_DETECTED" if screen_score >= paper_score else "PAPER_PRINT_DETECTED"
    return False, real_score, reason

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
    HILO ASÍNCRONO DE INFERENCIA BIOMÉTRICA + ANTI-SPOOFING (~5 Hz)
    Exige detección real YuNet (5 puntos), evalúa prueba de vida pasiva (MiniFASNet)
    y extrae descriptor 512D únicamente para rostros reales vivos.
    """
    global current_status, latest_live_vector, latest_liveness_info

    while True:
        if not is_camera_enabled():
            with vector_lock:
                latest_live_vector = None
                latest_liveness_info = {"is_live": False, "liveness_score": 0.0, "spoof_reason": ""}
            with status_lock:
                current_status = {
                    "state": "CAMERA_OFF",
                    "face_detected": False,
                    "is_live": False,
                    "liveness_score": 0.0,
                    "spoof_reason": "",
                    "camera_enabled": False,
                    "latency_ms": 0,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
            time.sleep(0.2)
            continue

        frame = None
        with raw_frame_lock:
            if latest_raw_frame is not None:
                frame = latest_raw_frame.copy()

        if frame is None:
            time.sleep(0.04)
            continue

        start_eval = time.time()
        h, w = frame.shape[:2]

        # Detección facial estricta con YuNet ONNX (sin fallback ciego)
        face_detected = False
        face_crop = None
        face_bbox = None

        if yunet_detector is not None:
            try:
                yunet_detector.setInputSize((w, h))
                _, detected_faces = yunet_detector.detect(frame)
                if detected_faces is not None and len(detected_faces) > 0:
                    best_face = detected_faces[0]
                    score = float(best_face[14])
                    if score >= 0.55:
                        face_detected = True
                        face_bbox = [
                            float(best_face[0]),
                            float(best_face[1]),
                            float(best_face[2]),
                            float(best_face[3]),
                        ]
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
            except Exception:
                pass

        detected_state = "IDLE"
        latency_ms = 0
        is_live = False
        liveness_score = 0.0
        spoof_reason = ""

        if face_detected and face_crop is not None and face_crop.size > 0 and face_bbox is not None:
            is_live, liveness_score, spoof_reason = evaluate_liveness(frame, face_bbox)

            if is_live:
                live_vec = extract_512d_vector(face_crop)
                with vector_lock:
                    latest_live_vector = live_vec.tolist()
                    latest_liveness_info = {
                        "is_live": True,
                        "liveness_score": round(liveness_score, 4),
                        "spoof_reason": "",
                    }
                detected_state = "FACE_DETECTED"
            else:
                # Fail-closed: nunca entregar vector facial si se detectó ataque de presentación
                with vector_lock:
                    latest_live_vector = None
                    latest_liveness_info = {
                        "is_live": False,
                        "liveness_score": round(liveness_score, 4),
                        "spoof_reason": spoof_reason,
                    }
                detected_state = "SPOOF_DETECTED"

            latency_ms = int((time.time() - start_eval) * 1000) + 10
        else:
            with vector_lock:
                latest_live_vector = None
                latest_liveness_info = {"is_live": False, "liveness_score": 0.0, "spoof_reason": ""}
            detected_state = "IDLE"

        with status_lock:
            current_status = {
                "state": detected_state,
                "face_detected": face_detected,
                "is_live": is_live,
                "liveness_score": round(liveness_score, 4),
                "spoof_reason": spoof_reason,
                "camera_enabled": is_camera_enabled(),
                "latency_ms": latency_ms if latency_ms > 0 else 30,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }

        # Cadencia asíncrona: ~5 evaluaciones por segundo (cada 200 ms)
        time.sleep(0.18)

def camera_loop():
    """
    HILO DE CAPTURA Y STREAMING EXCLUSIVO A 30 FPS CONSTANTES
    Garantiza video 100% fluido en Kiosk App sin bloqueos por IA y liberación real del hardware.
    """
    global current_frame_jpeg, latest_raw_frame, latest_live_vector

    ai_thread = threading.Thread(target=biometric_ai_worker, daemon=True)
    ai_thread.start()
    print("[+] Motor de inferencia biométrica asíncrona iniciado en hilo dedicado.")

    cap = None
    retry_count = 0
    consecutive_failed_frames = 0

    while True:
        # Si el operador desactivó la cámara, liberar hardware inmediatamente
        if not is_camera_enabled():
            if cap is not None:
                try:
                    cap.release()
                except Exception:
                    pass
                cap = None
                print("[*] Cámara física liberada y apagada por solicitud del Kiosko.")
            with raw_frame_lock:
                latest_raw_frame = None
            with vector_lock:
                latest_live_vector = None
            retry_count = 0
            consecutive_failed_frames = 0
            time.sleep(0.15)
            continue

        # Abrir dispositivo si aún no está abierto
        if cap is None or not cap.isOpened():
            if retry_count == 0:
                print("[*] Iniciando sondeo de dispositivo de video...")
            cap = open_camera()
            if cap is None or not cap.isOpened():
                retry_count += 1
                with frame_lock:
                    current_frame_jpeg = generate_placeholder_frame(f"ESPERANDO LIBERACION DE CAMARA (Intento #{retry_count})...")
                if retry_count % 3 == 1:
                    print(f"[!] Cámara no disponible (intento #{retry_count}). Reintentando en 2s...")
                for _ in range(20):
                    if not is_camera_enabled():
                        break
                    time.sleep(0.1)
                continue

            retry_count = 0
            consecutive_failed_frames = 0
            try:
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                cap.set(cv2.CAP_PROP_FPS, 30)
            except Exception:
                pass
            print("[+] Cámara web lista y activa para streaming continuo a 30 FPS.")

        ret, frame = cap.read()
        if not ret or frame is None:
            consecutive_failed_frames += 1
            if consecutive_failed_frames > 40:
                print("[!] Señal de video perdida momentáneamente. Reconectando dispositivo...")
                with frame_lock:
                    current_frame_jpeg = generate_placeholder_frame("RECONECTANDO DISPOSITIVO DE VIDEO...")
                try:
                    cap.release()
                except Exception:
                    pass
                cap = None
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
                liveness = dict(latest_liveness_info)
            is_live = bool(liveness.get("is_live", False))
            spoof_reason = liveness.get("spoof_reason", "")
            liveness_score = float(liveness.get("liveness_score", 0.0))

            if vec is not None and is_live:
                payload = {
                    "status": "OK",
                    "is_live": True,
                    "liveness_score": liveness_score,
                    "spoof_reason": "",
                    "dimensions": len(vec),
                    "vector": vec,
                }
            elif spoof_reason:
                payload = {
                    "status": "SPOOF_DETECTED",
                    "is_live": False,
                    "liveness_score": liveness_score,
                    "spoof_reason": spoof_reason,
                    "dimensions": 0,
                    "vector": [],
                }
            else:
                payload = {
                    "status": "NO_FACE_DETECTED",
                    "is_live": False,
                    "liveness_score": 0.0,
                    "spoof_reason": "",
                    "dimensions": 0,
                    "vector": [],
                }

            resp = json.dumps(payload).encode("utf-8")
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

        elif self.path == "/camera/stop":
            set_camera_enabled(False)
            resp = json.dumps({
                "status": "CAMERA_STOPPED",
                "camera_enabled": False,
            }).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Connection", "close")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

        elif self.path == "/camera/start":
            set_camera_enabled(True)
            resp = json.dumps({
                "status": "CAMERA_STARTED",
                "camera_enabled": True,
            }).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Connection", "close")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

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
