import 'package:flutter/material.dart';
import '../../domain/models/student_user.dart';
import '../theme/app_theme.dart';

/// Tactile Apple-Wallet-inspired institutional student credential card.
class DigitalIdCard extends StatelessWidget {
  final StudentUser user;

  const DigitalIdCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isVigente = user.isVigente;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardBurgundy,
            AppTheme.cardBurgundyDeep,
          ],
        ),
        border: Border.all(
          color: isVigente ? AppTheme.cardBorder : AppTheme.statusDenied,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Institutional header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UNIVERSIDAD AUTÓNOMA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'Credencial Estudiantil SIRAD',
                        style: TextStyle(
                          color: AppTheme.cardTextMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(
                Icons.contactless_outlined,
                color: Colors.white.withValues(alpha: 0.78),
                size: 22,
                semanticLabel: 'Credencial habilitada para lectura sin contacto',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Identity body
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                ),
                child: Center(
                  child: Text(
                    user.avatarInitials,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.career,
                      style: const TextStyle(
                        color: AppTheme.cardTextMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'RUT ${user.rut}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontFamilyFallback: AppTheme.monoFallback,
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.16)),
          const SizedBox(height: 14),

          // Footer status seal & student ID
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 12,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isVigente ? AppTheme.statusVigenteBg : AppTheme.statusDeniedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVigente ? Icons.verified_rounded : Icons.block_rounded,
                      size: 14,
                      color: isVigente ? AppTheme.statusVigente : AppTheme.statusDenied,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isVigente ? 'MATRÍCULA VIGENTE 2026' : 'SUSPENDIDO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isVigente ? AppTheme.statusVigente : AppTheme.statusDenied,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                user.id.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.cardTextMuted,
                  fontFamily: 'monospace',
                  fontFamilyFallback: AppTheme.monoFallback,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
