#!/usr/bin/env python3
"""
Genera la versión cuantizada INT8 (QUInt8) y pre-comprimida Gzip de MobileFaceNet
para el portal web (web_enrollment), reduciendo la transferencia en red ~7x
(de 261 MB a ~37 MB gzip) manteniendo similitud coseno >= 0.992 con el modelo FP32
utilizado en el kiosko Edge.

Uso:
  uv run --with onnx --with onnxruntime --with numpy python scripts/quantize_web_model.py
"""
import gzip
import os
import shutil
import sys
import numpy as np
import onnxruntime as ort
from onnxruntime.quantization import QuantType, quantize_dynamic

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_MODEL = os.path.join(PROJECT_ROOT, "scripts", "models", "mobilefacenet.onnx")
WEB_MODELS_DIR = os.path.join(PROJECT_ROOT, "apps", "web_enrollment", "public", "models")
OUT_MODEL = os.path.join(WEB_MODELS_DIR, "mobilefacenet.int8.onnx")
OUT_MODEL_GZ = OUT_MODEL + ".gz"


def verify_cosine_parity(fp32_path: str, int8_path: str) -> float:
    sess_fp32 = ort.InferenceSession(fp32_path, providers=["CPUExecutionProvider"])
    sess_int8 = ort.InferenceSession(int8_path, providers=["CPUExecutionProvider"])

    rng = np.random.default_rng(42)
    yy, xx = np.mgrid[0:112, 0:112]
    base = np.zeros((1, 3, 112, 112), dtype=np.float32)
    base[0, 0] = 180 - 0.5 * ((xx - 56) ** 2 + (yy - 56) ** 2) ** 0.5
    base[0, 1] = 140 - 0.4 * ((xx - 56) ** 2 + (yy - 56) ** 2) ** 0.5
    base[0, 2] = 120 - 0.3 * ((xx - 56) ** 2 + (yy - 56) ** 2) ** 0.5

    sims = []
    for _ in range(3):
        sample = np.clip(base + rng.normal(0, 8, base.shape), 0, 255).astype(np.float32)
        v1 = sess_fp32.run(None, {sess_fp32.get_inputs()[0].name: sample})[0].flatten()
        v2 = sess_int8.run(None, {sess_int8.get_inputs()[0].name: sample})[0].flatten()
        v1 = v1 / np.linalg.norm(v1)
        v2 = v2 / np.linalg.norm(v2)
        sims.append(float(np.dot(v1, v2)))
    return min(sims)


def main() -> int:
    if not os.path.exists(SRC_MODEL):
        print(f"[ERROR] No existe el modelo fuente: {SRC_MODEL}", file=sys.stderr)
        return 1

    os.makedirs(WEB_MODELS_DIR, exist_ok=True)
    print(f"[*] Cuantizando {SRC_MODEL} -> {OUT_MODEL} ...")
    quantize_dynamic(SRC_MODEL, OUT_MODEL, weight_type=QuantType.QUInt8)

    min_sim = verify_cosine_parity(SRC_MODEL, OUT_MODEL)
    print(f"[+] Paridad coseno mínima FP32 vs INT8: {min_sim:.6f}")
    if min_sim < 0.98:
        print(f"[ERROR] Paridad coseno inesperadamente baja: {min_sim}", file=sys.stderr)
        return 1

    print(f"[*] Pre-comprimiendo {OUT_MODEL} -> {OUT_MODEL_GZ} (gzip -6) ...")
    with open(OUT_MODEL, "rb") as f_in, gzip.open(OUT_MODEL_GZ, "wb", compresslevel=6) as f_out:
        shutil.copyfileobj(f_in, f_out)

    # Igualar mtime para que nginx gzip_static acepte el par sin discrepancias
    st = os.stat(OUT_MODEL)
    os.utime(OUT_MODEL_GZ, (st.st_atime, st.st_mtime))

    raw_mb = os.path.getsize(OUT_MODEL) / (1024 * 1024)
    gz_mb = os.path.getsize(OUT_MODEL_GZ) / (1024 * 1024)
    print(f"[✓] Listo: {raw_mb:.2f} MiB raw | {gz_mb:.2f} MiB gzip")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
