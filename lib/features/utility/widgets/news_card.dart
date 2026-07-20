import 'package:flutter/material.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../services/transit_news_service.dart';

class NewsCard extends StatelessWidget {
  final ThemeData theme;
  final AppLocalizations t;
  final TransitNewsArticle item;
  final VoidCallback onTap;

  const NewsCard({
    super.key,
    required this.theme,
    required this.t,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = TransitColors.getLineColor(item.lineId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.isTh
                          ? item.titleTh
                          : (item.titleEn.isNotEmpty
                                ? item.titleEn
                                : item.titleTh),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.isTh
                          ? item.bodyTh
                          : (item.bodyEn.isNotEmpty
                                ? item.bodyEn
                                : item.bodyTh),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
