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
          return t.get('theme_light');
        case ThemeMode.dark:
          return t.get('theme_dark');
        case ThemeMode.system:
          return t.get('theme_system');
      }
    }

    String getLanguageText(String code) {
      if (code == 'th') return t.get('lang_th');
      return t.get('lang_en');
    }

    void showThemeDialog() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.get('theme_setting')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(t.get('theme_light')),
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
                title: Text(t.get('theme_dark')),
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
                title: Text(t.get('theme_system')),
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
          title: Text(t.get('lang_setting')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(t.get('lang_th')),
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
                title: Text(t.get('lang_en')),
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
        title: Text(t.get('settings_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Option
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_rounded),
              title: Text(t.get('theme_setting')),
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
              title: Text(t.get('lang_setting')),
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
              title: Text(t.get('about_setting')),
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
                    const Text('แอปพลิเคชันวางแผนเดินทางรถไฟฟ้ากรุงเทพฯ พัฒนาด้วย Flutter & Riverpod'),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Version Info Display
          Center(
            child: Text(
              t.get('version_info'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
