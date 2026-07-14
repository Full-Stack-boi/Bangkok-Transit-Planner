import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import '../map/cached_tile_provider.dart';
import '../../core/constants/translation_helper.dart';

/// Settings screen supporting interactive Theme and Language selection
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final localeCode = ref.watch(localeProvider);
    final mockLocation = ref.watch(mockLocationProvider);

    String getThemeModeText(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.light:
          return t.settings.themeLight;
        case ThemeMode.dark:
          return t.settings.themeDark;
        case ThemeMode.system:
          return t.settings.themeSystem;
      }
    }

    String getLanguageText(String code) {
      if (code == 'th') return t.settings.langTh;
      return t.settings.langEn;
    }

    void showThemeDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.settings.themeSetting),
          content: RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeModeProvider.notifier).setTheme(mode);
              }
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(t.settings.themeLight),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(t.settings.themeDark),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(t.settings.themeSystem),
                  value: ThemeMode.system,
                ),
              ],
            ),
          ),
        ),
      );
    }

    void showLanguageDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.settings.langSetting),
          content: RadioGroup<String>(
            groupValue: localeCode,
            onChanged: (lang) {
              if (lang != null) {
                ref.read(localeProvider.notifier).setLocale(lang);
              }
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text(t.settings.langTh),
                  value: 'th',
                ),
                RadioListTile<String>(
                  title: Text(t.settings.langEn),
                  value: 'en',
                ),
              ],
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.navigation.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(context, ref, authState, t, theme),
          const SizedBox(height: 16),
          // Theme Option
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_rounded),
              title: Text(t.settings.themeSetting),
              subtitle: Text(getThemeModeText(themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: showThemeDialog,
            ),
          ),
          const SizedBox(height: 8),

          // Language Option
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(t.settings.langSetting),
              subtitle: Text(getLanguageText(localeCode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: showLanguageDialog,
            ),
          ),
          const SizedBox(height: 8),

          // Offline Map Option (Manual check/download updates)
          !kIsWeb
              ? Card(
                  child: ListTile(
                    leading: const Icon(Icons.map_rounded),
                    title: Text(t.settings.offlineMapTitle),
                    subtitle: Text(t.settings.offlineMapSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(t.settings.downloadDialogTitle),
                          content: Text(t.settings.downloadDialogBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text(t.common.cancelBtn),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(dialogContext);

                                // Mark prefetch as NOT completed in SharedPreferences so it will run
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(
                                  'map_prefetch_completed_v6_greater',
                                  false,
                                );

                                // Clear the pause flag
                                CachedTileProvider.isPaused = false;

                                // Let's get the stations from the transit repository provider
                                final stations = ref
                                    .read(transitRepositoryProvider)
                                    .stations;

                                // Set prefetch state in riverpod
                                ref
                                    .read(mapPrefetchProvider.notifier)
                                    .startPrefetch(6914);

                                // Start downloading
                                CachedTileProvider.prefetchBangkokTiles(
                                  stations,
                                  onStart: (total) {
                                    ref
                                        .read(mapPrefetchProvider.notifier)
                                        .startPrefetch(total);
                                  },
                                  onProgress:
                                      (current, success, cached, error) {
                                        ref
                                            .read(mapPrefetchProvider.notifier)
                                            .updateProgress(
                                              current: current,
                                              success: success,
                                              cached: cached,
                                              error: error,
                                            );
                                      },
                                  onFinish: (completed, lostConnection) async {
                                    if (completed) {
                                      ref
                                          .read(mapPrefetchProvider.notifier)
                                          .finishPrefetch();
                                      PaintingBinding.instance.imageCache
                                          .clear();
                                      PaintingBinding.instance.imageCache
                                          .clearLiveImages();
                                      final p =
                                          await SharedPreferences.getInstance();
                                      await p.setBool(
                                        'map_prefetch_completed_v6_greater',
                                        true,
                                      );
                                    } else {
                                      ref
                                          .read(mapPrefetchProvider.notifier)
                                          .pausePrefetch();
                                    }
                                  },
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(t.settings.downloadStarted),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              child: Text(t.common.download),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
          const SizedBox(height: 8),

          // Location Simulation Option (DEBUG ONLY - Hidden in release build)
          if (kDebugMode) ...[
            Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.4),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.bug_report_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  t.utility.debugSimGpsTitle,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  mockLocation != null
                      ? t.utility.debugSimGpsActive(
                          mockLocation.latitude.toStringAsFixed(4),
                          mockLocation.longitude.toStringAsFixed(4),
                        )
                      : t.utility.debugSimGpsDisabled,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLocationSimulationDialog(
                  context,
                  ref,
                  mockLocation,
                  theme,
                  localeCode,
                  t,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // About Screen Option
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(t.settings.aboutSetting),
              subtitle: const Text('BKK Transit Planner'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(24),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        // App Name
                        Text(
                          'BKK Transit Planner',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Version
                        Text(
                          '${t.settings.versionLabel} 1.0.0',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        // Description
                        Text(
                          t.settings.aboutDesc,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Legalese Disclaimer Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: Text(
                            t.settings.disclaimer,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Copyright Text
                        Text(
                          t.settings.copyright,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          showLicensePage(
                            context: context,
                            applicationName: 'BKK Transit Planner',
                            applicationVersion: '1.0.0',
                            applicationIcon: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 48,
                                height: 48,
                                fit: BoxFit.contain,
                              ),
                            ),
                            applicationLegalese: t.settings.copyright,
                          );
                        },
                        child: Text(t.settings.viewLicenses),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(t.common.closeBtn),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Version Info Display
          Center(
            child: Text(
              t.settings.versionInfo,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    AppLocalizations t,
    ThemeData theme,
  ) {
    if (authState.isAuthenticated) {
      final String displayName =
          authState.displayName ??
          authState.user?.email?.split('@').first ??
          t.auth.defaultUsername;
      final String email = authState.user?.email ?? '';

      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                backgroundImage: authState.avatarUrl != null
                    ? NetworkImage(authState.avatarUrl!)
                    : null,
                child: authState.avatarUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                onPressed: () {
                  ref.read(authProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(
                    Icons.account_circle_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.auth.signInToSync,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.auth.signInToSyncDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showLocationSimulationDialog(
    BuildContext context,
    WidgetRef ref,
    Position? mockPos,
    ThemeData theme,
    String localeCode,
    AppLocalizations t,
  ) {
    final transitRepo = ref.read(transitRepositoryProvider);
    final stations = transitRepo.stations;

    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = stations.where((s) {
              final query = searchQuery.toLowerCase();
              return s.nameEn.toLowerCase().contains(query) ||
                  s.nameTh.contains(query) ||
                  s.id.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.bug_report_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Simulate Location'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search station...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    if (mockPos != null)
                      ListTile(
                        leading: const Icon(
                          Icons.gps_off_rounded,
                          color: Colors.red,
                        ),
                        title: Text(t.utility.debugSimGpsDisableOption),
                        subtitle: Text(t.utility.debugSimGpsDisableSubtitle),
                        onTap: () {
                          ref
                              .read(mockLocationProvider.notifier)
                              .clearMockLocation();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t.utility.debugSimGpsDisabledSnack),
                            ),
                          );
                        },
                      ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final station = filtered[index];
                          final isCurrent =
                              mockPos != null &&
                              (mockPos.latitude - station.lat).abs() < 0.0001 &&
                              (mockPos.longitude - station.lng).abs() < 0.0001;

                          return ListTile(
                            leading: Icon(
                              Icons.directions_transit_rounded,
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              localeCode == 'th'
                                  ? station.nameTh
                                  : station.nameEn,
                            ),
                            subtitle: Text(
                              '${station.id} • ${station.lat.toStringAsFixed(4)}, ${station.lng.toStringAsFixed(4)}',
                            ),
                            trailing: isCurrent
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                  )
                                : null,
                            onTap: () {
                              ref
                                  .read(mockLocationProvider.notifier)
                                  .setMockLocation(station.lat, station.lng);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t.utility.debugSimGpsEnabledSnack(
                                      localeCode == 'th'
                                          ? station.nameTh
                                          : station.nameEn,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
