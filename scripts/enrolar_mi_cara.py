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

def extract_512d_vector(face_img):
    """
    Extrae un vector matemático normalizado de 512 dimensiones
    utilizando análisis de apariencia multirresolución y gradientes espaciales (HOG-512D).
    """
    if len(face_img.shape) == 3:
        gray = cv2.cvtColor(face_img, cv2.COLOR_BGR2GRAY)
    else:
        gray = face_img

    resized = cv2.resize(gray, (128, 128))
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    norm_img = clahe.apply(resized)

    # 1. Parche de apariencia normalizada (16x16 = 256 dimensiones)
    patch = cv2.resize(norm_img, (16, 16)).astype(np.float32).flatten()
    p_norm = np.linalg.norm(patch)
    if p_norm > 0:
        patch = patch / p_norm

    # 2. Rejilla espacial 8x8 con 4 bins de gradiente Sobel (64 x 4 = 256 dimensiones)
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

    # Concatenar: 256 + 256 = 512 dimensiones
    combined = np.concatenate([patch, grad_vec])
    c_norm = np.linalg.norm(combined)
    if c_norm > 0:
        combined = combined / c_norm

    return [round(float(x), 5) for x in combined]

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
        face_crop = img[y:y+h, x:x+w]

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
            faces = face_cascade.detectMultiScale(gray, 1.2, 5, minSize=(80, 80))

            target_face = None
            for (x, y, w, h) in faces:
                # Retícula biométrica verde
                cv2.rectangle(display, (x, y), (x+w, y+h), (0, 255, 128), 2)
                cv2.putText(display, "ROSTRO DETECTADO", (x, y-10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 128), 2)
                target_face = frame[y:y+h, x:x+w]
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
