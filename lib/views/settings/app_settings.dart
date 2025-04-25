// app_settings.dart
// Settings screen with notifications, account tools … and a palette picker.
// ───────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cateredtoyou/services/theme_manager.dart';   // ← NEW
import 'package:cateredtoyou/widgets/main_scaffold.dart';  // add

/// App-wide settings page
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  // toggles
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _autoCheckUpdates = true;

  // password form controllers
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordFormKey           = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

          @override
        Widget build(BuildContext context) {
          return MainScaffold(
            title: 'Settings',
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: _showHelpDialog,
              ),
            ],
     body: ListView(        // ← remainder unchanged
        padding: const EdgeInsets.all(16),
        children: [
          // ── Notifications ───────────────────────────────────
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            'Enable Notifications',
            'Receive alerts for events and updates',
            Icons.notifications,
            _notificationsEnabled,
            (v) => setState(() => _notificationsEnabled = v),
          ),
          _buildSwitchTile(
            'Sound',
            'Play sound with notifications',
            Icons.volume_up,
            _soundEnabled,
            (v) => setState(() => _soundEnabled = v),
            enabled: _notificationsEnabled,
          ),
          const Divider(),

          // ── App Updates ─────────────────────────────────────
          _buildSectionHeader('App Updates'),
          _buildSwitchTile(
            'Auto-check for Updates',
            'Automatically check for app updates',
            Icons.system_update,
            _autoCheckUpdates,
            (v) => setState(() => _autoCheckUpdates = v),
          ),
          const Divider(),

          // ── Data management ─────────────────────────────────
          _buildSectionHeader('Data Management'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Clear Cache'),
            subtitle: const Text('Free up storage space'),
            onTap: () => _showConfirmDialog(
              'Clear Cache',
              'Are you sure you want to clear the cache? This will not delete any of your data.',
              () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              ),
            ),
          ),
          const Divider(),

          // ── Appearance  (🎨 NEW) ────────────────────────────
          _buildSectionHeader('Appearance'),
          Consumer<ThemeManager>(
            builder: (context, tm, __) => Column(
              children: [
                _buildThemeTile(
                  ctx: context,
                  title: 'Honey Yellow',
                  preset: ThemePreset.honey,
                  current: tm.preset,
                  onTap: () => tm.setPreset(ThemePreset.honey),
                ),
                _buildThemeTile(
                  ctx: context,
                  title: 'Royal Blue',
                  preset: ThemePreset.royalBlue,
                  current: tm.preset,
                  onTap: () => tm.setPreset(ThemePreset.royalBlue),
                ),
              ],
            ),
          ),
          const Divider(),

          // ── Account ────────────────────────────────────────
          _buildSectionHeader('Account'),
          Consumer<AuthService>(
            builder: (_, auth, __) {
              final email = auth.currentUser?.email ?? 'Not logged in';
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Current User'),
                    subtitle: Text(email),
                  ),
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text('Change Password'),
                    onTap: () => _showChangePasswordDialog(context, auth),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout'),
                    onTap: () => _showConfirmDialog(
                      'Logout',
                      'Are you sure you want to logout?',
                      () async {
                        final router = GoRouter.of(context);
                        try {
                          await auth.signOut();
                          if (mounted) router.go('/login');
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error logging out: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(),

          // ── About ───────────────────────────────────────────
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0 (Build 1234)'),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Catered To You'),
            subtitle: const Text('We make catering easy'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Development Team'),
            subtitle: const Text('CSUN COMP490/491'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () => _showStaticDialog('Terms of Service',
                'By using Catered To You, you agree to these terms ...'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _showStaticDialog('Privacy Policy',
                'We collect information to provide better services ...'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Reusable widgets / helpers ───────────────────────────────────────────
  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
  }) =>
      SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        secondary: Icon(icon),
        value: enabled ? value : false,
        onChanged: enabled ? onChanged : null,
      );

  // NEW helper for palette picker
  Widget _buildThemeTile({
    required BuildContext ctx,
    required String title,
    required ThemePreset preset,
    required ThemePreset current,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: const Icon(Icons.color_lens_outlined),
        title: Text(title),
        trailing: current == preset
            ? const Icon(Icons.check, color: Colors.green)
            : null,
        onTap: onTap,
      );

  // dialogs -----------------------------------------------------------------
  void _showConfirmDialog(
      String title, String msg, VoidCallback onConfirm) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showStaticDialog(String title, String content) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      );

  void _showHelpDialog() => _showStaticDialog('Settings Help', '''
Notifications – control how and when you receive alerts.
App Updates – configure automatic update checks.
Data Management – clear cache to free storage.
Account – view info, change password, logout.
Appearance – switch between colour palettes.
About – legal & team info.
''');

  // password change dialog (unchanged) --------------------------------------
  void _showChangePasswordDialog(
      BuildContext ctx, AuthService authService) {/* …keep your existing long implementation here… */}
}
