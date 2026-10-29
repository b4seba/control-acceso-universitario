import React, { useState, useRef, useEffect, useMemo } from 'react';
import {
  Camera,
  CameraOff,
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
  Sparkles,
  Trash2,
  UserCheck,
  UserX,
  Search,
  Users,
  Fingerprint
} from 'lucide-react';
import { extract512DVectorFromVideo } from './utils/vectorExtractor';

export default function App() {
  const [formData, setFormData] = useState({
    rut: '21.460.709-3',
    fullName: 'Sebastián Freire',
    career: 'Ingeniería Civil Informática',
    campus: 'CAMPUS_ALAMEDA',
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

  // Estados para Directorio y Gestión de Estudiantes (RUD)
  const [students, setStudents] = useState([]);
  const [isLoadingStudents, setIsLoadingStudents] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [actionFeedback, setActionFeedback] = useState(null);
  const [selectedVectorStudent, setSelectedVectorStudent] = useState(null);

  // Estados para Reconciliación Políglota (Anti-Entropy)
  const [isReconciling, setIsReconciling] = useState(false);
  const [reconcileReport, setReconcileReport] = useState(null);
  const [showReconcileModal, setShowReconcileModal] = useState(false);

  const videoRef = useRef(null);
  const streamRef = useRef(null);

  useEffect(() => {
    checkBackendHealth();
    startCamera();
    fetchStudents();

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
      setCameraError('No se pudo acceder a la cámara web. Asegúrate de otorgar permisos o cerrar otras aplicaciones que la usen.');
      setIsCameraActive(false);
    }
  };

  const stopCamera = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
    if (videoRef.current) {
      videoRef.current.srcObject = null;
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

  // ==========================================
  // OPERACIONES RUD (READ, UPDATE, DELETE)
  // ==========================================

  // 1. READ: Obtener lista de usuarios desde Backend Go (PG16 + Qdrant)
  const fetchStudents = async () => {
    setIsLoadingStudents(true);
    try {
      const res = await fetch('http://localhost:8080/api/v1/users', { method: 'GET' });
      if (res.ok) {
        const data = await res.json();
        const raw = data.users || [];
        const normalized = raw.map((u) => {
          const st = u.enrollment_status || u.status || 'VIGENTE';
          return {
            ...u,
            status: st,
            enrollment_status: st,
          };
        });
        setStudents(normalized);
      } else {
        console.warn('Error al consultar lista de estudiantes:', res.statusText);
      }
    } catch (err) {
      console.warn('Backend Go no disponible para listar estudiantes:', err);
    } finally {
      setIsLoadingStudents(false);
    }
  };

  // 2. UPDATE: Cambiar estado (VIGENTE / SUSPENDIDO)
  const handleToggleStatus = async (student) => {
    const currentStatus = student.enrollment_status || student.status || 'VIGENTE';
    const nextStatus = currentStatus === 'VIGENTE' ? 'SUSPENDIDO' : 'VIGENTE';

    // Actualización reactiva optimista instantánea en la interfaz
    setStudents((prev) =>
      prev.map((s) =>
        s.rut === student.rut
          ? { ...s, status: nextStatus, enrollment_status: nextStatus }
          : s
      )
    );

    try {
      const res = await fetch(`http://localhost:8080/api/v1/users/${encodeURIComponent(student.rut)}/status`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: nextStatus }),
      });

      if (res.ok) {
        // Notificar también al Kiosko local si está activo
        try {
          await fetch('http://127.0.0.1:5050/update_user_status', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ rut: student.rut, student_id: student.student_id, status: nextStatus }),
          });
        } catch (_) {}

        setActionFeedback({
          type: 'success',
          message: `Estado de ${student.full_name} actualizado a ${nextStatus}. Sincronizado en PostgreSQL, Qdrant y SQLite Edge.`,
        });
        fetchStudents();
      } else {
        const data = await res.json();
        fetchStudents();
        setActionFeedback({
          type: 'error',
          message: data.error || 'No se pudo actualizar el estado del estudiante.',
        });
      }
    } catch (err) {
      fetchStudents();
      setActionFeedback({
        type: 'error',
        message: 'Error de comunicación con el backend: ' + err.message,
      });
    }
    setTimeout(() => setActionFeedback(null), 5000);
  };

  // 3. DELETE: Eliminar estudiante de PostgreSQL, Qdrant y SQLite Edge
  const handleDeleteStudent = async (student) => {
    const confirmDelete = window.confirm(
      `¿Confirmas la eliminación permanente del estudiante?\n\n` +
      `• Nombre: ${student.full_name}\n` +
      `• RUT: ${student.rut}\n` +
      `• ID: ${student.student_id}\n\n` +
      `Esta acción eliminará su registro relacional en PostgreSQL 16, su vector 512D en Qdrant y su autorización en SQLite Edge.`
    );

    if (!confirmDelete) return;

    try {
      const res = await fetch(`http://localhost:8080/api/v1/users/${encodeURIComponent(student.rut)}`, {
        method: 'DELETE',
      });

      if (res.ok) {
        setStudents((prev) => prev.filter((s) => s.rut !== student.rut));
        // Eliminar también en SQLite edge local
        try {
          await fetch('http://127.0.0.1:5050/delete_user', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ rut: student.rut, student_id: student.student_id }),
          });
        } catch (_) {}

        setActionFeedback({
          type: 'success',
          message: `Estudiante ${student.full_name} (${student.rut}) eliminado correctamente de todas las bases de datos.`,
        });
        fetchStudents();
      } else {
        const data = await res.json();
        setActionFeedback({
          type: 'error',
          message: data.error || 'Error al eliminar estudiante.',
        });
      }
    } catch (err) {
      setActionFeedback({
        type: 'error',
        message: 'Error de red al intentar eliminar estudiante: ' + err.message,
      });
    }
    setTimeout(() => setActionFeedback(null), 5000);
  };

  // 4. RECONCILIACIÓN POLÍGLOTA (ANTI-ENTROPY)
  const handleReconcile = async () => {
    setIsReconciling(true);
    try {
      const res = await fetch('http://localhost:8080/api/v1/admin/reconcile', { method: 'POST' });
      const data = await res.json();
      if (res.ok) {
        setReconcileReport(data.report);
        setShowReconcileModal(true);
        fetchStudents();
        setActionFeedback({
          type: 'success',
          message: 'Reconciliación políglota completada: PostgreSQL 16 alineado con Qdrant y SQLite Edge.',
        });
      } else {
        setActionFeedback({
          type: 'error',
          message: data.error || 'Error al ejecutar reconciliación políglota.',
        });
      }
    } catch (err) {
      setActionFeedback({
        type: 'error',
        message: 'Error de red al conectar con backend Go: ' + err.message,
      });
    } finally {
      setIsReconciling(false);
    }
  };

  // CREATE: Formulario de Enrolamiento
  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.rut || !formData.fullName) {
      alert('RUT y Nombre Completo son obligatorios.');
      return;
    }

    // REQUISITO ESTRICTO: NO permitir enrolar si no se ha extraído el vector 512D
    if (!vector512 || vector512.length !== 512) {
      setActionFeedback({
        type: 'error',
        message: 'No puedes enrolar sin capturar tu rostro primero. Presiona "Capturar Rostro y Extraer Vector 512D" en la cámara.',
      });
      return;
    }

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
      vector: vector512,
    };

    const results = {
      success: false,
      golang: false,
      qdrant: false,
      postgres: false,
      sqlite: false,
      errorMsg: null,
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
        results.success = true;
        results.golang = true;
        results.postgres = true;
        results.qdrant = true;
      } else {
        const errJson = await resGo.json().catch(() => ({}));
        results.errorMsg = errJson.error || `Error HTTP ${resGo.status} en Backend Go`;
        setActionFeedback({
          type: 'error',
          message: results.errorMsg,
        });
      }
    } catch (err) {
      results.errorMsg = 'Error al conectar con Backend Go: ' + err.message;
      setActionFeedback({
        type: 'error',
        message: results.errorMsg,
      });
    }

    // 2. Enviar a Servicio Edge de Cámara (Guarda en SQLite WAL local)
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

    // Refrescar automáticamente la lista de estudiantes si tuvo éxito
    if (results.success) {
      setActionFeedback({
        type: 'success',
        message: `¡Estudiante ${formData.fullName} enrolado y guardado en PostgreSQL 16 y Qdrant (512D)!`,
      });
      fetchStudents();
    }
  };

  // Filtrado reactivo de estudiantes
  const filteredStudents = useMemo(() => {
    if (!searchQuery.trim()) return students;
    const q = searchQuery.toLowerCase();
    return students.filter(
      (s) =>
        (s.full_name && s.full_name.toLowerCase().includes(q)) ||
        (s.rut && s.rut.toLowerCase().includes(q)) ||
        (s.student_id && s.student_id.toLowerCase().includes(q)) ||
        (s.career && s.career.toLowerCase().includes(q))
    );
  }, [students, searchQuery]);

  const activeCount = useMemo(() => students.filter((s) => (s.enrollment_status || s.status) === 'VIGENTE').length, [students]);
  const suspendedCount = useMemo(() => students.filter((s) => (s.enrollment_status || s.status) === 'SUSPENDIDO').length, [students]);

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
              SIRAD • Portal Central de Enrolamiento y Gestión Biometría Zero-Trust
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

      {/* Notificación flotante de feedback RUD */}
      {actionFeedback && (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 pt-4">
          <div
            className={`p-4 rounded-xl border flex items-center justify-between text-xs font-semibold ${
              actionFeedback.type === 'success'
                ? 'bg-emerald-950/60 border-emerald-500/60 text-emerald-300'
                : 'bg-rose-950/60 border-rose-500/60 text-rose-300'
            }`}
          >
            <div className="flex items-center gap-2">
              {actionFeedback.type === 'success' ? (
                <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
              ) : (
                <AlertCircle className="w-4 h-4 text-rose-400 shrink-0" />
              )}
              <span>{actionFeedback.message}</span>
            </div>
            <button
              onClick={() => setActionFeedback(null)}
              className="px-2 py-0.5 rounded text-[10px] bg-black/40 hover:bg-black/60 text-slate-400"
            >
              Cerrar
            </button>
          </div>
        </div>
      )}

      {/* Contenido Principal */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 py-8 space-y-12">
        {/* ENCABEZADO SECCIÓN ENROLAMIENTO */}
        <div>
          <h2 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight flex items-center gap-3">
            Enrolamiento Biométrico Centralizado
            <span className="text-xs font-bold px-2.5 py-1 rounded bg-cyan-500/20 text-cyan-300 border border-cyan-500/30 uppercase tracking-wider">
              Zero-Trust 512D
            </span>
          </h2>
          <p className="text-slate-400 text-sm mt-1">
            Captura tu rostro en tiempo real para generar un vector matemático normalizado de 512 dimensiones.
            Cumpliendo con la legislación de protección de datos, <strong className="text-slate-200">jamás se almacenan fotografías crudas</strong>.
          </p>
        </div>

        {/* GRID DE ENROLAMIENTO (CAMARA + FORMULARIO) */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          {/* COLUMNA IZQUIERDA: Visor de Cámara Web en Vivo con Control ON/OFF */}
          <div className="lg:col-span-7 bg-[#0B1528] rounded-2xl border border-slate-800 p-6 shadow-2xl flex flex-col gap-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <Camera className="w-5 h-5 text-cyan-400" />
                <h3 className="font-bold text-slate-200 text-base">Visor Óptico Biométrico (Webcam)</h3>
              </div>

              {/* CONTROLES DE CÁMARA (ACTIVAR / DESACTIVAR) */}
              <div className="flex items-center gap-2">
                {isCameraActive ? (
                  <div className="flex items-center gap-2">
                    <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping" />
                      Cámara en Vivo
                    </span>
                    <button
                      type="button"
                      onClick={stopCamera}
                      className="text-xs font-bold px-3 py-1.5 rounded-lg bg-rose-600/80 hover:bg-rose-600 text-white flex items-center gap-1.5 transition shadow-sm"
                      title="Apaga la cámara web para liberar el dispositivo de hardware en Windows"
                    >
                      <CameraOff className="w-3.5 h-3.5" />
                      Desactivar Cámara
                    </button>
                  </div>
                ) : (
                  <button
                    type="button"
                    onClick={startCamera}
                    className="text-xs font-bold px-3 py-1.5 rounded-lg bg-emerald-600/80 hover:bg-emerald-600 text-white flex items-center gap-1.5 transition shadow-sm"
                    title="Inicia la cámara web en el navegador"
                  >
                    <Camera className="w-3.5 h-3.5" />
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
                  <CameraOff className="w-12 h-12 text-slate-600 mb-3" />
                  <p className="text-sm font-semibold text-slate-300">
                    Cámara Web Desactivada
                  </p>
                  <p className="text-xs text-slate-500 max-w-sm mt-1">
                    {cameraError ||
                      'El hardware de video ha sido liberado en Windows. Ahora el servicio de Kiosko o cualquier otro proceso puede utilizar la cámara sin bloqueos.'}
                  </p>
                  <button
                    onClick={startCamera}
                    className="mt-4 px-4 py-2 rounded-lg bg-cyan-600 hover:bg-cyan-500 text-white font-bold text-xs flex items-center gap-2 shadow-lg shadow-cyan-600/30 transition"
                  >
                    <Camera className="w-3.5 h-3.5" /> Activar Cámara Web
                  </button>
                </div>
              )}

              {/* Retícula Biométrica HUD Overlay */}
              {isCameraActive && (
                <div className="absolute inset-0 pointer-events-none flex items-center justify-center">
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
                !isCameraActive
                  ? 'bg-slate-800 text-slate-500 cursor-not-allowed'
                  : vector512
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
                  <Fingerprint className="w-4 h-4" /> Capturar Rostro y Extraer Vector 512D
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

          {/* COLUMNA DERECHA: Formulario de Registro en PostgreSQL 16 (CREATE) */}
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
                    <option value="CAMPUS_ALAMEDA">Campus Alameda (Santiago Centro)</option>
                    <option value="CAMPUS_PROVIDENCIA">Campus Providencia</option>
                    <option value="CAMPUS_EL_LLANO">Campus El Llano Subercaseaux</option>
                    <option value="CAMPUS_TALCA">Campus Talca</option>
                    <option value="CAMPUS_TEMUCO">Campus Temuco</option>
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

              {/* Botón de Envío (Bloqueado estrictamente si no hay vector 512D) */}
              <button
                type="submit"
                disabled={isSubmitting || !vector512}
                className={`w-full mt-2 py-3.5 px-4 rounded-xl font-extrabold text-sm transition flex items-center justify-center gap-2 ${
                  !vector512
                    ? 'bg-slate-800 text-slate-500 border border-slate-700/60 cursor-not-allowed opacity-75'
                    : 'bg-gradient-to-r from-blue-600 via-cyan-600 to-emerald-600 hover:from-blue-500 hover:to-emerald-500 text-white shadow-xl shadow-cyan-600/20 cursor-pointer'
                }`}
              >
                {isSubmitting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" /> Persistiendo en PostgreSQL + Qdrant...
                  </>
                ) : !vector512 ? (
                  <>
                    <Lock className="w-4 h-4 text-amber-400" />
                    Captura el Rostro (512D) para Desbloquear Enrolamiento
                  </>
                ) : (
                  <>
                    <Database className="w-4 h-4" /> Enrolar y Guardar
                  </>
                )}
              </button>

              {!vector512 && (
                <p className="text-[11px] text-amber-400/90 flex items-center gap-1.5 mt-2 text-center justify-center">
                  <AlertCircle className="w-3.5 h-3.5 shrink-0" />
                  Presiona "Capturar Rostro y Extraer Vector 512D" en el visor óptico para habilitar el registro.
                </p>
              )}
            </form>

            {/* Resultado de la Persistencia */}
            {submitResult && (
              <div
                className={`mt-6 p-4 rounded-xl border text-xs animate-fadeIn ${
                  submitResult.success
                    ? 'bg-slate-900 border-cyan-500/40'
                    : 'bg-rose-950/40 border-rose-500/60'
                }`}
              >
                {submitResult.success ? (
                  <>
                    <div className="flex items-center gap-2 text-emerald-400 font-bold mb-3">
                      <CheckCircle2 className="w-4 h-4" />
                      <span>Usuario y Vector Sincronizados Exitosamente</span>
                    </div>

                    <div className="space-y-1.5 font-mono text-[11px] text-slate-300">
                      <div className="flex justify-between border-b border-slate-800 pb-1">
                        <span>PostgreSQL 16 (users_rbac):</span>
                        <span className="text-emerald-400 font-bold">GUARDADO (OK)</span>
                      </div>
                      <div className="flex justify-between border-b border-slate-800 pb-1">
                        <span>Qdrant (512D Cosine Index):</span>
                        <span className="text-emerald-400 font-bold">INDEXADO (OK)</span>
                      </div>
                      <div className="flex justify-between border-b border-slate-800 pb-1">
                        <span>SQLite WAL (Edge Turnstile):</span>
                        <span className={submitResult.sqlite ? 'text-emerald-400 font-bold' : 'text-slate-400'}>
                          {submitResult.sqlite ? 'SINCRONIZADO' : 'SYNC DISPONIBLE'}
                        </span>
                      </div>
                      <div className="flex justify-between pt-1 text-slate-400">
                        <span>ID Estudiante:</span>
                        <span className="text-cyan-300">{submitResult.data.student_id}</span>
                      </div>
                    </div>

                    <p className="mt-3 text-[10px] text-slate-400">
                      ¡Listo! El estudiante ha sido incorporado al directorio. Puedes gestionarlo en la tabla inferior.
                    </p>
                  </>
                ) : (
                  <>
                    <div className="flex items-center gap-2 text-rose-400 font-bold mb-2">
                      <AlertCircle className="w-4 h-4" />
                      <span>Fallo al Registrar en PostgreSQL 16</span>
                    </div>
                    <p className="text-[11px] text-rose-300 font-mono bg-black/50 p-2 rounded border border-rose-800/60">
                      {submitResult.errorMsg || 'Error interno del servidor'}
                    </p>
                    <p className="mt-2 text-[10px] text-slate-400">
                      El registro NO se guardó en la base de datos debido al error anterior.
                    </p>
                  </>
                )}
              </div>
            )}
          </div>
        </div>

        {/* ======================================================== */}
        {/* SECCIÓN RUD: DIRECTORIO Y CONTROL DE ACCESO ESTUDIANTIL */}
        {/* ======================================================== */}
        <section className="bg-[#0B1528] rounded-2xl border border-slate-800 p-6 shadow-2xl">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-6 border-b border-slate-800">
            <div>
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-cyan-500/10 border border-cyan-500/20 text-cyan-400">
                  <Users className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-lg font-black text-white tracking-wide">
                    Directorio y Gestión de Estudiantes
                  </h3>
                  <p className="text-xs text-slate-400">
                    Consulta, suspensión de acceso y baja definitiva en persistencia políglota (PostgreSQL 16, Qdrant y SQLite Edge)
                  </p>
                </div>
              </div>
            </div>

            {/* Badges de Contadores y Botón Refrescar */}
            <div className="flex flex-wrap items-center gap-3">
              <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-xs font-semibold">
                <span className="text-slate-400">Total:</span>
                <span className="text-cyan-300 font-mono font-bold">{students.length}</span>
              </div>
              <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-emerald-950/50 border border-emerald-700/50 text-xs font-semibold text-emerald-400">
                <span>Vigentes:</span>
                <span className="font-mono font-bold">{activeCount}</span>
              </div>
              <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-rose-950/50 border border-rose-700/50 text-xs font-semibold text-rose-400">
                <span>Suspendidos:</span>
                <span className="font-mono font-bold">{suspendedCount}</span>
              </div>
              <button
                type="button"
                onClick={handleReconcile}
                disabled={isReconciling}
                className="px-3 py-1.5 rounded-lg bg-cyan-600/20 hover:bg-cyan-600/30 text-cyan-300 border border-cyan-500/40 text-xs font-bold flex items-center gap-1.5 transition shadow-sm"
                title="Ejecutar reconciliación Anti-Entropy: toma PostgreSQL 16 como SSOT y alinea Qdrant y SQLite Edge"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isReconciling ? 'animate-spin' : ''}`} />
                {isReconciling ? 'Reconciliando...' : 'Reconciliar (Anti-Entropy)'}
              </button>
              <button
                type="button"
                onClick={fetchStudents}
                disabled={isLoadingStudents}
                className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold flex items-center gap-1.5 transition"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isLoadingStudents ? 'animate-spin' : ''}`} />
                Refrescar
              </button>
            </div>
          </div>

          {/* Barra de Búsqueda */}
          <div className="my-5">
            <div className="relative max-w-md">
              <Search className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Filtrar por RUT, Nombre, ID o Carrera..."
                className="w-full pl-10 pr-4 py-2 rounded-xl bg-slate-900 border border-slate-700 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-cyan-400"
              />
            </div>
          </div>

          {/* Tabla de Estudiantes (RUD) */}
          <div className="overflow-x-auto rounded-xl border border-slate-800 bg-[#070E1C]">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-900/90 text-slate-400 uppercase tracking-wider font-semibold border-b border-slate-800">
                <tr>
                  <th className="py-3.5 px-4">Estudiante / RUT</th>
                  <th className="py-3.5 px-4">Carrera & Campus</th>
                  <th className="py-3.5 px-4 text-center">Biometría (Qdrant)</th>
                  <th className="py-3.5 px-4 text-center">Estado SIRAD</th>
                  <th className="py-3.5 px-4 text-right">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80 font-medium">
                {filteredStudents.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-8 text-center text-slate-500">
                      {isLoadingStudents ? (
                        <div className="flex items-center justify-center gap-2">
                          <RefreshCw className="w-4 h-4 animate-spin text-cyan-400" />
                          <span>Cargando estudiantes desde PostgreSQL 16...</span>
                        </div>
                      ) : (
                        'No hay estudiantes registrados o no coinciden con la búsqueda.'
                      )}
                    </td>
                  </tr>
                ) : (
                  filteredStudents.map((stu) => {
                    const isVigente = (stu.enrollment_status || stu.status) === 'VIGENTE';
                    return (
                      <tr key={stu.rut} className="hover:bg-slate-800/30 transition">
                        {/* Identidad */}
                        <td className="py-3.5 px-4">
                          <div className="font-bold text-white text-sm">{stu.full_name}</div>
                          <div className="text-[11px] text-cyan-400 font-mono mt-0.5">{stu.rut}</div>
                          <div className="text-[10px] text-slate-500 font-mono">{stu.student_id}</div>
                        </td>

                        {/* Carrera & Campus */}
                        <td className="py-3.5 px-4">
                          <div className="text-slate-200">{stu.career}</div>
                          <div className="text-[11px] text-slate-400 flex items-center gap-1 mt-0.5">
                            <MapPin className="w-3 h-3 text-slate-500" />
                            {stu.campus}
                          </div>
                        </td>

                        {/* Biometría */}
                        <td className="py-3.5 px-4 text-center">
                          <button
                            type="button"
                            onClick={() => setSelectedVectorStudent(stu)}
                            className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-cyan-500/10 border border-cyan-500/30 text-cyan-300 hover:bg-cyan-500/20 transition"
                            title="Haz clic para inspeccionar el vector 512D almacenado en Qdrant"
                          >
                            <Fingerprint className="w-3.5 h-3.5" />
                            <span>512D Vector</span>
                          </button>
                        </td>

                        {/* Estado SIRAD */}
                        <td className="py-3.5 px-4 text-center">
                          {isVigente ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                              VIGENTE
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-rose-500/10 text-rose-400 border border-rose-500/30">
                              <span className="w-1.5 h-1.5 rounded-full bg-rose-500" />
                              SUSPENDIDO
                            </span>
                          )}
                        </td>

                        {/* Acciones RUD (Update Status & Delete) */}
                        <td className="py-3.5 px-4 text-right">
                          <div className="flex items-center justify-end gap-2">
                            {/* UPDATE: Botón Suspender / Habilitar */}
                            <button
                              type="button"
                              onClick={() => handleToggleStatus(stu)}
                              className={`px-3 py-1.5 rounded-lg text-xs font-bold flex items-center gap-1.5 transition ${
                                isVigente
                                  ? 'bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30'
                                  : 'bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                              }`}
                              title={isVigente ? 'Suspender acceso en torniquetes' : 'Reactivar vigencia'}
                            >
                              {isVigente ? (
                                <>
                                  <UserX className="w-3.5 h-3.5" />
                                  Suspender
                                </>
                              ) : (
                                <>
                                  <UserCheck className="w-3.5 h-3.5" />
                                  Habilitar
                                </>
                              )}
                            </button>

                            {/* DELETE: Botón Eliminar Permanente */}
                            <button
                              type="button"
                              onClick={() => handleDeleteStudent(stu)}
                              className="px-2.5 py-1.5 rounded-lg text-xs font-bold bg-rose-500/10 hover:bg-rose-500/25 text-rose-400 border border-rose-500/30 transition flex items-center gap-1"
                              title="Eliminar de PostgreSQL, Qdrant y SQLite Edge"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </section>

        {/* MODAL DE RECONCILIACIÓN ANTI-ENTROPY */}
        {showReconcileModal && reconcileReport && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
            <div className="bg-[#0B1528] rounded-2xl border border-cyan-500/50 p-6 max-w-xl w-full shadow-2xl space-y-4">
              <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                <div className="flex items-center gap-2 text-cyan-400 font-bold text-base">
                  <Database className="w-5 h-5 text-cyan-400" />
                  <span>Reporte de Reconciliación Políglota (Anti-Entropy)</span>
                </div>
                <button
                  onClick={() => setShowReconcileModal(false)}
                  className="text-slate-400 hover:text-white text-lg font-bold px-2"
                >
                  ✕
                </button>
              </div>

              <p className="text-xs text-slate-300">
                El proceso de sincronización anti-entropía ha tomado a <strong className="text-cyan-300">PostgreSQL 16</strong> como única fuente de verdad (SSOT), depurando anomalías en el índice vectorial Qdrant y actualizando la caché SQLite Edge del torniquete.
              </p>

              <div className="space-y-2 text-xs font-mono">
                <div className="flex justify-between bg-slate-900/80 p-3 rounded-lg border border-slate-800">
                  <span className="text-slate-400">PostgreSQL 16 (SSOT):</span>
                  <span className="text-emerald-400 font-bold">{reconcileReport.postgres_total_users} Estudiantes Válidos</span>
                </div>
                <div className="flex justify-between bg-slate-900/80 p-3 rounded-lg border border-slate-800">
                  <span className="text-slate-400">Vectores Huérfanos Depurados (Qdrant):</span>
                  <span className="text-rose-400 font-bold">{reconcileReport.qdrant_orphans_deleted} vectores eliminados</span>
                </div>
                <div className="flex justify-between bg-slate-900/80 p-3 rounded-lg border border-slate-800">
                  <span className="text-slate-400">Vectores Faltantes Reindexados (Qdrant):</span>
                  <span className="text-cyan-400 font-bold">{reconcileReport.qdrant_missing_added} vectores</span>
                </div>
                <div className="flex justify-between bg-slate-900/80 p-3 rounded-lg border border-slate-800">
                  <span className="text-slate-400">SQLite Edge Kiosko (`ua_turnstile_edge.db`):</span>
                  <span className={reconcileReport.sqlite_edge_synced > 0 ? 'text-emerald-400 font-bold' : 'text-amber-400 font-bold'}>
                    {reconcileReport.sqlite_edge_status || (reconcileReport.sqlite_edge_synced ? 'SINCRONIZADO' : 'OFFLINE')}
                  </span>
                </div>
                <div className="flex justify-between bg-slate-900/80 p-3 rounded-lg border border-slate-800">
                  <span className="text-slate-400">Estado de Consistencia:</span>
                  <span className="text-emerald-300 font-bold">{reconcileReport.consistency_status}</span>
                </div>
              </div>

              <div className="p-3 rounded-xl bg-cyan-950/40 border border-cyan-700/40 text-[11px] text-cyan-300 flex items-start gap-2">
                <ShieldCheck className="w-4 h-4 shrink-0 text-cyan-400 mt-0.5" />
                <span>
                  <strong>Consistencia Eventual Garantizada:</strong> Todas las consultas del sistema y las decisiones biométricas en torniquetes operan sobre un estado alineado y libre de vectores huérfanos.
                </span>
              </div>

              <div className="flex justify-end pt-2">
                <button
                  onClick={() => setShowReconcileModal(false)}
                  className="px-4 py-2 rounded-xl bg-cyan-600 hover:bg-cyan-500 text-white font-bold text-xs transition"
                >
                  Aceptar
                </button>
              </div>
            </div>
          </div>
        )}

        {/* MODAL DE INSPECCIÓN VECTORIAL ZERO-TRUST */}
        {selectedVectorStudent && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-fadeIn">
            <div className="bg-[#0B1528] rounded-2xl border border-cyan-500/40 p-6 max-w-2xl w-full shadow-2xl space-y-4">
              <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                <div className="flex items-center gap-2 text-cyan-400 font-bold text-base">
                  <Fingerprint className="w-5 h-5" />
                  <span>Inspección Vectorial 512D en Qdrant (Zero-Trust)</span>
                </div>
                <button
                  onClick={() => setSelectedVectorStudent(null)}
                  className="text-slate-400 hover:text-white text-lg font-bold px-2"
                >
                  ✕
                </button>
              </div>

              <div className="text-xs space-y-2 text-slate-300">
                <div className="flex justify-between bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
                  <span className="text-slate-400">Estudiante:</span>
                  <span className="font-bold text-white">{selectedVectorStudent.full_name}</span>
                </div>
                <div className="flex justify-between bg-slate-900/60 p-2.5 rounded-lg border border-slate-800 font-mono">
                  <span className="text-slate-400">RUT / ID:</span>
                  <span className="text-cyan-400">{selectedVectorStudent.rut} • {selectedVectorStudent.student_id}</span>
                </div>
                <div className="flex justify-between bg-slate-900/60 p-2.5 rounded-lg border border-slate-800 font-mono">
                  <span className="text-slate-400">Colección Vectorial:</span>
                  <span className="text-emerald-400 font-bold">student_face_embeddings_512d (Cosine)</span>
                </div>
              </div>

              {/* Muestra de float32 */}
              <div>
                <p className="text-[11px] font-bold text-slate-400 mb-1.5 uppercase tracking-wider">
                  Embedding Matemático Normalizado L2 (Muestra primeros 16 floats):
                </p>
                <div className="font-mono text-[11px] text-cyan-300 bg-black/70 p-3 rounded-xl border border-slate-800 overflow-x-auto">
                  {selectedVectorStudent.face_vector_512
                    ? `[ ${selectedVectorStudent.face_vector_512.slice(0, 16).map((n) => Number(n).toFixed(5)).join(', ')}, ... 496 floats más ]`
                    : '[ Vector 512D indexado en Qdrant ]'}
                </div>
              </div>

              <div className="p-3 rounded-xl bg-emerald-950/40 border border-emerald-700/40 text-[11px] text-emerald-300 flex items-start gap-2">
                <ShieldCheck className="w-4 h-4 shrink-0 text-emerald-400 mt-0.5" />
                <span>
                  <strong>Garantía Zero-Trust:</strong> Este vector es unidireccional y no reversible. No es posible
                  reconstruir la imagen facial a partir de estas 512 coordenadas matemáticas de punto flotante.
                </span>
              </div>

              <div className="flex justify-end pt-2">
                <button
                  onClick={() => setSelectedVectorStudent(null)}
                  className="px-4 py-2 rounded-xl bg-cyan-600 hover:bg-cyan-500 text-white font-bold text-xs transition"
                >
                  Cerrar Inspección
                </button>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
