import React from 'react';
import { CheckCircle2, AlertCircle, X } from 'lucide-react';

/**
 * Accessible inline notification banner for RUD and biometric actions.
 */
export default function FeedbackBanner({ feedback, onDismiss }) {
  if (!feedback) return null;

  const isSuccess = feedback.type === 'success';

  return (
    <div className="max-w-7xl mx-auto px-3.5 sm:px-6 pt-3.5 sm:pt-5">
      <div
        role={isSuccess ? 'status' : 'alert'}
        aria-live="polite"
        className={`rounded-xl border border-l-4 px-3.5 sm:px-4 py-2.5 sm:py-3 flex items-start sm:items-center justify-between gap-2.5 sm:gap-4 text-xs sm:text-sm font-medium animate-fadeIn ${
          isSuccess
            ? 'bg-success-bg border-success/25 border-l-success text-success'
            : 'bg-danger-bg border-danger/25 border-l-danger text-danger'
        }`}
      >
        <div className="flex items-start sm:items-center gap-2.5 min-w-0 flex-1">
          {isSuccess ? (
            <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5 sm:mt-0" aria-hidden="true" />
          ) : (
            <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 sm:mt-0" aria-hidden="true" />
          )}
          <span className="leading-snug break-words min-w-0">{feedback.message}</span>
        </div>

        <button
          type="button"
          onClick={onDismiss}
          aria-label="Cerrar notificación"
          className="min-h-[38px] min-w-[38px] sm:min-h-[32px] sm:min-w-[32px] px-2 rounded-lg hover:bg-black/5 inline-flex items-center justify-center shrink-0 transition-colors duration-150"
        >
          <X className="w-4 h-4" aria-hidden="true" />
        </button>
      </div>
    </div>
  );
}
