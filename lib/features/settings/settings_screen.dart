import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

/// Settings screen supporting interactive Theme and Language selection
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final localeCode = ref.watch(localeProvider);

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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(t.settings.themeLight),
                value: ThemeMode.light,
                groupValue: themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setTheme(mode);
                  }
                  Navigator.pop(context);
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(t.settings.themeDark),
                value: ThemeMode.dark,
                groupValue: themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setTheme(mode);
                  }
                  Navigator.pop(context);
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(t.settings.themeSystem),
                value: ThemeMode.system,
                groupValue: themeMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setTheme(mode);
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    }

    void showLanguageDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.settings.langSetting),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(t.settings.langTh),
                value: 'th',
                groupValue: localeCode,
                onChanged: (lang) {
                  if (lang != null) {
                    ref.read(localeProvider.notifier).setLocale(lang);
                  }
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: Text(t.settings.langEn),
                value: 'en',
                groupValue: localeCode,
                onChanged: (lang) {
                  if (lang != null) {
                    ref.read(localeProvider.notifier).setLocale(lang);
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.navigation.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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

          // About Screen Option
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(t.settings.aboutSetting),
              subtitle: const Text('BKK Transit Planner'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'BKK Transit Planner',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.directions_transit_rounded, size: 48),
                  children: [
                    const SizedBox(height: 8),
                    Text(t.settings.aboutDesc),
                  ],
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
}
