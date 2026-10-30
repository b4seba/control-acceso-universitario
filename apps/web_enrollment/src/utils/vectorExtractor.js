import * as ort from 'onnxruntime-web';

// Cargar WebAssembly desde CDN coincidente con la versión instalada (1.31.1)
ort.env.wasm.wasmPaths = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.31.1/dist/';
ort.env.wasm.numThreads = 1;

let mobileNetSession = null;
let yunetSession = null;
let isInitializing = false;

const STRIDES = [8, 16, 32];

// Decodificador nativo de YuNet Face Detector
function decodeYuNet(results, scoreThresh = 0.45) {
  const faces = [];
  
  for (let i = 0; i < STRIDES.length; i++) {
    const stride = STRIDES[i];
    const cols = Math.floor(640 / stride);
    const rows = Math.floor(640 / stride);

    const cls = results[`cls_${stride}`]?.data;
    const obj = results[`obj_${stride}`]?.data;
    const bbox = results[`bbox_${stride}`]?.data;
    const kps = results[`kps_${stride}`]?.data;

    if (!cls || !obj || !bbox || !kps) continue;

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const idx = r * cols + c;
        const clsScore = Math.min(Math.max(cls[idx], 0), 1);
        const objScore = Math.min(Math.max(obj[idx], 0), 1);
        const score = Math.sqrt(clsScore * objScore);

        if (score < scoreThresh) continue;

        const cx = (c + bbox[idx * 4 + 0]) * stride;
        const cy = (r + bbox[idx * 4 + 1]) * stride;
        const w = Math.exp(bbox[idx * 4 + 2]) * stride;
        const h = Math.exp(bbox[idx * 4 + 3]) * stride;

        const x1 = cx - w / 2;
        const y1 = cy - h / 2;

        const landmarks = [];
        for (let n = 0; n < 5; n++) {
          const kx = (kps[idx * 10 + 2 * n] + c) * stride;
          const ky = (kps[idx * 10 + 2 * n + 1] + r) * stride;
          landmarks.push({ x: kx, y: ky });
        }

        faces.push({
          box: { x: x1, y: y1, width: w, height: h },
          score,
          landmarks: {
            rightEye: landmarks[0], // Ojo derecho del sujeto (izquierda de la pantalla)
            leftEye: landmarks[1],  // Ojo izquierdo del sujeto (derecha de la pantalla)
            nose: landmarks[2],
            rightMouth: landmarks[3],
            leftMouth: landmarks[4],
          }
        });
      }
    }
  }

  faces.sort((a, b) => b.score - a.score);
  return faces;
}

// Inicialización de modelos (MobileFaceNet + YuNet Face Detector)
export async function initMobileFaceNet() {
  if (mobileNetSession && yunetSession) return { mobileNetSession, yunetSession };
  if (isInitializing) return;
  isInitializing = true;

  const startTime = performance.now();
  console.log('[FacePipeline] Cargando MobileFaceNet y YuNet ONNX en WebAssembly...');

  try {
    if (!mobileNetSession) {
      mobileNetSession = await ort.InferenceSession.create('/models/mobilefacenet.onnx', {
        executionProviders: ['wasm'],
        graphOptimizationLevel: 'all',
      });
    }
    if (!yunetSession) {
      yunetSession = await ort.InferenceSession.create('/models/face_detection_yunet_2023mar.onnx', {
        executionProviders: ['wasm'],
        graphOptimizationLevel: 'all',
      });
    }
    const elapsedMs = (performance.now() - startTime).toFixed(1);
    console.log(`[FacePipeline] Modelos cargados exitosamente en ${elapsedMs} ms`);
  } catch (error) {
    const elapsedMs = (performance.now() - startTime).toFixed(1);
    console.error(`[FacePipeline] Error inicializando modelos ONNX tras ${elapsedMs} ms:`, error);
  } finally {
    isInitializing = false;
  }
  return { mobileNetSession, yunetSession };
}

// Extraer vector 512D con Detección Facial YuNet + Alineamiento Canónico + Flip-Fusion
export async function extract512DVectorFromVideo(videoElement) {
  if (!mobileNetSession || !yunetSession) {
    await initMobileFaceNet();
    if (!mobileNetSession) {
      throw new Error('El modelo MobileFaceNet no está inicializado');
    }
  }

  const vWidth = videoElement.videoWidth || 640;
  const vHeight = videoElement.videoHeight || 480;

  // 1. Detectar rostro con YuNet ONNX a 640x640
  let detectedFace = null;
  if (yunetSession) {
    try {
      const detCanvas = document.createElement('canvas');
      detCanvas.width = 640;
      detCanvas.height = 640;
      const detCtx = detCanvas.getContext('2d', { willReadFrequently: true });
      detCtx.drawImage(videoElement, 0, 0, 640, 640);
      const detImgData = detCtx.getImageData(0, 0, 640, 640).data;

      const floatDet = new Float32Array(1 * 3 * 640 * 640);
      const totalPixels = 640 * 640;
      for (let i = 0; i < totalPixels; i++) {
        floatDet[i] = detImgData[i * 4];
        floatDet[totalPixels + i] = detImgData[i * 4 + 1];
        floatDet[totalPixels * 2 + i] = detImgData[i * 4 + 2];
      }

      const detTensor = new ort.Tensor('float32', floatDet, [1, 3, 640, 640]);
      const detResults = await yunetSession.run({ input: detTensor });
      const faces = decodeYuNet(detResults, 0.45);
      if (faces.length > 0) {
        detectedFace = faces[0];
      }
      detCtx.clearRect(0, 0, 640, 640);
    } catch (e) {
      console.warn('[FacePipeline] Detección YuNet falló, usando fallback de encuadre:', e);
    }
  }

  // 2. Construir Canvas 112x112 con Alineación Canónica ArcFace (51.6 px ojo, 35.24 px distancia)
  const canvas = document.createElement('canvas');
  canvas.width = 112;
  canvas.height = 112;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });

  if (detectedFace) {
    // Mapear coordenadas de 640x640 a resolución nativa del video
    const scaleX = vWidth / 640;
    const scaleY = vHeight / 640;
    const reX = detectedFace.landmarks.rightEye.x * scaleX;
    const reY = detectedFace.landmarks.rightEye.y * scaleY;
    const leX = detectedFace.landmarks.leftEye.x * scaleX;
    const leY = detectedFace.landmarks.leftEye.y * scaleY;

    const eyeCenterX = (reX + leX) / 2;
    const eyeCenterY = (reY + leY) / 2;
    const dx = leX - reX;
    const dy = leY - reY;
    const currentDist = Math.hypot(dx, dy);
    const angle = Math.atan2(dy, dx);

    // Parámetros canónicos estándar 112x112 ArcFace
    const targetDist = 35.24;
    const targetCenterX = 55.91;
    const targetCenterY = 51.60;
    const scale = currentDist > 0 ? targetDist / currentDist : 1.0;

    ctx.save();
    ctx.translate(targetCenterX, targetCenterY);
    ctx.rotate(-angle);
    ctx.scale(scale, scale);
    ctx.translate(-eyeCenterX, -eyeCenterY);
    ctx.drawImage(videoElement, 0, 0);
    ctx.restore();
    console.log(`[FacePipeline] Rostro alineado canónicamente (Score: ${(detectedFace.score * 100).toFixed(1)}%)`);
  } else {
    // Fallback al encuadre 4:5 central estandarizado
    const cropH = Math.min(vHeight * 0.72, vWidth * 0.9);
    const cropW = cropH * 0.8;
    const startX = (vWidth - cropW) / 2;
    const startY = (vHeight - cropH) * 0.42;
    ctx.drawImage(videoElement, startX, startY, cropW, cropH, 0, 0, 112, 112);
    console.log('[FacePipeline] Rostro no detectado por YuNet; usando encuadre 4:5 central');
  }

  // 3. Helper para inferir vector Float32Array(512) crudo desde un ImageData de 112x112
  const runInference = async (imgData) => {
    const floatData = new Float32Array(1 * 3 * 112 * 112);
    const totalPixels = 112 * 112;

    for (let i = 0; i < totalPixels; i++) {
      floatData[i] = imgData[i * 4];
      floatData[totalPixels + i] = imgData[i * 4 + 1];
      floatData[totalPixels * 2 + i] = imgData[i * 4 + 2];
    }

    const inputTensor = new ort.Tensor('float32', floatData, [1, 3, 112, 112]);
    const inputName = mobileNetSession.inputNames[0];
    const feeds = { [inputName]: inputTensor };
    const results = await mobileNetSession.run(feeds);
    const outputName = mobileNetSession.outputNames[0];
    return results[outputName].data;
  };

  const inferStart = performance.now();

  // Inferencia 1: Recorte alineado directo
  const imgDataDirect = ctx.getImageData(0, 0, 112, 112).data;
  const rawVecDirect = await runInference(imgDataDirect);

  // Inferencia 2: Recorte alineado espejado (Flip-Fusion)
  const flipCanvas = document.createElement('canvas');
  flipCanvas.width = 112;
  flipCanvas.height = 112;
  const fCtx = flipCanvas.getContext('2d', { willReadFrequently: true });
  fCtx.translate(112, 0);
  fCtx.scale(-1, 1);
  fCtx.drawImage(canvas, 0, 0);
  const imgDataFlip = fCtx.getImageData(0, 0, 112, 112).data;
  const rawVecFlip = await runInference(imgDataFlip);

  const inferMs = (performance.now() - inferStart).toFixed(1);
  console.log(`[FacePipeline] Inferencia 512D con Flip-Fusion completada en ${inferMs} ms`);

  // Fusión vectorial y Normalización Euclidiana (L2 = 1.0)
  let sumSq = 0;
  const fusedVector = new Float32Array(512);
  for (let i = 0; i < 512; i++) {
    const val = rawVecDirect[i] + rawVecFlip[i];
    fusedVector[i] = val;
    sumSq += val * val;
  }
  const norm = Math.sqrt(sumSq) || 1.0;
  const normalizedVector = [];
  for (let i = 0; i < 512; i++) {
    normalizedVector.push(Number((fusedVector[i] / norm).toFixed(5)));
  }

  // Zero-Trust: Destruir buffers de imagen de la memoria RAM
  ctx.clearRect(0, 0, 112, 112);
  fCtx.clearRect(0, 0, 112, 112);
  return normalizedVector;
}
