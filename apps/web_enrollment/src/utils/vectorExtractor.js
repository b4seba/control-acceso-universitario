import * as ort from 'onnxruntime-web';

// Cargar WebAssembly desde CDN coincidente con la versión instalada (1.31.1)
ort.env.wasm.wasmPaths = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.31.1/dist/';
ort.env.wasm.numThreads = 1;

const MODEL_CANDIDATES = [
  { url: '/models/mobilefacenet.int8.onnx', approxRawBytes: 65910000, label: 'MobileFaceNet INT8' },
  { url: '/models/mobilefacenet.onnx', approxRawBytes: 261036388, label: 'MobileFaceNet FP32' },
];
const YUNET_URL = '/models/face_detection_yunet_2023mar.onnx';

const IDB_NAME = 'sirad-biometric-models-v1';
const IDB_STORE = 'models';

let mobileNetSession = null;
let yunetSession = null;
let initPromise = null;

let modelStatus = {
  state: 'idle', // 'idle' | 'loading' | 'ready' | 'error'
  stage: '',
  progressPct: 0,
  loadedMB: 0,
  totalMB: 0,
  cached: false,
  errorMessage: null,
};

const listeners = new Set();

function emitStatus(patch) {
  modelStatus = { ...modelStatus, ...patch };
  for (const fn of listeners) {
    try {
      fn(modelStatus);
    } catch {
      // Ignore UI subscriber errors
    }
  }
}

export function getModelStatus() {
  return modelStatus;
}

export function subscribeModelStatus(listener) {
  listeners.add(listener);
  listener(modelStatus);
  return () => listeners.delete(listener);
}

function openModelDb() {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined') {
      reject(new Error('IndexedDB no disponible'));
      return;
    }
    const req = indexedDB.open(IDB_NAME, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(IDB_STORE)) {
        db.createObjectStore(IDB_STORE, { keyPath: 'url' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error || new Error('Error abriendo IndexedDB'));
  });
}

async function readCachedModel(url) {
  try {
    const db = await openModelDb();
    return await new Promise((resolve) => {
      const tx = db.transaction(IDB_STORE, 'readonly');
      const store = tx.objectStore(IDB_STORE);
      const req = store.get(url);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => resolve(null);
      tx.oncomplete = () => db.close();
    });
  } catch {
    return null;
  }
}

async function writeCachedModel(url, buffer, validator) {
  try {
    const db = await openModelDb();
    await new Promise((resolve) => {
      const tx = db.transaction(IDB_STORE, 'readwrite');
      const store = tx.objectStore(IDB_STORE);
      store.put({ url, buffer, validator, cachedAt: Date.now() });
      tx.oncomplete = () => {
        db.close();
        resolve();
      };
      tx.onerror = () => {
        db.close();
        resolve();
      };
    });
  } catch {
    // Non-fatal: private browsing / quota limits still run in memory
  }
}

async function headModelValidator(url) {
  try {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 6000);
    const res = await fetch(url, { method: 'HEAD', signal: controller.signal });
    window.clearTimeout(timer);
    if (!res.ok) return { exists: false, validator: null };
    const contentType = (res.headers.get('content-type') || '').toLowerCase();
    if (contentType.includes('text/html')) return { exists: false, validator: null };
    const etag = res.headers.get('etag') || '';
    const len = res.headers.get('content-length') || '';
    return { exists: true, validator: `${etag}|${len}` };
  } catch {
    return { exists: null, validator: null };
  }
}

async function fetchModelBytesWithProgress(url, approxRawBytes) {
  const cached = await readCachedModel(url);
  const head = await headModelValidator(url);

  if (head.exists === false) {
    return null;
  }

  if (cached?.buffer && (head.exists === null || !head.validator || cached.validator === head.validator)) {
    const mb = Number((cached.buffer.byteLength / (1024 * 1024)).toFixed(1));
    emitStatus({
      stage: 'Cargando red facial desde caché local...',
      progressPct: 92,
      loadedMB: mb,
      totalMB: mb,
      cached: true,
    });
    return new Uint8Array(cached.buffer);
  }

  const res = await fetch(url);
  if (!res.ok) return null;
  const contentType = (res.headers.get('content-type') || '').toLowerCase();
  if (contentType.includes('text/html')) return null;

  const isEncoded = Boolean(res.headers.get('content-encoding'));
  const headerLen = Number(res.headers.get('content-length') || 0);
  const expectedRaw = isEncoded ? approxRawBytes : headerLen || approxRawBytes;
  const etag = res.headers.get('etag') || '';
  const validator = `${etag}|${headerLen}`;

  if (!res.body || typeof res.body.getReader !== 'function') {
    const buf = await res.arrayBuffer();
    await writeCachedModel(url, buf, validator);
    return new Uint8Array(buf);
  }

  const reader = res.body.getReader();
  const chunks = [];
  let receivedBytes = 0;
  let lastEmitMs = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    receivedBytes += value.byteLength;

    const now = performance.now();
    if (now - lastEmitMs >= 150) {
      lastEmitMs = now;
      const pct = expectedRaw > 0 ? Math.min(90, Math.round((receivedBytes / expectedRaw) * 90)) : 50;
      emitStatus({
        stage: 'Descargando modelo biométrico...',
        progressPct: pct,
        loadedMB: Number((receivedBytes / (1024 * 1024)).toFixed(1)),
        totalMB: Number((expectedRaw / (1024 * 1024)).toFixed(1)),
        cached: false,
      });
    }
  }

  const merged = new Uint8Array(receivedBytes);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }

  const totalMB = Number((receivedBytes / (1024 * 1024)).toFixed(1));
  emitStatus({
    stage: 'Compilando red neuronal en WebAssembly...',
    progressPct: 95,
    loadedMB: totalMB,
    totalMB,
    cached: false,
  });

  await writeCachedModel(url, merged.buffer, validator);
  return merged;
}

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
            rightEye: landmarks[0],
            leftEye: landmarks[1],
            nose: landmarks[2],
            rightMouth: landmarks[3],
            leftMouth: landmarks[4],
          },
        });
      }
    }
  }

  faces.sort((a, b) => b.score - a.score);
  return faces;
}

// Inicialización de modelos (YuNet Face Detector + MobileFaceNet con caché IndexedDB y singleton Promise)
export async function initMobileFaceNet() {
  if (mobileNetSession && yunetSession) {
    emitStatus({ state: 'ready', stage: 'Motor biométrico 512D listo', progressPct: 100, errorMessage: null });
    return { mobileNetSession, yunetSession };
  }
  if (initPromise) return initPromise;

  initPromise = (async () => {
    const startTime = performance.now();
    emitStatus({
      state: 'loading',
      stage: 'Inicializando WebAssembly y detector YuNet...',
      progressPct: 3,
      loadedMB: 0,
      totalMB: 0,
      cached: false,
      errorMessage: null,
    });
    console.log('[FacePipeline] Cargando YuNet y MobileFaceNet ONNX en WebAssembly...');

    try {
      // Descargar pesos en paralelo mientras WebAssembly + YuNet se inicializan
      const fetchCandidateBytes = async () => {
        if (mobileNetSession) return null;
        for (const candidate of MODEL_CANDIDATES) {
          try {
            const bytes = await fetchModelBytesWithProgress(candidate.url, candidate.approxRawBytes);
            if (bytes) return { candidate, bytes };
          } catch (candidateErr) {
            console.warn(`[FacePipeline] Error descargando ${candidate.url}:`, candidateErr);
          }
        }
        return null;
      };

      const [, modelPayload] = await Promise.all([
        yunetSession
          ? Promise.resolve(yunetSession)
          : ort.InferenceSession.create(YUNET_URL, {
              executionProviders: ['wasm'],
              graphOptimizationLevel: 'all',
            }).then((sess) => {
              yunetSession = sess;
              return sess;
            }),
        fetchCandidateBytes(),
      ]);

      if (!mobileNetSession) {
        if (!modelPayload) {
          throw new Error('No se pudo descargar un modelo MobileFaceNet válido desde /models/.');
        }
        emitStatus({
          stage: `Compilando ${modelPayload.candidate.label} en WebAssembly...`,
          progressPct: 96,
        });
        try {
          mobileNetSession = await ort.InferenceSession.create(modelPayload.bytes, {
            executionProviders: ['wasm'],
            graphOptimizationLevel: 'all',
          });
          console.log(`[FacePipeline] Sesión creada con ${modelPayload.candidate.url}`);
        } catch (primaryErr) {
          console.warn(`[FacePipeline] Falló candidato ${modelPayload.candidate.url}:`, primaryErr);
          const fallback = MODEL_CANDIDATES.find((c) => c.url !== modelPayload.candidate.url);
          if (!fallback) throw primaryErr;
          const fallbackBytes = await fetchModelBytesWithProgress(fallback.url, fallback.approxRawBytes);
          if (!fallbackBytes) throw primaryErr;
          mobileNetSession = await ort.InferenceSession.create(fallbackBytes, {
            executionProviders: ['wasm'],
            graphOptimizationLevel: 'all',
          });
          console.log(`[FacePipeline] Sesión creada con fallback ${fallback.url}`);
        }
      }

      const elapsedMs = (performance.now() - startTime).toFixed(1);
      console.log(`[FacePipeline] Modelos cargados exitosamente en ${elapsedMs} ms`);
      emitStatus({
        state: 'ready',
        stage: modelStatus.cached ? 'Motor 512D listo (caché local)' : 'Motor biométrico 512D listo',
        progressPct: 100,
        errorMessage: null,
      });
      return { mobileNetSession, yunetSession };
    } catch (error) {
      const elapsedMs = (performance.now() - startTime).toFixed(1);
      const msg = error?.message || String(error);
      console.error(`[FacePipeline] Error inicializando modelos ONNX tras ${elapsedMs} ms:`, error);
      initPromise = null;
      emitStatus({
        state: 'error',
        stage: 'Error al cargar el modelo ONNX',
        errorMessage: msg,
      });
      throw error;
    }
  })();

  return initPromise;
}

// Extraer vector 512D con Detección Facial YuNet + Alineamiento Canónico + Flip-Fusion
export async function extract512DVectorFromVideo(videoElement) {
  if (!mobileNetSession || !yunetSession) {
    await initMobileFaceNet();
    if (!mobileNetSession) {
      throw new Error('El modelo MobileFaceNet no está inicializado');
    }
  }

  if (!videoElement || videoElement.readyState < 2 || !videoElement.videoWidth || !videoElement.videoHeight) {
    throw new Error('La señal de la cámara aún no está lista. Espere un momento y vuelva a capturar.');
  }

  const vWidth = videoElement.videoWidth;
  const vHeight = videoElement.videoHeight;

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

  const imgDataDirect = ctx.getImageData(0, 0, 112, 112).data;
  const rawVecDirect = await runInference(imgDataDirect);

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

  let sumSq = 0;
  const fusedVector = new Float32Array(512);
  for (let i = 0; i < 512; i++) {
    const val = rawVecDirect[i] + rawVecFlip[i];
    fusedVector[i] = val;
    sumSq += val * val;
  }

  ctx.clearRect(0, 0, 112, 112);
  fCtx.clearRect(0, 0, 112, 112);

  if (!sumSq || Number.isNaN(sumSq)) {
    throw new Error('La inferencia produjo un vector biométrico nulo.');
  }

  const norm = Math.sqrt(sumSq);
  const normalizedVector = [];
  for (let i = 0; i < 512; i++) {
    normalizedVector.push(Number((fusedVector[i] / norm).toFixed(5)));
  }

  return normalizedVector;
}
