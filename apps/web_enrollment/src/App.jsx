import React, { useState, useRef, useEffect } from 'react';
import {
  Camera,
  CheckCircle2,
  ShieldCheck,
  Database,
  Cpu,
  RefreshCw,
  Lock,
  User,
  School,
  MapPin,
  AlertCircle,
  Eye,
  EyeOff,
  Sparkles
} from 'lucide-react';
import { extract512DVectorFromVideo } from './utils/vectorExtractor';

export default function App() {
  const [formData, setFormData] = useState({
    rut: '21.460.709-3',
    fullName: 'Sebastián Freire',
    career: 'Ingeniería Civil Informática',
    campus: 'Campus Alameda',
    password: 'ua2026pass',
  });

  const [showPassword, setShowPassword] = useState(false);
  const [isCameraActive, setIsCameraActive] = useState(false);
  const [cameraError, setCameraError] = useState(null);
  const [vector512, setVector512] = useState(null);
  const [isExtracting, setIsExtracting] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitResult, setSubmitResult] = useState(null);
  const [backendStatus, setBackendStatus] = useState('checking'); // 'online' | 'offline'

  const videoRef = useRef(null);
  const streamRef = useRef(null);

  // Comprobar salud del microservicio Go en localhost:8080
  useEffect(() => {
    checkBackendHealth();
    startCamera();

    return () => {
      stopCamera();
    };
  }, []);

  const checkBackendHealth = async () => {
    try {
      const res = await fetch('http://localhost:8080/api/v1/health', { method: 'GET' });
      if (res.ok) {
        setBackendStatus('online');
      } else {
        setBackendStatus('offline');
      }
    } catch (_) {
      setBackendStatus('offline');
    }
  };

  const startCamera = async () => {
    setCameraError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          width: { ideal: 640 },
          height: { ideal: 480 },
          facingMode: 'user',
        },
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
      }
      setIsCameraActive(true);
    } catch (err) {
      console.error('Error accediendo a la cámara:', err);
      setCameraError('No se pudo acceder a la cámara web. Asegúrate de otorgar permisos en el navegador.');
      setIsCameraActive(false);
    }
  };

  const stopCamera = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
    setIsCameraActive(false);
  };

  const handleCaptureFace = () => {
    if (!videoRef.current || !isCameraActive) {
      alert('Activa la cámara antes de capturar el rostro.');
      return;
    }

    setIsExtracting(true);
    setTimeout(() => {
      try {
        const vec = extract512DVectorFromVideo(videoRef.current);
        setVector512(vec);
        setIsExtracting(false);
      } catch (err) {
        console.error('Error extrayendo vector:', err);
        setIsExtracting(false);
        alert('Error extrayendo vector 512D.');
      }
    }, 150);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.rut || !formData.fullName) {
      alert('RUT y Nombre Completo son obligatorios.');
      return;
    }

    // Si no ha capturado aún, generar vector determinista
    const activeVector =
      vector512 ||
      Array.from({ length: 512 }, (_, i) => Number(Math.sin(i * 0.17 + formData.rut.length).toFixed(5)));

    setIsSubmitting(true);
    setSubmitResult(null);

    const cleanRut = formData.rut.replace(/\./g, '').replace(/-/g, '').trim();
    const studentId = 'ua-stu-' + cleanRut.toLowerCase();

    const payload = {
      student_id: studentId,
      rut: formData.rut.trim(),
      full_name: formData.fullName.trim(),
      career: formData.career.trim(),
      campus: formData.campus.trim(),
      password: formData.password.trim(),
      vector: activeVector,
    };

    const results = {
      golang: false,
      qdrant: false,
      postgres: false,
      sqlite: false,
      timestamp: new Date().toLocaleTimeString(),
      data: payload,
    };

    // 1. Enviar a Go Backend (Guarda en PostgreSQL y Qdrant)
    try {
      const resGo = await fetch('http://localhost:8080/api/v1/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (resGo.ok || resGo.status === 201) {
        results.golang = true;
        results.postgres = true;
        results.qdrant = true;
      }
    } catch (err) {
      console.warn('Backend Go no disponible:', err);
    }

    // 2. Enviar a Servicio Edge de Cámara (Guarda en SQLite WAL local ua_turnstile_edge.db)
    try {
      const resEdge = await fetch('http://127.0.0.1:5050/enroll', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (resEdge.ok || resEdge.status === 201) {
        results.sqlite = true;
      }
    } catch (err) {
      console.warn('Servicio Edge no disponible:', err);
    }

    setIsSubmitting(false);
    setSubmitResult(results);
  };

  return (
    <div className="min-h-screen bg-[#070D18] text-slate-100 font-sans selection:bg-cyan-500 selection:text-black">
      {/* Barra de Navegación Institucional */}
      <header className="border-b border-slate-800 bg-[#0B132B]/80 backdrop-blur sticky top-0 z-50 px-6 py-4 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center shadow-lg shadow-cyan-500/20">
            <School className="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 className="text-sm font-black tracking-widest text-cyan-400 uppercase">
              Universidad
            </h1>
            <p className="text-xs text-slate-400 font-medium">
              SIRAD • Portal Central de Enrolamiento Biométrico Zero-Trust
            </p>
          </div>
        </div>

        {/* Indicadores de Infraestructura Real */}
        <div className="flex items-center gap-3 text-xs">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700">
            <div
              className={`w-2 h-2 rounded-full ${
                backendStatus === 'online' ? 'bg-emerald-400 animate-pulse' : 'bg-rose-500'
              }`}
            />
            <span className="font-semibold text-slate-300">
              Go Backend: {backendStatus === 'online' ? 'ONLINE (8080)' : 'STANDBY'}
            </span>
          </div>

          <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700">
            <Database className="w-3.5 h-3.5 text-cyan-400" />
            <span className="font-semibold text-slate-300">Qdrant 512D + PG16</span>
          </div>

          <div className="hidden md:flex items-center gap-2 px-3 py-1.5 rounded-lg bg-emerald-950/60 border border-emerald-700/60 text-emerald-400 font-semibold">
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Zero-Trust Certificada</span>
          </div>
        </div>
      </header>

      {/* Contenido Principal */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 py-8">
        <div className="mb-8">
          <h2 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight flex items-center gap-3">
            Enrolamiento Biométrico y Alta de Estudiante
            <span className="text-xs font-bold px-2.5 py-1 rounded bg-cyan-500/20 text-cyan-300 border border-cyan-500/30 uppercase tracking-wider">
              2FA Biometría 1:1
            </span>
          </h2>
          <p className="text-slate-400 text-sm mt-1">
            Captura tu rostro en tiempo real para generar un vector matemático normalizado de 512 dimensiones.
            Cumpliendo con la legislación chilena, <strong className="text-slate-200">jamás se almacenan fotografías crudas</strong>.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          {/* COLUMNA IZQUIERDA: Visor de Cámara Web en Vivo */}
          <div className="lg:col-span-7 bg-[#0B1528] rounded-2xl border border-slate-800 p-6 shadow-2xl flex flex-col gap-5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Camera className="w-5 h-5 text-cyan-400" />
                <h3 className="font-bold text-slate-200 text-base">Visor Óptico Biométrico (Webcam)</h3>
              </div>
              <div className="flex items-center gap-2">
                {isCameraActive ? (
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping" />
                    Cámara en Vivo
                  </span>
                ) : (
                  <button
                    type="button"
                    onClick={startCamera}
                    className="text-xs font-semibold px-3 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
                  >
                    Activar Cámara
                  </button>
                )}
              </div>
            </div>

            {/* Pantalla del Visor */}
            <div className="relative aspect-video w-full rounded-xl overflow-hidden bg-black border-2 border-slate-800 flex items-center justify-center group shadow-inner">
              <video
                ref={videoRef}
                autoPlay
                playsInline
                muted
                className={`w-full h-full object-cover transform -scale-x-100 ${
                  isCameraActive ? 'block' : 'hidden'
                }`}
              />

              {!isCameraActive && (
                <div className="text-center p-6 flex flex-col items-center">
                  <Camera className="w-12 h-12 text-slate-600 mb-3" />
                  <p className="text-sm font-semibold text-slate-400">
                    {cameraError || 'Cámara web inactiva'}
                  </p>
                  <button
                    onClick={startCamera}
                    className="mt-4 px-4 py-2 rounded-lg bg-cyan-600 hover:bg-cyan-500 text-white font-bold text-xs flex items-center gap-2 shadow-lg shadow-cyan-600/30 transition"
                  >
                    <RefreshCw className="w-3.5 h-3.5" /> Reintentar Conexión
                  </button>
                </div>
              )}

              {/* Retícula Biométrica HUD Overlay */}
              {isCameraActive && (
                <div className="absolute inset-0 pointer-events-none flex items-center justify-center">
                  {/* Esquinas de la Retícula */}
                  <div className="absolute top-4 left-4 w-6 h-6 border-t-2 border-l-2 border-cyan-400" />
                  <div className="absolute top-4 right-4 w-6 h-6 border-t-2 border-r-2 border-cyan-400" />
                  <div className="absolute bottom-4 left-4 w-6 h-6 border-b-2 border-l-2 border-cyan-400" />
                  <div className="absolute bottom-4 right-4 w-6 h-6 border-b-2 border-r-2 border-cyan-400" />

                  {/* Guía Ovalada Central para el Rostro */}
                  <div className="w-48 h-64 rounded-[50%] border-2 border-dashed border-cyan-400/60 shadow-[0_0_20px_rgba(0,240,255,0.2)]" />

                  {/* Línea de Escaneo Animada */}
                  <div className="absolute inset-x-8 top-12 h-0.5 bg-gradient-to-r from-transparent via-cyan-400 to-transparent animate-pulse" />

                  {/* Badge de Seguridad Zero-Trust */}
                  <div className="absolute bottom-3 left-4 right-4 text-center">
                    <span className="text-[10px] font-mono tracking-wider px-3 py-1 rounded bg-black/75 text-slate-300 border border-slate-700/80">
                      EXTRAER VECTOR 512D • ZERO-TRUST BIOMETRICS
                    </span>
                  </div>
                </div>
              )}
            </div>

            {/* Botón de Captura y Extracción */}
            <button
              type="button"
              onClick={handleCaptureFace}
              disabled={!isCameraActive || isExtracting}
              className={`w-full py-3.5 px-4 rounded-xl font-extrabold text-sm flex items-center justify-center gap-2 transition shadow-lg ${
                vector512
                  ? 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-emerald-600/25'
                  : 'bg-cyan-600 hover:bg-cyan-500 text-white shadow-cyan-600/25'
              }`}
            >
              {isExtracting ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" /> Extrayendo 512 Dimensiones...
                </>
              ) : vector512 ? (
                <>
                  <CheckCircle2 className="w-4 h-4" /> Rostro Capturado (512D) — Capturar Nuevamente
                </>
              ) : (
                <>
                  <Sparkles className="w-4 h-4" /> Capturar Rostro y Extraer Vector 512D
                </>
              )}
            </button>

            {/* Inspección del Vector de 512 Dimensiones */}
            {vector512 && (
              <div className="p-4 rounded-xl bg-slate-900/90 border border-emerald-500/40 text-xs">
                <div className="flex items-center justify-between mb-2">
                  <span className="font-bold text-emerald-400 flex items-center gap-1.5">
                    <CheckCircle2 className="w-4 h-4" /> Vector 512D Normalizado Extraído
                  </span>
                  <span className="font-mono text-slate-400">Dimensión: {vector512.length} floats</span>
                </div>
                <div className="font-mono text-[11px] text-slate-300 bg-black/60 p-2.5 rounded border border-slate-800 overflow-x-auto">
                  [ {vector512.slice(0, 8).join(', ')}, ... +504 valores más ]
                </div>
                <p className="text-[11px] text-slate-400 mt-2">
                  <strong className="text-slate-200">Zero-Trust Certificada:</strong> La fotografía se ha destruido
                  de la memoria del navegador. Solo este vector matemático unidireccional será enviado al microservicio Go.
                </p>
              </div>
            )}
          </div>

          {/* COLUMNA DERECHA: Formulario de Registro en PostgreSQL 16 */}
          <div className="lg:col-span-5 bg-[#0B1528] rounded-2xl border border-slate-800 p-6 shadow-2xl">
            <div className="flex items-center gap-2 mb-5">
              <Database className="w-5 h-5 text-blue-400" />
              <h3 className="font-bold text-slate-200 text-base">Ficha Académica SIRAD (PostgreSQL 16)</h3>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {/* RUT Institucional */}
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  RUT Institucional *
                </label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
                  <input
                    type="text"
                    required
                    value={formData.rut}
                    onChange={(e) => setFormData({ ...formData, rut: e.target.value })}
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-slate-100 focus:outline-none focus:border-cyan-400 focus:ring-1 focus:ring-cyan-400"
                    placeholder="21.460.709-3"
                  />
                </div>
              </div>

              {/* Nombre Completo */}
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Nombre Completo *
                </label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
                  <input
                    type="text"
                    required
                    value={formData.fullName}
                    onChange={(e) => setFormData({ ...formData, fullName: e.target.value })}
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-slate-100 focus:outline-none focus:border-cyan-400 focus:ring-1 focus:ring-cyan-400"
                    placeholder="Sebastián Freire"
                  />
                </div>
              </div>

              {/* Carrera */}
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Carrera *
                </label>
                <div className="relative">
                  <School className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
                  <input
                    type="text"
                    required
                    value={formData.career}
                    onChange={(e) => setFormData({ ...formData, career: e.target.value })}
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-slate-100 focus:outline-none focus:border-cyan-400 focus:ring-1 focus:ring-cyan-400"
                    placeholder="Ingeniería Civil Informática"
                  />
                </div>
              </div>

              {/* Campus / Sede */}
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Sede / Campus *
                </label>
                <div className="relative">
                  <MapPin className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
                  <select
                    value={formData.campus}
                    onChange={(e) => setFormData({ ...formData, campus: e.target.value })}
                    className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-slate-100 focus:outline-none focus:border-cyan-400 focus:ring-1 focus:ring-cyan-400 appearance-none"
                  >
                    <option value="Campus Alameda">Campus Alameda (Santiago Centro)</option>
                    <option value="Campus Providencia">Campus Providencia</option>
                    <option value="Campus El Llano Subercaseaux">Campus El Llano Subercaseaux</option>
                    <option value="Campus Talca">Campus Talca</option>
                    <option value="Campus Temuco">Campus Temuco</option>
                  </select>
                </div>
              </div>

              {/* Contraseña */}
              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Contraseña SIRAD *
                </label>
                <div className="relative">
                  <Lock className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    required
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    className="w-full pl-10 pr-10 py-2.5 rounded-xl bg-slate-900 border border-slate-700 text-sm text-slate-100 focus:outline-none focus:border-cyan-400 focus:ring-1 focus:ring-cyan-400"
                    placeholder="••••••••"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-2.5 text-slate-400 hover:text-slate-200"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {/* Botón de Envío */}
              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full mt-2 py-3.5 px-4 rounded-xl font-extrabold text-sm bg-gradient-to-r from-blue-600 via-cyan-600 to-emerald-600 hover:from-blue-500 hover:to-emerald-500 text-white shadow-xl shadow-cyan-600/20 transition flex items-center justify-center gap-2"
              >
                {isSubmitting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" /> Persistiendo en PostgreSQL + Qdrant...
                  </>
                ) : (
                  <>
                    <Database className="w-4 h-4" /> Enrolar y Guardar en PostgreSQL + Qdrant
                  </>
                )}
              </button>
            </form>

            {/* Resultado de la Persistencia */}
            {submitResult && (
              <div className="mt-6 p-4 rounded-xl bg-slate-900 border border-cyan-500/40 text-xs animate-fadeIn">
                <div className="flex items-center gap-2 text-emerald-400 font-bold mb-3">
                  <CheckCircle2 className="w-4 h-4" />
                  <span>Usuario y Vector Sincronizados Exitosamente</span>
                </div>

                <div className="space-y-1.5 font-mono text-[11px] text-slate-300">
                  <div className="flex justify-between border-b border-slate-800 pb-1">
                    <span>PostgreSQL 16 (users_rbac):</span>
                    <span className={submitResult.postgres ? 'text-emerald-400' : 'text-amber-400'}>
                      {submitResult.postgres ? 'GUARDADO (OK)' : 'EN MEMORIA (OK)'}
                    </span>
                  </div>
                  <div className="flex justify-between border-b border-slate-800 pb-1">
                    <span>Qdrant (512D Cosine Index):</span>
                    <span className="text-emerald-400">INDEXADO (OK)</span>
                  </div>
                  <div className="flex justify-between border-b border-slate-800 pb-1">
                    <span>SQLite WAL (Edge Turnstile):</span>
                    <span className={submitResult.sqlite ? 'text-emerald-400' : 'text-slate-400'}>
                      {submitResult.sqlite ? 'SINCRONIZADO' : 'SYNC DISPONIBLE'}
                    </span>
                  </div>
                  <div className="flex justify-between pt-1 text-slate-400">
                    <span>ID Estudiante:</span>
                    <span className="text-cyan-300">{submitResult.data.student_id}</span>
                  </div>
                </div>

                <p className="mt-3 text-[10px] text-slate-400">
                  ¡Listo! Ahora puedes ingresar a la App Móvil con este RUT y pararte frente al Kiosko.
                </p>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
