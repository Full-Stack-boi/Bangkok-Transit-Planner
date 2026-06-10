import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_rounded),
              title: const Text('ธีม'),
              subtitle: const Text('Dark Mode'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 8),

          // Language
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_rounded),
              title: const Text('ภาษา'),
              subtitle: const Text('ไทย'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 8),

          // About
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('เกี่ยวกับ'),
              subtitle: const Text('BKK Transit Planner v1.0.0'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 24),

          // Version info
          Center(
            child: Text(
              'BKK Transit Planner\nv1.0.0',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
