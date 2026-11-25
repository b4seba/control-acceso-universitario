import React, { useState, useRef, useEffect, useMemo, useCallback } from 'react';
import { extract512DVectorFromVideo, initMobileFaceNet } from './utils/vectorExtractor';
import TopHeader from './components/TopHeader';
import FeedbackBanner from './components/FeedbackBanner';
import BiometricCameraPanel from './components/BiometricCameraPanel';
import EnrollmentForm from './components/EnrollmentForm';
import StudentDirectoryTable from './components/StudentDirectoryTable';
import ReconcileModal from './components/ReconcileModal';
import VectorInspectModal from './components/VectorInspectModal';
import ConfirmDeleteModal from './components/ConfirmDeleteModal';

const API_BASE = (import.meta.env.VITE_API_BASE_URL ?? '').replace(/\/$/, '');
const EDGE_CAMERA_BASE = 'http://127.0.0.1:5050';

async function notifyEdgeService(endpoint, payload) {
  try {
    const res = await fetch(`${EDGE_CAMERA_BASE}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    return res.ok || res.status === 201;
  } catch {
    return false;
  }
}

const INITIAL_FORM_DATA = {
  rut: '',
  fullName: '',
  career: '',
  password: '',
};

export default function App() {
  const [formData, setFormData] = useState(INITIAL_FORM_DATA);

  const [isCameraActive, setIsCameraActive] = useState(false);
  const [cameraError, setCameraError] = useState(null);
  const [vector512, setVector512] = useState(null);
  const [isExtracting, setIsExtracting] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitResult, setSubmitResult] = useState(null);
  const [backendStatus, setBackendStatus] = useState('checking');

  const [students, setStudents] = useState([]);
  const [isLoadingStudents, setIsLoadingStudents] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [actionFeedback, setActionFeedback] = useState(null);
  const [selectedVectorStudent, setSelectedVectorStudent] = useState(null);
  const [pendingDeleteStudent, setPendingDeleteStudent] = useState(null);
  const [isDeleting, setIsDeleting] = useState(false);

  const [isReconciling, setIsReconciling] = useState(false);
  const [reconcileReport, setReconcileReport] = useState(null);
  const [showReconcileModal, setShowReconcileModal] = useState(false);

  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const feedbackTimerRef = useRef(null);

  const pushFeedback = useCallback((type, message, autoDismissMs = 0) => {
    if (feedbackTimerRef.current) {
      window.clearTimeout(feedbackTimerRef.current);
      feedbackTimerRef.current = null;
    }
    setActionFeedback({ type, message });
    if (autoDismissMs > 0) {
      feedbackTimerRef.current = window.setTimeout(() => {
        setActionFeedback(null);
        feedbackTimerRef.current = null;
      }, autoDismissMs);
    }
  }, []);

  const checkBackendHealth = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/api/v1/health`, { method: 'GET' });
      setBackendStatus(res.ok ? 'online' : 'offline');
    } catch {
      setBackendStatus('offline');
    }
  }, []);

  const startCamera = useCallback(async () => {
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
      setCameraError(
        'No se pudo acceder a la cámara web. Verifica los permisos del navegador o cierra otras aplicaciones que usen el dispositivo.'
      );
      setIsCameraActive(false);
    }
  }, []);

  const stopCamera = useCallback(() => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
    if (videoRef.current) {
      videoRef.current.srcObject = null;
    }
    setIsCameraActive(false);
  }, []);

  const fetchStudents = useCallback(async () => {
    setIsLoadingStudents(true);
    try {
      const res = await fetch(`${API_BASE}/api/v1/users`, { method: 'GET' });
      if (res.ok) {
        const data = await res.json();
        const normalized = (data.users || []).map((u) => {
          const st = u.enrollment_status || u.status || 'VIGENTE';
          return { ...u, status: st, enrollment_status: st };
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
  }, []);

  useEffect(() => {
    let cancelled = false;
    const bootstrap = async () => {
      await Promise.resolve();
      if (cancelled) return;
      checkBackendHealth();
      startCamera();
      fetchStudents();
      initMobileFaceNet();
    };
    bootstrap();

    return () => {
      cancelled = true;
      stopCamera();
      if (feedbackTimerRef.current) {
        window.clearTimeout(feedbackTimerRef.current);
      }
    };
  }, [checkBackendHealth, startCamera, stopCamera, fetchStudents]);

  const handleFieldChange = useCallback((field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  }, []);

  const handleCaptureFace = async () => {
    if (!videoRef.current || !isCameraActive) {
      pushFeedback('error', 'Activa la cámara antes de capturar el rostro.', 4500);
      return;
    }

    setIsExtracting(true);
    try {
      const vec = await extract512DVectorFromVideo(videoRef.current);
      setVector512(vec);
      pushFeedback('success', 'Vector biométrico 512D extraído exitosamente mediante MobileFaceNet.', 4500);
    } catch (err) {
      console.error('Error extrayendo vector con MobileFaceNet:', err);
      pushFeedback('error', 'No se detectó un rostro válido o falló la extracción del vector 512D.', 5000);
    } finally {
      setIsExtracting(false);
    }
  };

  const handleToggleStatus = async (student) => {
    const currentStatus = student.enrollment_status || student.status || 'VIGENTE';
    const nextStatus = currentStatus === 'VIGENTE' ? 'SUSPENDIDO' : 'VIGENTE';

    setStudents((prev) =>
      prev.map((s) =>
        s.rut === student.rut ? { ...s, status: nextStatus, enrollment_status: nextStatus } : s
      )
    );

    try {
      const res = await fetch(`${API_BASE}/api/v1/users/${encodeURIComponent(student.rut)}/status`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: nextStatus }),
      });

      if (res.ok) {
        await notifyEdgeService('/update_user_status', {
          rut: student.rut,
          student_id: student.student_id,
          status: nextStatus,
        });
        pushFeedback(
          'success',
          `Estado de ${student.full_name} actualizado a ${nextStatus} en PostgreSQL, Qdrant y SQLite Edge.`,
          5000
        );
        fetchStudents();
      } else {
        const data = await res.json().catch(() => ({}));
        fetchStudents();
        pushFeedback('error', data.error || 'No se pudo actualizar el estado del estudiante.', 5000);
      }
    } catch (err) {
      fetchStudents();
      pushFeedback('error', 'Error de comunicación con el backend: ' + err.message, 5000);
    }
  };

  const handleConfirmDelete = async (student) => {
    setIsDeleting(true);
    try {
      const res = await fetch(`${API_BASE}/api/v1/users/${encodeURIComponent(student.rut)}`, {
        method: 'DELETE',
      });

      if (res.ok) {
        setStudents((prev) => prev.filter((s) => s.rut !== student.rut));
        await notifyEdgeService('/delete_user', {
          rut: student.rut,
          student_id: student.student_id,
        });
        setPendingDeleteStudent(null);
        pushFeedback(
          'success',
          `Estudiante ${student.full_name} (${student.rut}) eliminado de todas las bases de datos.`,
          5000
        );
        fetchStudents();
      } else {
        const data = await res.json().catch(() => ({}));
        setPendingDeleteStudent(null);
        pushFeedback('error', data.error || 'Error al eliminar estudiante.', 5000);
      }
    } catch (err) {
      setPendingDeleteStudent(null);
      pushFeedback('error', 'Error de red al intentar eliminar estudiante: ' + err.message, 5000);
    } finally {
      setIsDeleting(false);
    }
  };

  const handleReconcile = async () => {
    setIsReconciling(true);
    try {
      const res = await fetch(`${API_BASE}/api/v1/admin/reconcile`, { method: 'POST' });
      const data = await res.json();
      if (res.ok) {
        setReconcileReport(data.report);
        setShowReconcileModal(true);
        fetchStudents();
        pushFeedback(
          'success',
          'Reconciliación políglota completada: PostgreSQL 16 alineado con Qdrant y SQLite Edge.',
          5000
        );
      } else {
        pushFeedback('error', data.error || 'Error al ejecutar reconciliación políglota.', 5000);
      }
    } catch (err) {
      pushFeedback('error', 'Error de red al conectar con backend Go: ' + err.message, 5000);
    } finally {
      setIsReconciling(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (
      !formData.rut.trim() ||
      !formData.fullName.trim() ||
      !formData.career.trim() ||
      !formData.password.trim()
    ) {
      pushFeedback('error', 'Completa RUT, nombre, carrera y contraseña.', 4500);
      return;
    }

    if (!vector512 || vector512.length !== 512) {
      pushFeedback(
        'error',
        'No puedes enrolar sin capturar el rostro primero. Presiona "Capturar Rostro y Extraer Vector 512D".',
        5000
      );
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

    try {
      const resGo = await fetch(`${API_BASE}/api/v1/auth/register`, {
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
        pushFeedback('error', results.errorMsg);
      }
    } catch (err) {
      results.errorMsg = 'Error al conectar con Backend Go: ' + err.message;
      pushFeedback('error', results.errorMsg);
    }

    results.sqlite = await notifyEdgeService('/enroll', payload);

    setIsSubmitting(false);
    setSubmitResult(results);

    if (results.success) {
      pushFeedback(
        'success',
        `Estudiante ${payload.full_name} enrolado y guardado en PostgreSQL 16 y Qdrant (512D).`,
        5500
      );
      setFormData(INITIAL_FORM_DATA);
      setVector512(null);
      fetchStudents();
    }
  };

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

  const activeCount = useMemo(
    () => students.filter((s) => (s.enrollment_status || s.status) === 'VIGENTE').length,
    [students]
  );
  const suspendedCount = useMemo(
    () => students.filter((s) => (s.enrollment_status || s.status) === 'SUSPENDIDO').length,
    [students]
  );

  return (
    <div className="min-h-screen bg-canvas text-ink font-sans selection:bg-crimson selection:text-white">
      <TopHeader backendStatus={backendStatus} />

      <FeedbackBanner feedback={actionFeedback} onDismiss={() => setActionFeedback(null)} />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 py-8 space-y-10">
        <div className="border-b border-hairline pb-5">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <h2 className="text-2xl sm:text-3xl font-bold text-ink tracking-tight">
              Enrolamiento Biométrico Centralizado
            </h2>
            <span className="font-mono text-xs text-ink-secondary uppercase tracking-wider">
              Modelo 512D · Privacidad Zero-Trust
            </span>
          </div>
          <p className="text-ink-secondary text-sm mt-1.5 max-w-3xl leading-relaxed">
            Capture el rostro en tiempo real para generar un descriptor matemático normalizado de 512 dimensiones.{' '}
            <strong className="font-semibold text-ink">No se almacenan fotografías crudas</strong> en ningún repositorio.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 lg:gap-8 items-start">
          <BiometricCameraPanel
            videoRef={videoRef}
            isCameraActive={isCameraActive}
            cameraError={cameraError}
            isExtracting={isExtracting}
            vector512={vector512}
            onStartCamera={startCamera}
            onStopCamera={stopCamera}
            onCaptureFace={handleCaptureFace}
          />

          <EnrollmentForm
            formData={formData}
            onChangeField={handleFieldChange}
            vector512={vector512}
            isSubmitting={isSubmitting}
            submitResult={submitResult}
            onSubmit={handleSubmit}
          />
        </div>

        <StudentDirectoryTable
          students={students}
          filteredStudents={filteredStudents}
          activeCount={activeCount}
          suspendedCount={suspendedCount}
          searchQuery={searchQuery}
          onSearchChange={setSearchQuery}
          isLoadingStudents={isLoadingStudents}
          isReconciling={isReconciling}
          onReconcile={handleReconcile}
          onRefresh={fetchStudents}
          onInspectVector={setSelectedVectorStudent}
          onToggleStatus={handleToggleStatus}
          onRequestDelete={setPendingDeleteStudent}
        />
      </main>

      <ReconcileModal
        isOpen={showReconcileModal}
        report={reconcileReport}
        onClose={() => setShowReconcileModal(false)}
      />

      <VectorInspectModal
        student={selectedVectorStudent}
        onClose={() => setSelectedVectorStudent(null)}
      />

      <ConfirmDeleteModal
        student={pendingDeleteStudent}
        isDeleting={isDeleting}
        onCancel={() => setPendingDeleteStudent(null)}
        onConfirm={handleConfirmDelete}
      />
    </div>
  );
}
