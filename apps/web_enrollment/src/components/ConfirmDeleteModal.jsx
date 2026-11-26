import React from 'react';
import { AlertTriangle } from 'lucide-react';
import ModalDialog from './ModalDialog';

/**
 * Accessible confirmation dialog replacing native window.confirm for permanent deletion.
 */
export default function ConfirmDeleteModal({ student, isDeleting, onCancel, onConfirm }) {
  return (
    <ModalDialog
      isOpen={Boolean(student)}
      onClose={onCancel}
      titleId="confirm-delete-title"
      title="Confirmar eliminación permanente"
      icon={AlertTriangle}
      role="alertdialog"
      maxWidthClass="max-w-md"
    >
      {student && (
        <div className="space-y-4">
          <p className="text-xs sm:text-sm text-ink-secondary leading-relaxed">
            Esta acción eliminará el registro relacional en <strong className="text-ink">PostgreSQL 16</strong>, su vector 512D en <strong className="text-ink">Qdrant</strong> y su autorización en <strong className="text-ink">SQLite Edge</strong>.
          </p>

          <dl className="divide-y divide-hairline rounded-lg border border-hairline bg-canvas text-xs px-3.5">
            <div className="flex justify-between py-2 gap-2">
              <dt className="text-ink-secondary">Nombre</dt>
              <dd className="font-semibold text-ink">{student.full_name}</dd>
            </div>
            <div className="flex justify-between py-2 gap-2 font-mono">
              <dt className="text-ink-secondary font-sans">RUT</dt>
              <dd className="text-ink">{student.rut}</dd>
            </div>
            <div className="flex justify-between py-2 gap-2 font-mono">
              <dt className="text-ink-secondary font-sans">ID</dt>
              <dd className="text-ink">{student.student_id}</dd>
            </div>
          </dl>

          <div className="flex items-center justify-end gap-2.5 pt-1">
            <button
              type="button"
              onClick={onCancel}
              disabled={isDeleting}
              className="min-h-[40px] px-4 py-2 rounded-lg border border-border-strong bg-surface hover:bg-subtle text-ink font-semibold text-xs transition-colors duration-150"
            >
              Cancelar
            </button>
            <button
              type="button"
              onClick={() => onConfirm(student)}
              disabled={isDeleting}
              className="min-h-[40px] px-4 py-2 rounded-lg bg-danger hover:bg-danger/90 text-white font-semibold text-xs transition-colors duration-150 disabled:opacity-60"
            >
              {isDeleting ? 'Eliminando...' : 'Eliminar permanentemente'}
            </button>
          </div>
        </div>
      )}
    </ModalDialog>
  );
}
