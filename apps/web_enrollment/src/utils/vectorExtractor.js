import * as ort from 'onnxruntime-web';

// Cargar WebAssembly desde CDN coincidente con la versión instalada (1.31.1)
ort.env.wasm.wasmPaths = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.31.1/dist/';
ort.env.wasm.numThreads = 1;

let session = null;
let isInitializing = false;

// Precargar sesión inferencia de MobileFaceNet en memoria
export async function initMobileFaceNet() {
  if (session) return session;
  if (isInitializing) return;
  isInitializing = true;

  const startTime = performance.now();
  console.log('[MobileFaceNet] Iniciando carga de modelo ONNX en WebAssembly...');

  try {
    session = await ort.InferenceSession.create('/models/mobilefacenet.onnx', {
      executionProviders: ['wasm'],
      graphOptimizationLevel: 'all',
    });
    const elapsedMs = (performance.now() - startTime).toFixed(1);
    console.log(`[MobileFaceNet] Modelo cargado exitosamente en WebAssembly en ${elapsedMs} ms`);
  } catch (error) {
    const elapsedMs = (performance.now() - startTime).toFixed(1);
    console.error(`[MobileFaceNet] Error inicializando modelo ONNX tras ${elapsedMs} ms:`, error);
  } finally {
    isInitializing = false;
  }
  return session;
}

// Extraer vector 512D
export async function extract512DVectorFromVideo(videoElement) {
  if (!session) {
    await initMobileFaceNet();
    if (!session) {
      throw new Error('El modelo MobileFaceNet no está inicializado');
    }
  }

  // Recortar región facial y escalar a 112x112 (Estándar MobileFaceNet)
  const canvas = document.createElement('canvas');
  canvas.width = 112;
  canvas.height = 112;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });

  const vWidth = videoElement.videoWidth || 640;
  const vHeight = videoElement.videoHeight || 480;
  const cropSize = Math.min(vWidth, vHeight) * 0.7;
  const startX = (vWidth - cropSize) / 2;
  const startY = (vHeight - cropSize) / 2;

  ctx.drawImage(videoElement, startX, startY, cropSize, cropSize, 0, 0, 112, 112);
  const imgData = ctx.getImageData(0, 0, 112, 112).data;

  // Preprocesamiento Tensor NCHW [1, 3, 112, 112]
  // Normalización estándar: (pixel - 127.5) / 128.0 -> Rango [-1.0, 1.0]
  const floatData = new Float32Array(1 * 3 * 112 * 112);
  const totalPixels = 112 * 112;

  for (let i = 0; i < totalPixels; i++) {
    const r = imgData[i * 4];
    const g = imgData[i * 4 + 1];
    const b = imgData[i * 4 + 2];

    floatData[i] = (r - 127.5) / 128.0;                    // R
    floatData[totalPixels + i] = (g - 127.5) / 128.0;      // G
    floatData[totalPixels * 2 + i] = (b - 127.5) / 128.0;  // B
  }

  // Crear Tensor ONNX y ejecutar Inferencia
  const inputTensor = new ort.Tensor('float32', floatData, [1, 3, 112, 112]);
  const inputName = session.inputNames[0];
  const feeds = { [inputName]: inputTensor };

  const inferStart = performance.now();
  const results = await session.run(feeds);
  const inferMs = (performance.now() - inferStart).toFixed(1);
  console.log(`[MobileFaceNet] Inferencia 512D completada en ${inferMs} ms`);

  // Obtener el vector de salida de 512 dimensiones
  const outputName = session.outputNames[0];
  const rawVector = results[outputName].data; // Float32Array de 512

  // Normalización Euclidiana (L2 = 1.0)
  let sumSq = 0;
  for (let i = 0; i < 512; i++) {
    sumSq += rawVector[i] * rawVector[i];
  }
  const norm = Math.sqrt(sumSq) || 1.0;
  const normalizedVector = [];
  for (let i = 0; i < 512; i++) {
    normalizedVector.push(Number((rawVector[i] / norm).toFixed(5)));
  }

  // Zero-Trust: Destruir buffers de imagen de la memoria RAM
  ctx.clearRect(0, 0, 112, 112);
  return normalizedVector;
}
