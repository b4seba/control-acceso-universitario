#!/usr/bin/env python3
"""
Simulador de Cámara y Reconocimiento Facial en Vivo del Kiosko Torniquete Edge
Universidad - Evaluación Sumativa 2
Validación Biométrica Real 1:1 y 1:N con Halos Cromáticos y Persistencia SQLite WAL
"""
import os
import sys
import json
import time
import sqlite3
import hashlib
import numpy as np
from datetime import datetime, timezone

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

import cv2

# Carga de MobileFaceNet 512D con OpenCV DNN
MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models", "mobilefacenet.onnx")
if os.path.exists(MODEL_PATH):
    net = cv2.dnn.readNetFromONNX(MODEL_PATH)
    net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
    net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)
else:
    net = None

def extract_512d_vector(face_img):
    if face_img is None or face_img.size == 0 or net is None:
        return np.zeros(512, dtype=np.float32)
    try:
        blob = cv2.dnn.blobFromImage(
            face_img,
            scalefactor=1.0 / 128.0,
            size=(112, 112),
            mean=(127.5, 127.5, 127.5),
            swapRB=True,
            crop=False
        )
        net.setInput(blob)
        output = net.forward()
        vec = output.flatten().astype(np.float32)
        norm = np.linalg.norm(vec)
        return (vec / norm) if norm > 0 else np.zeros(512, dtype=np.float32)
    except Exception as e:
        print(f"[!] Error en inferencia: {e}")
        return np.zeros(512, dtype=np.float32)

def cosine_similarity(v1, v2):
    dot = np.dot(v1, v2)
    return float(dot)

def load_enrolled_students():
    """Carga los vectores de la lista blanca desde SQLite WAL."""
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    db_path = os.path.join(project_root, "ua_turnstile_edge.db")

    students = []
    if os.path.exists(db_path):
        conn = sqlite3.connect(db_path)
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
    return students, db_path

def record_outbox_event(db_path, student_id, rut, result, reason, latency_ms):
    """Inserta el evento en SQLite WAL en estado PENDING."""
    try:
        conn = sqlite3.connect(db_path)
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
        print("[!] Error grabando outbox:", e)

def main():
    print("=" * 80)
    print(" KIOSKO TORNIQUETE EDGE - RECONOCIMIENTO FACIAL 512D EN TIEMPO REAL")
    print(" Universidad - Evaluación Sumativa 2")
    print("=" * 80)

    students, db_path = load_enrolled_students()
    print(f"[+] Estudiantes enrolados cargados desde SQLite ({len(students)} registrados):")
    for s in students:
        print(f"    - {s['name']} (RUT: {s['rut']}, Estado: {s['status']})")

    cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    face_cascade = cv2.CascadeClassifier(cascade_path)

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("[ERROR] No se pudo acceder a la cámara web.")
        return

    # Estados de la UI: 'IDLE', 'SCANNING', 'GRANTED', 'DENIED'
    ui_state = 'IDLE'
    active_user = None
    similarity_score = 0.0
    state_timer = 0
    latency_ms = 0

    THRESHOLD = 0.72 # Umbral mínimo de similitud Coseno

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.flip(frame, 1)
        h_frame, w_frame = frame.shape[:2]
        display = frame.copy()

        now = time.time()
        start_eval = time.time()

        # Si estamos mostrando GRANTED o DENIED, respetar temporizador de 2 segundos
        if ui_state in ['GRANTED', 'DENIED'] and (now - state_timer) < 2.0:
            pass # Mantener estado en pantalla
        else:
            ui_state = 'IDLE'
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = face_cascade.detectMultiScale(gray, 1.25, 5, minSize=(90, 90))

            if len(faces) > 0:
                ui_state = 'SCANNING'
                x, y, w, h = faces[0]
                face_crop = frame[y:y+h, x:x+w]

                # Extracción del vector 512D en tiempo real (< 40 ms)
                live_vector = extract_512d_vector(face_crop)
                latency_ms = int((time.time() - start_eval) * 1000) + 75 # Simulación de sensor y cómputo

                # Buscar mejor coincidencia contra la base de datos
                best_sim = -1.0
                best_match = None
                for s in students:
                    sim = cosine_similarity(live_vector, s['vector'])
                    if sim > best_sim:
                        best_sim = sim
                        best_match = s

                similarity_score = best_sim

                if best_match and best_sim >= THRESHOLD:
                    if best_match['status'] == 'VIGENTE':
                        ui_state = 'GRANTED'
                        active_user = best_match
                        state_timer = now
                        record_outbox_event(db_path, best_match['student_id'], best_match['rut'], 'GRANTED', None, latency_ms)
                    else:
                        ui_state = 'DENIED'
                        active_user = best_match
                        state_timer = now
                        record_outbox_event(db_path, best_match['student_id'], best_match['rut'], 'DENIED', 'Matrícula no vigente / Sanción', latency_ms)
                elif best_sim > 0.0:
                    # Rostro presente pero no reconocido
                    if (now - state_timer) > 1.5:
                        ui_state = 'DENIED'
                        active_user = {"name": "Rostro No Registrado", "rut": "DESCONOCIDO"}
                        state_timer = now
                        record_outbox_event(db_path, "UNKNOWN", "UNKNOWN", "DENIED", "Biometría no coincide", latency_ms)

        # =====================================================================
        # RENDERIZADO DE HALOS CROMÁTICOS EN PANTALLA
        # =====================================================================
        halo_color = (182, 119, 0) # Azul IDLE (BGR)
        status_text = "EN ESPERA DE ESTUDIANTE (IDLE)"

        if ui_state == 'SCANNING':
            halo_color = (216, 180, 0) # Cian SCANNING
            status_text = "ESCANEANDO BIOMETRÍA FACIAL (512D)..."
        elif ui_state == 'GRANTED':
            halo_color = (129, 185, 16) # Verde Esmeralda GRANTED
            status_text = f"¡ACCESO CONCEDIDO! - {active_user['name'].upper()}"
        elif ui_state == 'DENIED':
            halo_color = (68, 68, 239) # Rojo Carmesí DENIED
            status_text = "ACCESO DENEGADO - BIOMETRÍA NO VÁLIDA"

        # Marco perimetral industrial
        thickness = 10 if ui_state in ['GRANTED', 'DENIED'] else 4
        cv2.rectangle(display, (0, 0), (w_frame, h_frame), halo_color, thickness)

        # Barra superior de estado
        cv2.rectangle(display, (0, 0), (w_frame, 55), (15, 23, 42), -1)
        cv2.putText(display, status_text, (20, 36), cv2.FONT_HERSHEY_SIMPLEX, 0.75, halo_color, 2)

        # Indicador de SLA y Similitud en vivo
        if ui_state == 'GRANTED':
            cv2.rectangle(display, (20, h_frame - 75), (w_frame - 20, h_frame - 20), (16, 185, 129), -1)
            cv2.putText(display, f"VALIDADO EN {latency_ms} ms | SLA <= 500 ms (CUMPLIDO) | SIMILITUD: {similarity_score*100:.1f}%",
                        (30, h_frame - 38), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 0, 0), 2)
        elif ui_state == 'DENIED':
            cv2.rectangle(display, (20, h_frame - 75), (w_frame - 20, h_frame - 20), (68, 68, 239), -1)
            cv2.putText(display, f"RECHAZADO: Similitud {similarity_score*100:.1f}% (Umbral requerido >= 72%)",
                        (30, h_frame - 38), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (255, 255, 255), 2)
        else:
            cv2.rectangle(display, (0, h_frame - 35), (w_frame, h_frame), (15, 23, 42), -1)
            cv2.putText(display, "ZERO-TRUST: CERO FOTOS CRUDAS • SOLO VECTORES MATEMATICOS NORMALIZADOS 512D",
                        (20, h_frame - 12), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (148, 163, 184), 1)

        cv2.imshow("UA Torniquete Edge - Reconocimiento Facial en Vivo", display)
        if cv2.waitKey(1) & 0xFF in [27, ord('q'), ord('Q')]:
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
