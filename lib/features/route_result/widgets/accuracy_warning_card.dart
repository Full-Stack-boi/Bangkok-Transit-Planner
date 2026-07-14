import 'package:flutter/material.dart';
import '../../../core/constants/translation_helper.dart';

class AccuracyWarningCard extends StatelessWidget {
  final ThemeData theme;
  final String localeCode;
  final AppLocalizations t;

  const AccuracyWarningCard({
    super.key,
    required this.theme,
    required this.localeCode,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.routeResult.accuracyWarning,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.routeResult.accuracyBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showReportDialog(context, localeCode, theme, t),
                  child: Text(
                    t.routeResult.reportIssueLink,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(
    BuildContext context,
    String localeCode,
    ThemeData theme,
    AppLocalizations t,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.routeResult.reportDialogTitle),
        content: Text(t.routeResult.reportDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.cancelBtn),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t.routeResult.reportSuccess),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
            child: Text(t.utility.submitReportBtn),
          ),
        ],
      ),
    );
  }
}
