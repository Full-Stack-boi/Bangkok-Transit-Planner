import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../providers/providers.dart';

class TransitCardRow extends ConsumerWidget {
  final ThemeData theme;
  final AppLocalizations t;
  final UserCardsState cardState;

  const TransitCardRow({
    super.key,
    required this.theme,
    required this.t,
    required this.cardState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.utility.cardsSectionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.utility.cardsSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.8,
          ),
          children: [
            _buildCompactCardPreview(
              context: context,
              ref: ref,
              theme: theme,
              t: t,
              networkId: 'BTS',
              cardName: t.utility.rabbitCardName,
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              activeType: cardState.btsCardType,
              options: [
                _CardOption(
                  value: 'standard',
                  title: t.utility.optionStandardTitle,
                  subtitle: t.utility.optionStandardSubtitle,
                ),
                _CardOption(
                  value: 'student',
                  title: t.utility.optionStudentTitle,
                  subtitle: t.utility.optionStudentBtsSubtitle,
                ),
                _CardOption(
                  value: 'senior',
                  title: t.utility.optionSeniorTitle,
                  subtitle: t.utility.optionSeniorBtsSubtitle,
                ),
                _CardOption(
                  value: 'trip_package',
                  title: t.utility.optionTripPackageTitle,
                  subtitle: t.utility.optionTripPackageBtsSubtitle,
                ),
              ],
            ),
            _buildCompactCardPreview(
              context: context,
              ref: ref,
              theme: theme,
              t: t,
              networkId: 'MRT',
              cardName: t.utility.mrtCardName,
              gradient: LinearGradient(
                colors: [Colors.blue.shade500, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              activeType: cardState.mrtCardType,
              options: [
                _CardOption(
                  value: 'standard',
                  title: t.utility.optionStandardTitle,
                  subtitle: t.utility.optionStandardSubtitle,
                ),
                _CardOption(
                  value: 'student',
                  title: t.utility.optionStudentTitle,
                  subtitle: t.utility.optionStudentMrtSubtitle,
                ),
                _CardOption(
                  value: 'senior',
                  title: t.utility.optionSeniorTitle,
                  subtitle: t.utility.optionSeniorMrtSubtitle,
                ),
              ],
            ),
            _buildCompactCardPreview(
              context: context,
              ref: ref,
              theme: theme,
              t: t,
              networkId: 'ARL',
              cardName: t.utility.arlCardName,
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              activeType: cardState.arlCardType,
              options: [
                _CardOption(
                  value: 'standard',
                  title: t.utility.optionStandardTitle,
                  subtitle: t.utility.optionStandardSubtitle,
                ),
                _CardOption(
                  value: 'student',
                  title: t.utility.optionStudentTitle,
                  subtitle: t.utility.optionStudentArlSubtitle,
                ),
                _CardOption(
                  value: 'senior',
                  title: t.utility.optionSeniorTitle,
                  subtitle: t.utility.optionSeniorArlSubtitle,
                ),
              ],
            ),
            _buildCompactCardPreview(
              context: context,
              ref: ref,
              theme: theme,
              t: t,
              networkId: 'SRT',
              cardName: t.utility.srtCardName,
              gradient: LinearGradient(
                colors: [Colors.red.shade800, Colors.red.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              activeType: cardState.srtCardType,
              options: [
                _CardOption(
                  value: 'standard',
                  title: t.utility.optionStandardTitle,
                  subtitle: t.utility.optionStandardSubtitle,
                ),
                _CardOption(
                  value: 'student',
                  title: t.utility.optionStudentTitle,
                  subtitle: t.utility.optionStudentSrtSubtitle,
                ),
                _CardOption(
                  value: 'senior',
                  title: t.utility.optionSeniorTitle,
                  subtitle: t.utility.optionSeniorSrtSubtitle,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactCardPreview({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required AppLocalizations t,
    required String networkId,
    required String cardName,
    required Gradient gradient,
    required String activeType,
    required List<_CardOption> options,
  }) {
    final activeOption = options.firstWhere(
      (opt) => opt.value == activeType,
      orElse: () => options.first,
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showCardDetailsBottomSheet(
            context: context,
            ref: ref,
            theme: theme,
            networkId: networkId,
            cardName: cardName,
            gradient: gradient,
            activeType: activeType,
            options: options,
          );
        },
        child: Container(
          decoration: BoxDecoration(gradient: gradient),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cardName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.credit_card_rounded,
                    color: Colors.white70,
                    size: 12,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeOption.title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeOption.subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCardDetailsBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required String networkId,
    required String cardName,
    required Gradient gradient,
    required String activeType,
    required List<_CardOption> options,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _CardDetailBottomSheetContent(
          theme: theme,
          networkId: networkId,
          cardName: cardName,
          gradient: gradient,
          initialActiveType: activeType,
          options: options,
        );
      },
    );
  }
}

class _CardDetailBottomSheetContent extends ConsumerStatefulWidget {
  final ThemeData theme;
  final String networkId;
  final String cardName;
  final Gradient gradient;
  final String initialActiveType;
  final List<_CardOption> options;

  const _CardDetailBottomSheetContent({
    required this.theme,
    required this.networkId,
    required this.cardName,
    required this.gradient,
    required this.initialActiveType,
    required this.options,
  });

  @override
  ConsumerState<_CardDetailBottomSheetContent> createState() =>
      _CardDetailBottomSheetContentState();
}

class _CardDetailBottomSheetContentState
    extends ConsumerState<_CardDetailBottomSheetContent> {
  late String _activeType;

  @override
  void initState() {
    super.initState();
    _activeType = widget.initialActiveType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    Color networkColor = Colors.green.shade600;
    if (widget.networkId == 'MRT') networkColor = Colors.blue.shade700;
    if (widget.networkId == 'ARL') networkColor = Colors.red.shade700;
    if (widget.networkId == 'SRT') networkColor = Colors.red.shade800;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: RadioGroup<String>(
          groupValue: _activeType,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _activeType = val;
              });
              ref
                  .read(userCardsProvider.notifier)
                  .setCardType(widget.networkId, val);
              Future.delayed(const Duration(milliseconds: 150), () {
                if (context.mounted) {
                  Navigator.pop(context);
                }
              });
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: networkColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.cardName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...widget.options.map((opt) {
                final isSelected = opt.value == _activeType;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeType = opt.value;
                      });
                      ref
                          .read(userCardsProvider.notifier)
                          .setCardType(widget.networkId, opt.value);
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? networkColor.withValues(alpha: 0.08)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? networkColor
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.12,
                                ),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? networkColor : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  opt.subtitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isSelected
                                        ? networkColor.withValues(alpha: 0.8)
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RadioGroup(
                            groupValue: _activeType,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _activeType = val;
                                });
                                ref
                                    .read(userCardsProvider.notifier)
                                    .setCardType(widget.networkId, val);
                                Future.delayed(
                                  const Duration(milliseconds: 150),
                                  () {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                );
                              }
                            },
                            child: Radio<String>(
                              value: opt.value,
                              activeColor: networkColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// class RadioGroup<T> extends StatelessWidget {
//   final T groupValue;
//   final ValueChanged<T?> onChanged;
//   final Widget child;

//   const RadioGroup({
//     super.key,
//     required this.groupValue,
//     required this.onChanged,
//     required this.child,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return child;
//   }
// }

class _CardOption {
  final String value;
  final String title;
  final String subtitle;

  const _CardOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}
