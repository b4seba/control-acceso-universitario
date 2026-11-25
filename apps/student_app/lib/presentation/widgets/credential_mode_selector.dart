import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../viewmodels/credential_viewmodel.dart';

/// Accessible segmented control switching between NFC HCE and Dynamic 15s QR.
class CredentialModeSelector extends StatelessWidget {
  final CredentialMode activeMode;
  final ValueChanged<CredentialMode> onSelect;

  const CredentialModeSelector({
    super.key,
    required this.activeMode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentItem(
              label: 'NFC HCE',
              icon: Icons.nfc_rounded,
              selected: activeMode == CredentialMode.nfcHce,
              onTap: () => onSelect(CredentialMode.nfcHce),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentItem(
              label: 'QR Dinámico',
              icon: Icons.qr_code_2_rounded,
              selected: activeMode == CredentialMode.dynamicQr,
              onTap: () => onSelect(CredentialMode.dynamicQr),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppTheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        elevation: selected ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? AppTheme.institutionalCrimson : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
