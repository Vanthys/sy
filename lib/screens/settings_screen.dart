import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/theme_provider.dart';
import '../logic/vault_provider.dart';
import 'settings/about_settings_screen.dart';
import 'settings/appearance_settings_screen.dart';
import 'settings/backup_settings_screen.dart';
import 'settings/vault_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final vaultState = ref.watch(vaultProvider);

    String themeName = switch (themeMode) {
      AppThemeMode.light => 'Light',
      AppThemeMode.dark => 'Dark',
      AppThemeMode.amoled => 'AMOLED',
      AppThemeMode.system => 'System',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SettingsSection(
            title: 'Appearance',
            tiles: [
              _NavTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Theme: $themeName',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Privacy & Security',
            tiles: [
              _NavTile(
                icon: Icons.shield_outlined,
                title: 'Privacy & Vault',
                subtitle: vaultState.isVaultUnlocked
                    ? 'Vault is unlocked'
                    : 'Manage vault passphrase and security options',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VaultSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Data',
            tiles: [
              _NavTile(
                icon: Icons.backup_outlined,
                title: 'Backup & Restore',
                subtitle: 'Create or restore an encrypted backup',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BackupSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'About',
            tiles: [
              _NavTile(
                icon: Icons.info_outlined,
                title: 'About SY3',
                subtitle: 'Version, licenses',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AboutSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...tiles,
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
