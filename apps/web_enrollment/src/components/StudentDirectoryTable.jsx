import React from 'react';
import {
  Fingerprint,
  RefreshCw,
  Search,
  Trash2,
  UserCheck,
  UserX,
  Users,
  X,
} from 'lucide-react';

/**
 * Institutional student directory ledger supporting search, vector inspection,
 * status toggling, deletion, and polyglot Anti-Entropy reconciliation.
 */
export default function StudentDirectoryTable({
  students,
  filteredStudents,
  activeCount,
  suspendedCount,
  searchQuery,
  onSearchChange,
  isLoadingStudents,
  isReconciling,
  onReconcile,
  onRefresh,
  onInspectVector,
  onToggleStatus,
  onRequestDelete,
}) {
  return (
    <section
      aria-labelledby="directory-title"
      className="bg-surface rounded-xl border border-hairline p-5 sm:p-6 space-y-5"
    >
      {/* Header & Summary Telemetry */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 pb-5 border-b border-hairline">
        <div className="flex items-start gap-3">
          <span className="w-9 h-9 rounded-lg bg-subtle border border-hairline flex items-center justify-center text-ink shrink-0 mt-0.5">
            <Users className="w-4 h-4" aria-hidden="true" />
          </span>
          <div>
            <h2 id="directory-title" className="text-lg font-semibold text-ink leading-tight">
              Directorio y Control de Acceso Estudiantil
            </h2>
            <p className="text-xs text-ink-secondary mt-0.5">
              Gestión RUD y consistencia políglota entre PostgreSQL 16, Qdrant y SQLite Edge
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {/* Clean tabular counters without decorative pill spam */}
          <dl className="inline-flex items-center divide-x divide-hairline rounded-lg border border-hairline bg-canvas px-3 py-1.5 text-xs">
            <div className="pr-3 flex items-center gap-1.5">
              <dt className="text-ink-secondary">Total</dt>
              <dd className="font-mono font-semibold text-ink tabular-nums">{students.length}</dd>
            </div>
            <div className="px-3 flex items-center gap-1.5">
              <dt className="text-ink-secondary">Vigentes</dt>
              <dd className="font-mono font-semibold text-success tabular-nums">{activeCount}</dd>
            </div>
            <div className="pl-3 flex items-center gap-1.5">
              <dt className="text-ink-secondary">Suspendidos</dt>
              <dd className="font-mono font-semibold text-danger tabular-nums">{suspendedCount}</dd>
            </div>
          </dl>

          <button
            type="button"
            onClick={onReconcile}
            disabled={isReconciling}
            title="Ejecuta reconciliación Anti-Entropy tomando PostgreSQL 16 como fuente única de verdad"
            className="min-h-[38px] px-3 py-1.5 rounded-lg border border-crimson/35 bg-crimson-soft hover:bg-crimson/10 text-crimson text-xs font-semibold inline-flex items-center gap-1.5 transition-colors duration-150 disabled:opacity-60"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isReconciling ? 'animate-spin' : ''}`} aria-hidden="true" />
            <span>{isReconciling ? 'Reconciliando...' : 'Reconciliar (Anti-Entropy)'}</span>
          </button>

          <button
            type="button"
            onClick={onRefresh}
            disabled={isLoadingStudents}
            className="min-h-[38px] px-3 py-1.5 rounded-lg border border-border-strong bg-surface hover:bg-subtle text-ink text-xs font-semibold inline-flex items-center gap-1.5 transition-colors duration-150 disabled:opacity-60"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isLoadingStudents ? 'animate-spin' : ''}`} aria-hidden="true" />
            <span>Refrescar</span>
          </button>
        </div>
      </div>

      {/* Search Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="relative w-full max-w-md">
          <label htmlFor="directory-search" className="sr-only">
            Filtrar estudiantes por RUT, nombre, ID o carrera
          </label>
          <Search
            className="w-4 h-4 text-ink-muted absolute left-3.5 top-3 pointer-events-none"
            aria-hidden="true"
          />
          <input
            id="directory-search"
            type="text"
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Filtrar por RUT, Nombre, ID o Carrera..."
            className="w-full min-h-[40px] pl-10 pr-9 py-2 rounded-lg bg-surface border border-border-strong text-xs sm:text-sm text-ink placeholder:text-ink-muted focus:outline-none focus:border-crimson focus:ring-1 focus:ring-crimson"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => onSearchChange('')}
              aria-label="Limpiar búsqueda"
              className="absolute right-1.5 top-1 w-8 h-8 rounded-md text-ink-muted hover:text-ink hover:bg-subtle flex items-center justify-center"
            >
              <X className="w-3.5 h-3.5" aria-hidden="true" />
            </button>
          )}
        </div>

        <p className="text-xs text-ink-secondary tabular-nums">
          Mostrando {filteredStudents.length} de {students.length} registros
        </p>
      </div>

      {/* Directory Ledger Table */}
      <div className="overflow-x-auto rounded-lg border border-hairline">
        <table className="w-full text-left text-xs border-collapse">
          <thead className="bg-canvas text-ink-secondary uppercase tracking-wider text-[11px] font-semibold border-b border-hairline">
            <tr>
              <th scope="col" className="py-3 px-4">Estudiante / RUT</th>
              <th scope="col" className="py-3 px-4">Carrera</th>
              <th scope="col" className="py-3 px-4 text-center">Biometría</th>
              <th scope="col" className="py-3 px-4 text-center">Estado SIRAD</th>
              <th scope="col" className="py-3 px-4 text-right">Acciones</th>
            </tr>
          </thead>

          <tbody className="divide-y divide-hairline bg-surface">
            {isLoadingStudents && students.length === 0 ? (
              Array.from({ length: 4 }).map((_, idx) => (
                <tr key={idx} aria-hidden="true">
                  <td className="py-4 px-4">
                    <div className="h-4 w-36 bg-subtle rounded mb-1.5" />
                    <div className="h-3 w-24 bg-subtle rounded" />
                  </td>
                  <td className="py-4 px-4">
                    <div className="h-4 w-44 bg-subtle rounded mb-1.5" />
                    <div className="h-3 w-28 bg-subtle rounded" />
                  </td>
                  <td className="py-4 px-4 text-center">
                    <div className="h-7 w-24 bg-subtle rounded mx-auto" />
                  </td>
                  <td className="py-4 px-4 text-center">
                    <div className="h-6 w-20 bg-subtle rounded mx-auto" />
                  </td>
                  <td className="py-4 px-4 text-right">
                    <div className="h-8 w-28 bg-subtle rounded ml-auto" />
                  </td>
                </tr>
              ))
            ) : filteredStudents.length === 0 ? (
              <tr>
                <td colSpan={5} className="py-12 px-4 text-center">
                  <div className="flex flex-col items-center gap-2 max-w-sm mx-auto">
                    <Users className="w-8 h-8 text-ink-muted" aria-hidden="true" />
                    <p className="text-sm font-medium text-ink">
                      {searchQuery
                        ? 'Sin coincidencias para el filtro aplicado'
                        : 'No hay estudiantes enrolados'}
                    </p>
                    <p className="text-xs text-ink-secondary">
                      {searchQuery
                        ? 'Intente con otro RUT, nombre o limpie el filtro actual.'
                        : 'Utilice el formulario superior para registrar el primer estudiante con su vector 512D.'}
                    </p>
                    {searchQuery ? (
                      <button
                        type="button"
                        onClick={() => onSearchChange('')}
                        className="mt-2 min-h-[36px] px-3 py-1.5 rounded-lg border border-border-strong bg-surface hover:bg-subtle text-xs font-semibold text-ink"
                      >
                        Limpiar búsqueda
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={onRefresh}
                        className="mt-2 min-h-[36px] px-3 py-1.5 rounded-lg border border-border-strong bg-surface hover:bg-subtle text-xs font-semibold text-ink"
                      >
                        Refrescar directorio
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ) : (
              filteredStudents.map((stu) => {
                const isVigente = (stu.enrollment_status || stu.status) === 'VIGENTE';

                return (
                  <tr key={stu.rut} className="hover:bg-canvas/70 transition-colors duration-150">
                    {/* Identidad */}
                    <td className="py-3.5 px-4 align-middle">
                      <div className="font-semibold text-ink text-sm">{stu.full_name}</div>
                      <div className="text-xs text-ink-secondary font-mono mt-0.5 tabular-nums">
                        {stu.rut}
                      </div>
                      <div className="text-[11px] text-ink-muted font-mono">{stu.student_id}</div>
                    </td>

                    {/* Carrera */}
                    <td className="py-3.5 px-4 align-middle">
                      <div className="text-ink font-medium text-xs sm:text-sm">{stu.career}</div>
                      <div className="text-[11px] text-ink-secondary font-mono mt-0.5">
                        {stu.role || 'ESTUDIANTE'}
                      </div>
                    </td>

                    {/* Biometría */}
                    <td className="py-3.5 px-4 text-center align-middle">
                      <button
                        type="button"
                        onClick={() => onInspectVector(stu)}
                        title="Inspeccionar vector 512D almacenado en Qdrant"
                        className="min-h-[34px] inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium bg-canvas border border-border-strong text-ink hover:border-ink/40 hover:bg-subtle transition-colors duration-150"
                      >
                        <Fingerprint className="w-3.5 h-3.5 text-crimson" aria-hidden="true" />
                        <span className="font-mono">512D</span>
                      </button>
                    </td>

                    {/* Estado SIRAD */}
                    <td className="py-3.5 px-4 text-center align-middle">
                      {isVigente ? (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[11px] font-semibold bg-success-bg text-success border border-success/20">
                          <span className="w-1.5 h-1.5 rounded-full bg-success" aria-hidden="true" />
                          VIGENTE
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[11px] font-semibold bg-danger-bg text-danger border border-danger/20">
                          <span className="w-1.5 h-1.5 rounded-full bg-danger" aria-hidden="true" />
                          SUSPENDIDO
                        </span>
                      )}
                    </td>

                    {/* Acciones RUD */}
                    <td className="py-3.5 px-4 text-right align-middle">
                      <div className="inline-flex items-center justify-end gap-2">
                        <button
                          type="button"
                          onClick={() => onToggleStatus(stu)}
                          title={isVigente ? 'Suspender acceso en torniquetes' : 'Reactivar vigencia'}
                          className={`min-h-[36px] px-3 py-1.5 rounded-lg text-xs font-semibold inline-flex items-center gap-1.5 border transition-colors duration-150 ${
                            isVigente
                              ? 'bg-warning-bg hover:bg-warning/10 text-warning border-warning/30'
                              : 'bg-success-bg hover:bg-success/10 text-success border-success/30'
                          }`}
                        >
                          {isVigente ? (
                            <>
                              <UserX className="w-3.5 h-3.5" aria-hidden="true" />
                              <span>Suspender</span>
                            </>
                          ) : (
                            <>
                              <UserCheck className="w-3.5 h-3.5" aria-hidden="true" />
                              <span>Habilitar</span>
                            </>
                          )}
                        </button>

                        <button
                          type="button"
                          onClick={() => onRequestDelete(stu)}
                          aria-label={`Eliminar permanentemente a ${stu.full_name}`}
                          title="Eliminar de PostgreSQL, Qdrant y SQLite Edge"
                          className="min-h-[36px] min-w-[36px] px-2.5 py-1.5 rounded-lg text-xs font-semibold bg-danger-bg hover:bg-danger/10 text-danger border border-danger/30 transition-colors duration-150 inline-flex items-center justify-center"
                        >
                          <Trash2 className="w-3.5 h-3.5" aria-hidden="true" />
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
  );
}
