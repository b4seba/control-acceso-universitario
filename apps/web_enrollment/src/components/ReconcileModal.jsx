import React from 'react';
import { Database, ShieldCheck } from 'lucide-react';
import ModalDialog from './ModalDialog';

/**
 * Accessible modal displaying the Polyglot Anti-Entropy reconciliation report.
 */
export default function ReconcileModal({ isOpen, report, onClose }) {
  return (
    <ModalDialog
      isOpen={isOpen && Boolean(report)}
      onClose={onClose}
      titleId="reconcile-modal-title"
      title="Reporte de Reconciliación Políglota (Anti-Entropy)"
      icon={Database}
      maxWidthClass="max-w-xl"
    >
      {report && (
        <div className="space-y-4">
          <p className="text-xs text-ink-secondary leading-relaxed">
            La sincronización tomó a <strong className="text-ink">PostgreSQL 16</strong> como fuente única de verdad (SSOT), depurando anomalías en Qdrant y alineando la caché SQLite Edge del torniquete.
          </p>

          <dl className="divide-y divide-hairline rounded-lg border border-hairline bg-canvas text-xs font-mono px-3.5 tabular-nums">
            <div className="flex justify-between py-2.5 gap-3">
              <dt className="text-ink-secondary font-sans">PostgreSQL 16 (SSOT)</dt>
              <dd className="text-success font-semibold">
                {report.postgres_total_users} estudiantes válidos
              </dd>
            </div>
            <div className="flex justify-between py-2.5 gap-3">
              <dt className="text-ink-secondary font-sans">Vectores huérfanos depurados (Qdrant)</dt>
              <dd className="text-danger font-semibold">
                {report.qdrant_orphans_deleted} eliminados
              </dd>
            </div>
            <div className="flex justify-between py-2.5 gap-3">
              <dt className="text-ink-secondary font-sans">Vectores faltantes reindexados (Qdrant)</dt>
              <dd className="text-ink font-semibold">
                {report.qdrant_missing_added} vectores
              </dd>
            </div>
            <div className="flex justify-between py-2.5 gap-3">
              <dt className="text-ink-secondary font-sans">SQLite Edge Kiosko (ua_turnstile_edge.db)</dt>
              <dd className={report.sqlite_edge_synced > 0 ? 'text-success font-semibold' : 'text-warning font-semibold'}>
                {report.sqlite_edge_status || (report.sqlite_edge_synced ? 'SINCRONIZADO' : 'OFFLINE')}
              </dd>
            </div>
            <div className="flex justify-between py-2.5 gap-3">
              <dt className="text-ink-secondary font-sans">Estado de consistencia</dt>
              <dd className="text-success font-semibold">{report.consistency_status}</dd>
            </div>
          </dl>

          <div className="p-3.5 rounded-lg bg-canvas border border-hairline text-xs text-ink-secondary flex items-start gap-2.5">
            <ShieldCheck className="w-4 h-4 shrink-0 text-crimson mt-0.5" aria-hidden="true" />
            <p className="leading-relaxed">
              <strong className="text-ink">Consistencia eventual verificada:</strong> Las validaciones biométricas operan sobre un estado alineado entre motores.
            </p>
          </div>

          <div className="flex justify-end pt-1">
            <button
              type="button"
              onClick={onClose}
              className="min-h-[40px] px-4 py-2 rounded-lg bg-crimson hover:bg-crimson-hover text-white font-semibold text-xs transition-colors duration-150"
            >
              Aceptar
            </button>
          </div>
        </div>
      )}
    </ModalDialog>
  );
}
