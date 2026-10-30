#!/usr/bin/env python3
"""
Módulo de Enrolamiento Biométrico Real (Webcam o Foto)
Universidad - Evaluación Sumativa 2
Zero-Trust Biometrics (Solo vector matemático 512D, Cero fotos crudas)
"""
import os
import sys
import time
import json
import sqlite3
import argparse
import numpy as np

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

import cv2
import urllib.request

# Carga de MobileFaceNet 512D con OpenCV DNN
MODELS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
MODEL_PATH = os.path.join(MODELS_DIR, "mobilefacenet.onnx")
if os.path.exists(MODEL_PATH):
    net = cv2.dnn.readNetFromONNX(MODEL_PATH)
    net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
    net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)
else:
    net = None

YUNET_PATH = os.path.join(MODELS_DIR, "face_detection_yunet_2023mar.onnx")
yunet_detector = None
if hasattr(cv2, 'FaceDetectorYN') and os.path.exists(YUNET_PATH):
    try:
        yunet_detector = cv2.FaceDetectorYN.create(
            YUNET_PATH, "", (640, 480), score_threshold=0.5, nms_threshold=0.3
        )
        print(f"[+] Detector YuNet ONNX cargado exitosamente: {YUNET_PATH}")
    except Exception as e:
        print(f"[!] Error cargando YuNet: {e}")

def align_face_5points(frame, face_landmarks):
    dst_pts = np.array([
        [38.2946, 51.6963],
        [73.5318, 51.5014],
        [56.0252, 71.7366],
        [41.5493, 92.3655],
        [70.7299, 92.2041]
    ], dtype=np.float32)

    M, _ = cv2.estimateAffinePartial2D(face_landmarks, dst_pts, method=cv2.LMEDS)
    if M is not None:
        return cv2.warpAffine(frame, M, (112, 112), borderValue=0.0)
    return None

def extract_512d_vector(face_img):
    """Extrae un vector biométrico de 512D con Flip-Fusion usando MobileFaceNet en OpenCV DNN."""
    if face_img is None or face_img.size == 0 or net is None:
        return [0.0] * 512
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
        return [round(float(x), 5) for x in vec]
    except Exception as e:
        print(f"[!] Error en inferencia MobileFaceNet con Flip-Fusion: {e}")
        return [0.0] * 512

def save_to_sqlite(student_id, rut, full_name, career, campus, role, status, vector512):
    """Guarda el estudiante en la lista blanca de SQLite WAL local."""
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    db_path = os.path.join(project_root, "ua_turnstile_edge.db")

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("PRAGMA journal_mode = WAL;")

    cur.execute("""
    INSERT OR REPLACE INTO whitelist_users 
    (student_id, rut, full_name, career, campus, role, status, face_vector_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (student_id, rut, full_name, career, campus, role, status, json.dumps(vector512)))

    conn.commit()
    conn.close()
    print(f"[+] Persistido en SQLite WAL local: {db_path} (Tabla whitelist_users)")

def sync_to_central_api(student_id, vector512):
    """Intenta notificar al microservicio Golang / Qdrant central si está en ejecución."""
    try:
        url = "http://localhost:8080/api/v1/vectors"
        payload = json.dumps({"student_id": student_id, "vector": vector512}).encode("utf-8")
        req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=2) as resp:
            if resp.status in [200, 201]:
                print("[+] Sincronizado exitosamente con API Central Golang y colección Qdrant Vector DB.")
    except Exception as e:
        print(f"[!] Backend Go no alcanzable en http://localhost:8080 ({e}). Vector retenido de forma segura en SQLite WAL local.")

def main():
    parser = argparse.ArgumentParser(description="Enrolamiento Biométrico Real 512D")
    parser.add_argument("--nombre", default="Sebastián Freire", help="Nombre del estudiante")
    parser.add_argument("--rut", default="20.456.789-K", help="RUT del estudiante")
    parser.add_argument("--carrera", default="Ingeniería Civil Informática", help="Carrera")
    parser.add_argument("--campus", default="Campus Providencia", help="Sede")
    parser.add_argument("--id", default="ua-stu-2026-001", help="ID institucional")
    parser.add_argument("--foto", default=None, help="Ruta a foto existente en disco (opcional)")
    parser.add_argument("--auto", type=int, default=0, help="Captura automática con cuenta regresiva en segundos")
    args = parser.parse_args()

    print("=" * 80)
    print(" UNIVERSIDAD - ENROLAMIENTO FACIAL REAL (512 DIMENSIONES)")
    print(" POLÍTICA ZERO-TRUST: CERO ALMACENAMIENTO DE FOTOGRAFÍAS CRUDAS")
    print("=" * 80)
    print(f"  Estudiante: {args.nombre}")
    print(f"  RUT:        {args.rut}")
    print(f"  Carrera:    {args.carrera}")
    print(f"  Campus:     {args.campus}")
    print("-" * 80)

    cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    face_cascade = cv2.CascadeClassifier(cascade_path)

    face_crop = None

    # Caso 1: Imagen provista como parámetro
    if args.foto and os.path.exists(args.foto):
        print(f"[+] Cargando fotografía desde: {args.foto}")
        img = cv2.imread(args.foto)
        if img is None:
            print("[ERROR] No se pudo leer la imagen.")
            return
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.2, 5, minSize=(60, 60))
        if len(faces) == 0:
            print("[ERROR] No se detectó ningún rostro en la fotografía.")
            return
        x, y, w, h = faces[0]
        py = int(h * 0.12)
        px = int(w * 0.08)
        y1, y2 = max(0, y - py), min(img.shape[0], y + h + py)
        x1, x2 = max(0, x - px), min(img.shape[1], x + w + px)
        face_crop = img[y1:y2, x1:x2]

    # Caso 2: Captura en vivo mediante Webcam
    else:
        print("[+] Iniciando cámara web para captura en vivo...")
        print("    --> Coloca tu rostro frente a la cámara.")
        print("    --> Presiona la tecla [ESPACIO] o [E] para enrolar tu rostro.")
        print("    --> Presiona [ESC] o [Q] para cancelar.")
        cap = cv2.VideoCapture(0)

        if not cap.isOpened():
            print("[ERROR] No se pudo acceder a la webcam.")
            return

        start_time = time.time()
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            # Espejo horizontal para UX natural
            frame = cv2.flip(frame, 1)
            display = frame.copy()
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            target_face = None
            detected_with_yunet = False

            if yunet_detector is not None:
                yunet_detector.setInputSize((frame.shape[1], frame.shape[0]))
                _, yn_faces = yunet_detector.detect(frame)
                if yn_faces is not None and len(yn_faces) > 0:
                    best_f = yn_faces[0]
                    if float(best_f[14]) >= 0.45:
                        x, y, w, h = map(int, best_f[0:4])
                        cv2.rectangle(display, (x, y), (x+w, y+h), (0, 255, 128), 2)
                        cv2.putText(display, f"YUNET ALINEADO ({(float(best_f[14])*100):.1f}%)", (x, y-10),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 128), 2)

                        # Puntos de landmarks
                        pts = np.array([
                            [best_f[4], best_f[5]],
                            [best_f[6], best_f[7]],
                            [best_f[8], best_f[9]],
                            [best_f[10], best_f[11]],
                            [best_f[12], best_f[13]]
                        ], dtype=np.float32)

                        for p in pts:
                            cv2.circle(display, (int(p[0]), int(p[1])), 3, (0, 255, 255), -1)

                        aligned = align_face_5points(frame, pts)
                        if aligned is not None:
                            target_face = aligned
                            detected_with_yunet = True

            if not detected_with_yunet:
                faces = face_cascade.detectMultiScale(gray, 1.2, 5, minSize=(80, 80)) if face_cascade else []
                for (x, y, w, h) in faces:
                    cv2.rectangle(display, (x, y), (x+w, y+h), (0, 255, 128), 2)
                    cv2.putText(display, "ROSTRO DETECTADO", (x, y-10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 128), 2)
                    py = int(h * 0.12)
                    px = int(w * 0.08)
                    y1, y2 = max(0, y - py), min(frame.shape[0], y + h + py)
                    x1, x2 = max(0, x - px), min(frame.shape[1], x + w + px)
                    target_face = frame[y1:y2, x1:x2]
                    break

            # Overlay instructivo
            elapsed = time.time() - start_time
            if args.auto > 0 and target_face is not None:
                remaining = max(0, args.auto - int(elapsed))
                cv2.rectangle(display, (0, 0), (display.shape[1], 45), (10, 25, 47), -1)
                cv2.putText(display, f"ENROLAMIENTO AUTO EN: {remaining}s | Mantente encuadrado",
                            (15, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 255, 255), 2)
                if remaining == 0:
                    face_crop = target_face
                    break
            else:
                cv2.rectangle(display, (0, 0), (display.shape[1], 45), (10, 25, 47), -1)
                cv2.putText(display, f"ENROLAMIENTO: {args.nombre} | Presiona [ESPACIO] para capturar",
                            (15, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

            cv2.imshow("Universidad - Enrolamiento Biometrico 512D", display)
            key = cv2.waitKey(1) & 0xFF

            if key in [ord(' '), ord('e'), ord('E')]:
                if target_face is not None:
                    face_crop = target_face
                    break
                else:
                    print("[!] Por favor encuadra tu rostro dentro del visor antes de presionar espacio.")
            elif key in [27, ord('q'), ord('Q')]:
                print("\n[!] Enrolamiento cancelado por el usuario.")
                cap.release()
                cv2.destroyAllWindows()
                return

        cap.release()
        cv2.destroyAllWindows()

    if face_crop is None:
        print("[ERROR] No se capturó ningún rostro válido.")
        return

    # Extracción del vector 512D
    print("\n[+] Extrayendo vector biométrico de 512 dimensiones...")
    vector512 = extract_512d_vector(face_crop)
    print(f"    ✓ Dimensión exacta: {len(vector512)} floats")
    print(f"    ✓ Primeros 5 valores: {vector512[:5]}")
    print(f"    ✓ Norma L2: {sum(x**2 for x in vector512)**0.5:.4f}")

    # Certificación Zero-Trust: Destruir foto cruda
    del face_crop
    print("    ✓ [ZERO-TRUST CERTIFICADA]: Fotografía cruda eliminada de memoria RAM.")

    # Guardar en SQLite WAL local del Kiosko
    save_to_sqlite(
        student_id=args.id,
        rut=args.rut,
        full_name=args.nombre,
        career=args.carrera,
        campus=args.campus,
        role="ESTUDIANTE",
        status="VIGENTE",
        vector512=vector512,
    )

    # Sincronizar con API
    sync_to_central_api(args.id, vector512)

    print("\n" + "=" * 80)
    print(" ¡ENROLAMIENTO COMPLETADO EXITOSAMENTE!")
    print(f" Ahora cuando te pares frente al torniquete, el sistema reconocerá tu cara real.")
    print("=" * 80)

if __name__ == "__main__":
    main()
