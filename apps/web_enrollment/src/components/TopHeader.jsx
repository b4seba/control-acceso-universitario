import React from 'react';
import { Landmark, Database } from 'lucide-react';

const STATUS_META = {
  online: {
    label: 'Go Backend: ONLINE',
    shortLabel: 'ONLINE',
    dotClass: 'bg-success',
    textClass: 'text-success',
    boxClass: 'bg-success-bg border-success/25',
  },
  offline: {
    label: 'Go Backend: STANDBY',
    shortLabel: 'STANDBY',
    dotClass: 'bg-danger',
    textClass: 'text-danger',
    boxClass: 'bg-danger-bg border-danger/25',
  },
  checking: {
    label: 'Verificando enlace...',
    shortLabel: 'Enlace...',
    dotClass: 'bg-warning',
    textClass: 'text-warning',
    boxClass: 'bg-warning-bg border-warning/25',
  },
};

/**
 * Institutional header bar displaying brand identity and real backend connectivity.
 */
export default function TopHeader({ backendStatus }) {
  const status = STATUS_META[backendStatus] || STATUS_META.checking;

  return (
    <header className="sticky top-0 z-40 bg-surface/95 backdrop-blur-sm border-b border-hairline">
      <div className="h-1 w-full bg-crimson" aria-hidden="true" />
      <div className="max-w-7xl mx-auto px-3.5 sm:px-6 py-2.5 sm:py-3.5 flex items-center justify-between gap-2.5 sm:gap-4">
        <div className="flex items-center gap-2.5 sm:gap-3.5 min-w-0 flex-1">
          <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-lg bg-crimson text-white flex items-center justify-center shrink-0">
            <Landmark className="w-4 h-4 sm:w-5 sm:h-5" aria-hidden="true" />
          </div>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5">
              <span className="text-[11px] sm:text-xs font-bold tracking-[0.12em] sm:tracking-[0.14em] uppercase text-crimson">
                Universidad Autónoma
              </span>
              <span className="hidden sm:inline text-xs text-ink-muted" aria-hidden="true">
                /
              </span>
              <span className="hidden sm:inline text-xs font-semibold text-ink-secondary">
                SIRAD Control de Acceso
              </span>
            </div>
            <h1 className="text-[13px] sm:text-base font-semibold text-ink leading-tight">
              Portal Central de Enrolamiento Biométrico
            </h1>
          </div>
        </div>

        <div className="flex items-center gap-2 sm:gap-3 text-xs shrink-0">
          <div
            className={`inline-flex items-center gap-1.5 sm:gap-2 px-2.5 sm:px-3 py-1.5 rounded-lg border font-medium text-[11px] sm:text-xs ${status.boxClass} ${status.textClass}`}
            role="status"
            aria-live="polite"
          >
            <span className={`w-2 h-2 rounded-full shrink-0 ${status.dotClass}`} aria-hidden="true" />
            <span className="sm:hidden">{status.shortLabel}</span>
            <span className="hidden sm:inline">{status.label}</span>
          </div>

          <div className="hidden md:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-subtle border border-hairline text-ink-secondary font-mono text-[11px]">
            <Database className="w-3.5 h-3.5 text-ink-muted" aria-hidden="true" />
            <span>PG16 · Qdrant 512D</span>
          </div>
        </div>
      </div>
    </header>
  );
}
