import React, { useState } from 'react';
import {
  AlertCircle,
  CheckCircle2,
  Database,
  Eye,
  EyeOff,
  Lock,
  RefreshCw,
  School,
  User,
} from 'lucide-react';

/**
 * Academic student enrollment form bound to biometric 512D capture state.
 */
export default function EnrollmentForm({
  formData,
  onChangeField,
  vector512,
  isSubmitting,
  submitResult,
  onSubmit,
}) {
  const [showPassword, setShowPassword] = useState(false);

  const inputBaseClass =
    'w-full min-h-[42px] pl-10 pr-4 py-2 rounded-lg bg-surface border border-border-strong text-sm text-ink placeholder:text-ink-muted focus:outline-none focus:border-crimson focus:ring-1 focus:ring-crimson transition-colors duration-150';

  return (
    <section
      aria-labelledby="enrollment-form-title"
      className="lg:col-span-5 bg-surface rounded-xl border border-hairline p-5 sm:p-6"
    >
      <div className="flex items-center gap-2.5 pb-4 mb-5 border-b border-hairline">
        <span className="w-8 h-8 rounded-lg bg-subtle border border-hairline flex items-center justify-center text-crimson">
          <Database className="w-4 h-4" aria-hidden="true" />
        </span>
        <div>
          <h2 id="enrollment-form-title" className="text-base font-semibold text-ink leading-tight">
            Ficha Académica SIRAD
          </h2>
          <p className="text-xs text-ink-secondary">
            Registro relacional en PostgreSQL 16 + índice Qdrant
          </p>
        </div>
      </div>

      <form onSubmit={onSubmit} className="space-y-4">
        {/* RUT Institucional */}
        <div>
          <label htmlFor="field-rut" className="block text-xs font-semibold text-ink-secondary mb-1.5">
            RUT Institucional <span className="text-crimson" aria-hidden="true">*</span>
          </label>
          <div className="relative">
            <User className="w-4 h-4 text-ink-muted absolute left-3.5 top-3 pointer-events-none" aria-hidden="true" />
            <input
              id="field-rut"
              type="text"
              required
              value={formData.rut}
              onChange={(e) => onChangeField('rut', e.target.value)}
              className={`${inputBaseClass} font-mono`}
              placeholder="Ej. 12.345.678-9"
            />
          </div>
        </div>

        {/* Nombre Completo */}
        <div>
          <label htmlFor="field-fullname" className="block text-xs font-semibold text-ink-secondary mb-1.5">
            Nombre Completo <span className="text-crimson" aria-hidden="true">*</span>
          </label>
          <div className="relative">
            <User className="w-4 h-4 text-ink-muted absolute left-3.5 top-3 pointer-events-none" aria-hidden="true" />
            <input
              id="field-fullname"
              type="text"
              required
              value={formData.fullName}
              onChange={(e) => onChangeField('fullName', e.target.value)}
              className={inputBaseClass}
              placeholder="Nombre completo del estudiante"
            />
          </div>
        </div>

        {/* Carrera */}
        <div>
          <label htmlFor="field-career" className="block text-xs font-semibold text-ink-secondary mb-1.5">
            Carrera <span className="text-crimson" aria-hidden="true">*</span>
          </label>
          <div className="relative">
            <School className="w-4 h-4 text-ink-muted absolute left-3.5 top-3 pointer-events-none" aria-hidden="true" />
            <input
              id="field-career"
              type="text"
              required
              value={formData.career}
              onChange={(e) => onChangeField('career', e.target.value)}
              className={inputBaseClass}
              placeholder="Ej. Ingeniería Civil Informática"
            />
          </div>
        </div>

        {/* Contraseña */}
        <div>
          <label htmlFor="field-password" className="block text-xs font-semibold text-ink-secondary mb-1.5">
            Contraseña SIRAD <span className="text-crimson" aria-hidden="true">*</span>
          </label>
          <div className="relative">
            <Lock className="w-4 h-4 text-ink-muted absolute left-3.5 top-3 pointer-events-none" aria-hidden="true" />
            <input
              id="field-password"
              type={showPassword ? 'text' : 'password'}
              required
              value={formData.password}
              onChange={(e) => onChangeField('password', e.target.value)}
              className={`${inputBaseClass} pr-11`}
              placeholder="Crea una contraseña de acceso"
            />
            <button
              type="button"
              onClick={() => setShowPassword((prev) => !prev)}
              aria-label={showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'}
              className="absolute right-1.5 top-1 w-9 h-9 rounded-md text-ink-secondary hover:text-ink hover:bg-subtle flex items-center justify-center transition-colors duration-150"
            >
              {showPassword ? (
                <EyeOff className="w-4 h-4" aria-hidden="true" />
              ) : (
                <Eye className="w-4 h-4" aria-hidden="true" />
              )}
            </button>
          </div>
        </div>

        {/* Botón de Envío (Bloqueado hasta tener vector 512D) */}
        <button
          type="submit"
          disabled={isSubmitting || !vector512}
          className={`w-full mt-2 min-h-[46px] py-3 px-4 rounded-lg font-semibold text-sm flex items-center justify-center gap-2 transition-colors duration-150 ${
            !vector512
              ? 'bg-subtle text-ink-muted border border-hairline cursor-not-allowed'
              : 'bg-crimson hover:bg-crimson-hover text-white'
          }`}
        >
          {isSubmitting ? (
            <>
              <RefreshCw className="w-4 h-4 animate-spin" aria-hidden="true" />
              <span>Persistiendo en PostgreSQL + Qdrant...</span>
            </>
          ) : !vector512 ? (
            <>
              <Lock className="w-4 h-4 text-warning" aria-hidden="true" />
              <span>Capture el rostro (512D) para habilitar</span>
            </>
          ) : (
            <>
              <Database className="w-4 h-4" aria-hidden="true" />
              <span>Enrolar y Guardar</span>
            </>
          )}
        </button>

        {!vector512 && (
          <p className="text-xs text-ink-secondary flex items-center gap-1.5 pt-0.5">
            <AlertCircle className="w-3.5 h-3.5 text-warning shrink-0" aria-hidden="true" />
            <span>
              Presione &ldquo;Capturar Rostro y Extraer Vector 512D&rdquo; en la estación óptica para desbloquear el envío.
            </span>
          </p>
        )}
      </form>

      {/* Resultado de la Persistencia */}
      {submitResult && (
        <div
          className={`mt-5 p-4 rounded-lg border text-xs animate-fadeIn ${
            submitResult.success
              ? 'bg-canvas border-hairline'
              : 'bg-danger-bg border-danger/30'
          }`}
        >
          {submitResult.success ? (
            <div className="space-y-3">
              <div className="flex items-center gap-2 text-success font-semibold">
                <CheckCircle2 className="w-4 h-4 shrink-0" aria-hidden="true" />
                <span>Estudiante y descriptor 512D sincronizados</span>
              </div>

              <dl className="divide-y divide-hairline font-mono text-[11px] bg-surface rounded-md border border-hairline px-3">
                <div className="flex justify-between py-2 gap-2">
                  <dt className="text-ink-secondary">PostgreSQL 16 (users_rbac)</dt>
                  <dd className="text-success font-semibold">GUARDADO</dd>
                </div>
                <div className="flex justify-between py-2 gap-2">
                  <dt className="text-ink-secondary">Qdrant (512D Cosine)</dt>
                  <dd className="text-success font-semibold">INDEXADO</dd>
                </div>
                <div className="flex justify-between py-2 gap-2">
                  <dt className="text-ink-secondary">SQLite WAL (Edge)</dt>
                  <dd className={submitResult.sqlite ? 'text-success font-semibold' : 'text-ink-secondary'}>
                    {submitResult.sqlite ? 'SINCRONIZADO' : 'SYNC DISPONIBLE'}
                  </dd>
                </div>
                <div className="flex justify-between py-2 gap-2">
                  <dt className="text-ink-secondary">ID Estudiante</dt>
                  <dd className="text-ink font-semibold">{submitResult.data.student_id}</dd>
                </div>
              </dl>
            </div>
          ) : (
            <div className="space-y-2">
              <div className="flex items-center gap-2 text-danger font-semibold">
                <AlertCircle className="w-4 h-4 shrink-0" aria-hidden="true" />
                <span>No se pudo registrar en PostgreSQL 16</span>
              </div>
              <p className="text-[11px] text-danger font-mono bg-surface p-2.5 rounded border border-danger/25">
                {submitResult.errorMsg || 'Error interno del servidor'}
              </p>
            </div>
          )}
        </div>
      )}
    </section>
  );
}
