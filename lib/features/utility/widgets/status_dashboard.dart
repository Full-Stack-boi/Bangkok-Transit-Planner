import 'package:flutter/material.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../services/transit_news_service.dart';
import 'transit_line_status_card.dart';

class StatusDashboard extends StatelessWidget {
  final ThemeData theme;
  final AppLocalizations t;
  final List<TransitLineStatus> statuses;

  const StatusDashboard({
    super.key,
    required this.theme,
    required this.t,
    required this.statuses,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.utility.statusSectionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 10,
                mainAxisSpacing: 8,
                mainAxisExtent: 52,
              ),
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                return TransitLineStatusCard(
                  theme: theme,
                  t: t,
                  item: statuses[index],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
