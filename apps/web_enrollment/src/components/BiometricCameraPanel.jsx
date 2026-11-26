import React from 'react';
import { AlertCircle, Camera, CameraOff, CheckCircle2, Cpu, Fingerprint, RefreshCw } from 'lucide-react';

/**
 * Optical biometric webcam capture panel with clean fiducial alignment guides,
 * ONNX model readiness progress, and L2 512D embedding preview.
 */
export default function BiometricCameraPanel({
  videoRef,
  isCameraActive,
  cameraError,
  isExtracting,
  vector512,
  modelStatus,
  onStartCamera,
  onStopCamera,
  onCaptureFace,
  onRetryModelLoad,
}) {
  const isModelLoading = modelStatus?.state === 'loading' || modelStatus?.state === 'idle';
  const isModelError = modelStatus?.state === 'error';
  const progressPct = modelStatus?.progressPct ?? 0;
  return (
    <section
      aria-labelledby="camera-panel-title"
      className="lg:col-span-7 bg-surface rounded-xl border border-hairline p-5 sm:p-6 flex flex-col gap-5"
    >
      <div className="flex flex-wrap items-center justify-between gap-3 pb-4 border-b border-hairline">
        <div className="flex items-center gap-2.5">
          <span className="w-8 h-8 rounded-lg bg-subtle border border-hairline flex items-center justify-center text-ink">
            <Camera className="w-4 h-4" aria-hidden="true" />
          </span>
          <div>
            <h2 id="camera-panel-title" className="text-base font-semibold text-ink leading-tight">
              Estación Óptica Biométrica
            </h2>
            <p className="text-xs text-ink-secondary">
              Detección YuNet + embedding local MobileFaceNet (ONNX Web)
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2.5">
          {isCameraActive ? (
            <>
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium bg-success-bg text-success border border-success/20">
                <span className="w-1.5 h-1.5 rounded-full bg-success" aria-hidden="true" />
                Sensor activo
              </span>
              <button
                type="button"
                onClick={onStopCamera}
                title="Libera el dispositivo de cámara web"
                className="min-h-[38px] px-3 py-1.5 rounded-lg border border-border-strong bg-surface hover:bg-subtle text-ink text-xs font-semibold inline-flex items-center gap-1.5 transition-colors duration-150"
              >
                <CameraOff className="w-3.5 h-3.5 text-danger" aria-hidden="true" />
                <span>Desactivar Cámara</span>
              </button>
            </>
          ) : (
            <button
              type="button"
              onClick={onStartCamera}
              title="Inicia la cámara web en el navegador"
              className="min-h-[38px] px-3.5 py-1.5 rounded-lg bg-ink hover:bg-ink/90 text-white text-xs font-semibold inline-flex items-center gap-1.5 transition-colors duration-150"
            >
              <Camera className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Activar Cámara</span>
            </button>
          )}
        </div>
      </div>

      {/* Optical Viewport */}
      <div className="relative aspect-video w-full rounded-xl overflow-hidden bg-[#141416] border border-border-strong flex items-center justify-center">
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted
          aria-label="Vista previa en vivo de la cámara web para captura facial"
          className={`w-full h-full object-cover transform -scale-x-100 ${
            isCameraActive ? 'block' : 'hidden'
          }`}
        />

        {isCameraActive && (
          <div className="absolute inset-0 pointer-events-none flex flex-col items-center justify-center">
            <svg
              className="w-full h-full absolute inset-0"
              viewBox="0 0 640 360"
              preserveAspectRatio="none"
              aria-hidden="true"
            >
              <defs>
                <mask id="faceSilhouetteMask">
                  <rect width="640" height="360" fill="white" />
                  <ellipse cx="320" cy="168" rx="102" ry="130" fill="black" />
                </mask>
              </defs>
              <rect
                width="640"
                height="360"
                fill="rgba(24, 24, 27, 0.34)"
                mask="url(#faceSilhouetteMask)"
              />
              <ellipse
                cx="320"
                cy="168"
                rx="102"
                ry="130"
                fill="none"
                stroke="rgba(255, 255, 255, 0.72)"
                strokeWidth="1.5"
                strokeDasharray="5 5"
              />
              <line x1="204" y1="146" x2="226" y2="146" stroke="rgba(255, 255, 255, 0.6)" strokeWidth="1.5" />
              <line x1="414" y1="146" x2="436" y2="146" stroke="rgba(255, 255, 255, 0.6)" strokeWidth="1.5" />
              {/* Corner fiducials */}
              <path d="M 24 44 L 24 24 L 44 24" fill="none" stroke="rgba(255,255,255,0.65)" strokeWidth="1.5" />
              <path d="M 596 24 L 616 24 L 616 44" fill="none" stroke="rgba(255,255,255,0.65)" strokeWidth="1.5" />
              <path d="M 24 316 L 24 336 L 44 336" fill="none" stroke="rgba(255,255,255,0.65)" strokeWidth="1.5" />
              <path d="M 596 336 L 616 336 L 616 316" fill="none" stroke="rgba(255,255,255,0.65)" strokeWidth="1.5" />
            </svg>

            <div className="absolute bottom-3 px-3 py-1 rounded-md bg-[#18181B]/80 text-[11px] text-white/95 font-medium tracking-wide">
              Alinee el rostro dentro de la guía frontal
            </div>
          </div>
        )}

        {!isCameraActive && (
          <div className="text-center p-6 flex flex-col items-center max-w-sm">
            <span className="w-12 h-12 rounded-xl bg-white/10 border border-white/15 flex items-center justify-center mb-3">
              <CameraOff className="w-6 h-6 text-white/80" aria-hidden="true" />
            </span>
            <p className="text-sm font-semibold text-white">Cámara web desactivada</p>
            <p className="text-xs text-white/75 mt-1.5 leading-relaxed">
              {cameraError ||
                'El dispositivo de video fue liberado. Active la cámara para extraer el descriptor matemático 512D.'}
            </p>
            <button
              type="button"
              onClick={onStartCamera}
              className="mt-4 min-h-[40px] px-4 py-2 rounded-lg bg-crimson hover:bg-crimson-hover text-white font-semibold text-xs inline-flex items-center gap-2 transition-colors duration-150"
            >
              <Camera className="w-3.5 h-3.5" aria-hidden="true" />
              <span>Activar Cámara Web</span>
            </button>
          </div>
        )}
      </div>

      {/* Model Readiness & Download Progress Strip */}
      <div
        className={`rounded-lg border px-3.5 py-2.5 text-xs flex flex-col gap-1.5 ${
          isModelError
            ? 'bg-danger-bg border-danger/25 text-danger'
            : modelStatus?.state === 'ready'
            ? 'bg-success-bg border-success/20 text-success'
            : 'bg-subtle border-hairline text-ink-secondary'
        }`}
        role="status"
        aria-live="polite"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="inline-flex items-center gap-1.5 font-medium">
            {isModelError ? (
              <AlertCircle className="w-3.5 h-3.5 shrink-0" aria-hidden="true" />
            ) : modelStatus?.state === 'ready' ? (
              <CheckCircle2 className="w-3.5 h-3.5 shrink-0" aria-hidden="true" />
            ) : (
              <Cpu className="w-3.5 h-3.5 shrink-0 animate-pulse text-ink" aria-hidden="true" />
            )}
            <span>
              {modelStatus?.stage || 'Inicializando motor biométrico ONNX...'}
            </span>
          </span>

          {isModelLoading && (
            <span className="font-mono text-[11px] tabular-nums text-ink">
              {modelStatus?.totalMB > 0
                ? `${progressPct}% · ${modelStatus.loadedMB}/${modelStatus.totalMB} MB`
                : `${progressPct}%`}
            </span>
          )}

          {isModelError && onRetryModelLoad && (
            <button
              type="button"
              onClick={onRetryModelLoad}
              className="px-2.5 py-1 rounded border border-danger/30 bg-surface hover:bg-danger-bg text-danger font-semibold text-[11px] inline-flex items-center gap-1 transition-colors duration-150"
            >
              <RefreshCw className="w-3 h-3" aria-hidden="true" />
              <span>Reintentar carga</span>
            </button>
          )}
        </div>

        {isModelLoading && (
          <div className="w-full h-1.5 rounded-full bg-hairline overflow-hidden">
            <div
              className="h-full bg-ink transition-all duration-150"
              style={{ width: `${Math.max(4, progressPct)}%` }}
            />
          </div>
        )}
      </div>

      {/* Primary Biometric Capture Action */}
      <button
        type="button"
        onClick={onCaptureFace}
        disabled={!isCameraActive || isExtracting}
        className={`w-full min-h-[46px] py-3 px-4 rounded-lg font-semibold text-sm flex items-center justify-center gap-2 transition-colors duration-150 ${
          !isCameraActive
            ? 'bg-subtle text-ink-muted border border-hairline cursor-not-allowed'
            : vector512
            ? 'bg-success hover:bg-success/90 text-white'
            : 'bg-ink hover:bg-ink/90 text-white'
        }`}
      >
        {isExtracting ? (
          <>
            <RefreshCw className="w-4 h-4 animate-spin" aria-hidden="true" />
            <span>
              {isModelLoading
                ? `Esperando modelo biométrico (${progressPct}%)...`
                : 'Extrayendo descriptor 512D...'}
            </span>
          </>
        ) : vector512 ? (
          <>
            <CheckCircle2 className="w-4 h-4" aria-hidden="true" />
            <span>Rostro Capturado (512D) — Recapturar</span>
          </>
        ) : (
          <>
            <Fingerprint className="w-4 h-4" aria-hidden="true" />
            <span>Capturar Rostro y Extraer Vector 512D</span>
          </>
        )}
      </button>

      {/* Extracted Vector Inspection Box */}
      {vector512 && (
        <div className="p-4 rounded-lg bg-canvas border border-hairline text-xs space-y-2.5 animate-fadeIn">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <span className="font-semibold text-success flex items-center gap-1.5">
              <CheckCircle2 className="w-4 h-4" aria-hidden="true" />
              <span>Vector 512D normalizado extraído</span>
            </span>
            <span className="font-mono text-ink-secondary tabular-nums">
              Dimensión: {vector512.length} floats
            </span>
          </div>
          <div className="font-mono text-[11px] text-ink bg-surface p-2.5 rounded-md border border-hairline overflow-x-auto whitespace-nowrap">
            [ {vector512.slice(0, 8).map((n) => Number(n).toFixed(4)).join(', ')}, ... +504 valores más ]
          </div>
          <p className="text-[11px] text-ink-secondary leading-relaxed">
            La imagen fue descartada de la memoria del navegador. Solo este descriptor matemático unidireccional será persistido.
          </p>
        </div>
      )}
    </section>
  );
}
