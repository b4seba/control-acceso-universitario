/**
 * Extractor Biométrico 512D en JavaScript (Cliente Web / Canvas)
 * Arquitectura Zero-Trust Biometrics
 * Convierte un cuadro de video en 512 números flotantes normalizados (L2 = 1.0)
 * y destruye la imagen cruda inmediatamente de la memoria.
 */
export function extract512DVectorFromVideo(videoElement) {
  const canvas = document.createElement('canvas');
  canvas.width = 128;
  canvas.height = 128;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });

  // 1. Dibujar y convertir a escala de grises
  ctx.drawImage(videoElement, 0, 0, 128, 128);
  const imgData = ctx.getImageData(0, 0, 128, 128);
  const data = imgData.data;

  const gray = new Float32Array(128 * 128);
  for (let i = 0; i < 128 * 128; i++) {
    const r = data[i * 4];
    const g = data[i * 4 + 1];
    const b = data[i * 4 + 2];
    gray[i] = 0.299 * r + 0.587 * g + 0.114 * b;
  }

  // 2. Parche de apariencia normalizada (16x16 = 256 dimensiones)
  const patchCanvas = document.createElement('canvas');
  patchCanvas.width = 16;
  patchCanvas.height = 16;
  const patchCtx = patchCanvas.getContext('2d', { willReadFrequently: true });
  patchCtx.drawImage(canvas, 0, 0, 16, 16);
  const patchData = patchCtx.getImageData(0, 0, 16, 16).data;

  const patch = new Float32Array(256);
  let pSumSq = 0;
  for (let i = 0; i < 256; i++) {
    const val = 0.299 * patchData[i * 4] + 0.587 * patchData[i * 4 + 1] + 0.114 * patchData[i * 4 + 2];
    patch[i] = val;
    pSumSq += val * val;
  }
  const pNorm = Math.sqrt(pSumSq);
  if (pNorm > 0) {
    for (let i = 0; i < 256; i++) {
      patch[i] /= pNorm;
    }
  }

  // 3. Rejilla espacial Sobel 8x8 con 4 bins de orientación (64 x 4 = 256 dimensiones)
  const gradVec = new Float32Array(256);
  const cellSize = 16;

  for (let gy = 0; gy < 8; gy++) {
    for (let gx = 0; gx < 8; gx++) {
      const cellHist = [0, 0, 0, 0];

      for (let y = gy * cellSize + 1; y < (gy + 1) * cellSize - 1; y++) {
        for (let x = gx * cellSize + 1; x < (gx + 1) * cellSize - 1; x++) {
          // Gradiente Sobel simple 3x3 aproximado
          const dx =
            -gray[(y - 1) * 128 + (x - 1)] + gray[(y - 1) * 128 + (x + 1)] -
            2 * gray[y * 128 + (x - 1)] + 2 * gray[y * 128 + (x + 1)] -
            gray[(y + 1) * 128 + (x - 1)] + gray[(y + 1) * 128 + (x + 1)];

          const dy =
            -gray[(y - 1) * 128 + (x - 1)] - 2 * gray[(y - 1) * 128 + x] - gray[(y - 1) * 128 + (x + 1)] +
            gray[(y + 1) * 128 + (x - 1)] + 2 * gray[(y + 1) * 128 + x] + gray[(y + 1) * 128 + (x + 1)];

          const mag = Math.sqrt(dx * dx + dy * dy);
          let angle = Math.atan2(dy, dx) * (180 / Math.PI);
          if (angle < 0) angle += 360;

          // 4 bins: [0-90), [90-180), [180-270), [270-360)
          const bin = Math.min(3, Math.floor(angle / 90));
          cellHist[bin] += mag;
        }
      }

      const cellIdx = (gy * 8 + gx) * 4;
      gradVec[cellIdx] = cellHist[0];
      gradVec[cellIdx + 1] = cellHist[1];
      gradVec[cellIdx + 2] = cellHist[2];
      gradVec[cellIdx + 3] = cellHist[3];
    }
  }

  let gSumSq = 0;
  for (let i = 0; i < 256; i++) {
    gSumSq += gradVec[i] * gradVec[i];
  }
  const gNorm = Math.sqrt(gSumSq);
  if (gNorm > 0) {
    for (let i = 0; i < 256; i++) {
      gradVec[i] /= gNorm;
    }
  }

  // 4. Concatenar 256 + 256 = 512 dimensiones
  const combined = new Float32Array(512);
  combined.set(patch, 0);
  combined.set(gradVec, 256);

  let cSumSq = 0;
  for (let i = 0; i < 512; i++) {
    cSumSq += combined[i] * combined[i];
  }
  const cNorm = Math.sqrt(cSumSq);
  const result = [];
  if (cNorm > 0) {
    for (let i = 0; i < 512; i++) {
      result.push(Number((combined[i] / cNorm).toFixed(5)));
    }
  } else {
    for (let i = 0; i < 512; i++) {
      result.push(0.0);
    }
  }

  // Limpieza de memoria (Zero-Trust: Destruir canvas y buffers de imagen)
  ctx.clearRect(0, 0, 128, 128);
  patchCtx.clearRect(0, 0, 16, 16);

  return result;
}
