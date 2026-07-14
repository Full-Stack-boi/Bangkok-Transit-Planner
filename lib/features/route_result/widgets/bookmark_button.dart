import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/route_result.dart';
import '../../../core/constants/translation_helper.dart';
import '../../favorites/favorites_view_model.dart';
import '../../../providers/providers.dart';

class BookmarkButton extends ConsumerWidget {
  final RouteResult result;
  final ThemeData theme;
  final AppLocalizations t;
  final String localeCode;

  const BookmarkButton({
    super.key,
    required this.result,
    required this.theme,
    required this.t,
    required this.localeCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesRepo = ref.watch(favoritesRepositoryProvider);
    final isSaved = favoritesRepo.isRouteSaved(
      result.origin.id,
      result.destination.id,
    );

    return IconButton(
      icon: Icon(
        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: isSaved ? theme.appColors.favoriteColor : null,
      ),
      onPressed: () async {
        if (isSaved) {
          await favoritesRepo.deleteRoute(
            result.origin.id,
            result.destination.id,
          );
          ref.read(favoritesViewModelProvider.notifier).refresh();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.routeResult.routeDeletedSuccess)),
            );
          }
        } else {
          _showSaveRouteDialog(context, ref, result, t, localeCode);
        }
      },
    );
  }

  Future<void> _showSaveRouteDialog(
    BuildContext context,
    WidgetRef ref,
    RouteResult result,
    AppLocalizations t,
    String localeCode,
  ) async {
    final originName = localeCode == 'th'
        ? result.origin.nameTh
        : result.origin.nameEn;
    final destName = localeCode == 'th'
        ? result.destination.nameTh
        : result.destination.nameEn;

    TextEditingController? controller;

    return showDialog<void>(
      context: context,
      builder: (context) {
        controller ??= TextEditingController(text: '$originName - $destName');
        return AlertDialog(
          title: Text(t.routeResult.saveRouteBtn),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: t.routeResult.routeNameLabel,
              hintText: t.routeResult.routeNameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.common.cancelBtn),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller!.text.trim();
                if (name.isNotEmpty) {
                  await ref
                      .read(favoritesViewModelProvider.notifier)
                      .saveRoute(
                        originId: result.origin.id,
                        destinationId: result.destination.id,
                        originName: result.origin.nameTh,
                        destinationName: result.destination.nameTh,
                        routeName: name,
                        originLat: result.origin.lat,
                        originLng: result.origin.lng,
                        destinationLat: result.destination.lat,
                        destinationLng: result.destination.lng,
                      );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.routeResult.routeSavedSuccess)),
                    );
                  }
                }
              },
              child: Text(t.common.saveBtn),
            ),
          ],
        );
      },
    ).whenComplete(() => controller?.dispose());
  }
}
