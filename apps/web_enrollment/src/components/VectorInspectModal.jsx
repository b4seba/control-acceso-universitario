import React from 'react';
import { Fingerprint, ShieldCheck } from 'lucide-react';
import ModalDialog from './ModalDialog';

/**
 * Accessible modal displaying L2-normalized 512D embedding metadata from Qdrant.
 */
export default function VectorInspectModal({ student, onClose }) {
  return (
    <ModalDialog
      isOpen={Boolean(student)}
      onClose={onClose}
      titleId="vector-modal-title"
      title="Inspección Vectorial 512D (Qdrant)"
      icon={Fingerprint}
      maxWidthClass="max-w-2xl"
    >
      {student && (
        <div className="space-y-4">
          <dl className="divide-y divide-hairline rounded-lg border border-hairline bg-canvas text-xs px-3.5">
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-2.5 gap-0.5 sm:gap-3">
              <dt className="text-ink-secondary">Estudiante</dt>
              <dd className="font-semibold text-ink break-words sm:text-right">{student.full_name}</dd>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-2.5 gap-0.5 sm:gap-3 font-mono">
              <dt className="text-ink-secondary font-sans">RUT / ID</dt>
              <dd className="text-ink font-medium break-all sm:text-right">
                {student.rut} · {student.student_id}
              </dd>
            </div>
            <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-2.5 gap-0.5 sm:gap-3 font-mono">
              <dt className="text-ink-secondary font-sans">Colección Vectorial</dt>
              <dd className="text-success font-semibold break-all sm:text-right">
                student_face_embeddings_512d (Cosine)
              </dd>
            </div>
          </dl>

          <div>
            <p className="text-xs font-semibold text-ink-secondary mb-1.5">
              Embedding matemático normalizado L2 (muestra de 16 coordenadas)
            </p>
            <div className="font-mono text-[11px] text-ink bg-canvas p-3 rounded-lg border border-hairline overflow-x-auto">
              {student.face_vector_512
                ? `[ ${student.face_vector_512.slice(0, 16).map((n) => Number(n).toFixed(5)).join(', ')}, ... +496 valores más ]`
                : '[ Vector 512D indexado en Qdrant ]'}
            </div>
          </div>

          <div className="p-3.5 rounded-lg bg-success-bg border border-success/20 text-xs text-success flex items-start gap-2.5">
            <ShieldCheck className="w-4 h-4 shrink-0 mt-0.5" aria-hidden="true" />
            <p className="leading-relaxed">
              <strong>Descriptor unidireccional:</strong> Estas 512 coordenadas de punto flotante no permiten reconstruir la fotografía facial original.
            </p>
          </div>

          <div className="flex justify-end pt-1">
            <button
              type="button"
              onClick={onClose}
              className="w-full sm:w-auto min-h-[44px] sm:min-h-[40px] px-4 py-2 rounded-lg bg-ink hover:bg-ink/90 text-white font-semibold text-xs transition-colors duration-150"
            >
              Cerrar Inspección
            </button>
          </div>
        </div>
      )}
    </ModalDialog>
  );
}
