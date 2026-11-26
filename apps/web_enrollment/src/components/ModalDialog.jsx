import React, { useEffect, useRef } from 'react';
import { X } from 'lucide-react';

/**
 * Accessible modal dialog wrapper with Escape handling, backdrop dismiss,
 * and automatic focus management.
 */
export default function ModalDialog({
  isOpen,
  onClose,
  titleId,
  title,
  icon: Icon,
  role = 'dialog',
  maxWidthClass = 'max-w-xl',
  children,
}) {
  const closeButtonRef = useRef(null);
  const dialogRef = useRef(null);
  const previousFocusRef = useRef(null);

  useEffect(() => {
    if (!isOpen) return undefined;

    previousFocusRef.current = document.activeElement;
    const focusTimer = window.setTimeout(() => {
      closeButtonRef.current?.focus();
    }, 0);

    const handleKeyDown = (event) => {
      if (event.key === 'Escape') {
        event.stopPropagation();
        onClose();
        return;
      }

      if (event.key === 'Tab' && dialogRef.current) {
        const focusable = dialogRef.current.querySelectorAll(
          'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
        );
        if (focusable.length === 0) return;

        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => {
      window.clearTimeout(focusTimer);
      document.removeEventListener('keydown', handleKeyDown);
      if (previousFocusRef.current && typeof previousFocusRef.current.focus === 'function') {
        previousFocusRef.current.focus();
      }
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-[#18181B]/45 backdrop-blur-[2px] animate-fadeIn"
      onClick={(e) => {
        if (e.target === e.currentTarget) {
          onClose();
        }
      }}
    >
      <div
        ref={dialogRef}
        role={role}
        aria-modal="true"
        aria-labelledby={titleId}
        className={`bg-surface rounded-xl border border-hairline shadow-xl w-full ${maxWidthClass} p-6 space-y-5 text-ink`}
      >
        <div className="flex items-start justify-between gap-4 pb-3.5 border-b border-hairline">
          <div className="flex items-center gap-2.5">
            {Icon && (
              <span className="w-8 h-8 rounded-lg bg-subtle border border-hairline flex items-center justify-center text-crimson shrink-0">
                <Icon className="w-4 h-4" aria-hidden="true" />
              </span>
            )}
            <h3 id={titleId} className="text-base font-semibold text-ink leading-snug">
              {title}
            </h3>
          </div>
          <button
            ref={closeButtonRef}
            type="button"
            onClick={onClose}
            aria-label="Cerrar ventana"
            className="w-9 h-9 rounded-lg border border-transparent hover:border-hairline hover:bg-subtle text-ink-secondary hover:text-ink flex items-center justify-center transition-colors duration-150"
          >
            <X className="w-4 h-4" aria-hidden="true" />
          </button>
        </div>

        {children}
      </div>
    </div>
  );
}
