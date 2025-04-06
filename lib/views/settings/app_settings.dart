import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cateredtoyou/services/theme_manager.dart';

/// App Settings Screen
/// This screen allows users to configure app-wide preferences
/// and settings like appearance, notifications, and account details.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _selectedLanguage = 'English';
  bool _useMetric = true;
  bool _autoCheckUpdates = true;
  bool _dataSync = true;
  
  // List of available languages
  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
  ];

  @override
  Widget build(BuildContext context) {
    // Access ThemeManager from the provider
    final themeManager = Provider.of<ThemeManager>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance section
          _buildSectionHeader('Appearance'),
          _buildSwitchTile(
            'Dark Mode',
            'Switch between light and dark theme',
            Icons.dark_mode,
            // Use the ThemeManager's value for dark mode:
            themeManager.isDarkMode,
            (value) {
              // Toggle the theme using the ThemeManager
              themeManager.toggleTheme(value);
            },
          ),
          const Divider(),
          
          // Notifications section
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            'Enable Notifications',
            'Receive alerts for events and updates',
            Icons.notifications,
            _notificationsEnabled,
            (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          _buildSwitchTile(
            'Sound',
            'Play sound with notifications',
            Icons.volume_up,
            _soundEnabled,
            (value) {
              setState(() {
                _soundEnabled = value;
              });
            },
            enabled: _notificationsEnabled,
          ),
          const Divider(),
          
          // Display & Regional section
          _buildSectionHeader('Display & Regional'),
          _buildDropdownTile(
            'Language',
            'Select your preferred language',
            Icons.language,
            _selectedLanguage,
            _languages,
            (value) {
              if (value != null) {
                setState(() {
                  _selectedLanguage = value;
                });
              }
            },
          ),
          _buildSwitchTile(
            'Use Metric System',
            'Switch between metric and imperial units',
            Icons.straighten,
            _useMetric,
            (value) {
              setState(() {
                _useMetric = value;
              });
            },
          ),
          const Divider(),
          
          // Data & Sync section
          _buildSectionHeader('Data & Sync'),
          _buildSwitchTile(
            'Auto-check for Updates',
            'Automatically check for app updates',
            Icons.system_update,
            _autoCheckUpdates,
            (value) {
              setState(() {
                _autoCheckUpdates = value;
              });
            },
          ),
          _buildSwitchTile(
            'Background Data Sync',
            'Sync data in the background',
            Icons.sync,
            _dataSync,
            (value) {
              setState(() {
                _dataSync = value;
              });
            },
          ),
          const Divider(),
          
          // Data management
          _buildSectionHeader('Data Management'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Clear Cache'),
            subtitle: const Text('Free up storage space'),
            onTap: () {
              _showConfirmDialog(
                'Clear Cache',
                'Are you sure you want to clear the cache? This will not delete any of your data.',
                () {
                  // Would clear cache here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache cleared'),
                    ),
                  );
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.blue),
            title: const Text('Export Data'),
            subtitle: const Text('Export your data to a CSV file'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data export started'),
                ),
              );
            },
          ),
          const Divider(),
          
          // Account section
          _buildSectionHeader('Account'),
          Consumer<AuthService>(
            builder: (context, authService, _) {
              // This would get the actual current user from your auth service
              const currentUser = "johndoe@comp490.com";
              
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Current User'),
                    subtitle: Text(currentUser),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Edit Profile'),
                    onTap: () {
                      // Would navigate to profile edit screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile editing would open here'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text('Change Password'),
                    onTap: () {
                      // Would navigate to change password screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password change would open here'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout'),
                    onTap: () {
                      _showConfirmDialog(
                        'Logout',
                        'Are you sure you want to logout?',
                        () {
                          // Would log out here
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Logging out...'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const Divider(),
          
          // About section
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0 (Build 1234)'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () {
              // Would open terms of service
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              // Would open privacy policy
            },
          ),
          const SizedBox(height: 32),
          
          Center(
            child: TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showConfirmDialog(
                  'Delete Account',
                  'Are you sure you want to delete your account? This action cannot be undone.',
                  () {
                    // Would delete account here
                  },
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete Account'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  // Helper widget to build switch tiles
  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    bool enabled = true,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon),
      value: enabled ? value : false,
      onChanged: enabled ? onChanged : null,
    );
  }

  // Helper widget to build dropdown tiles
  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Icon(icon),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        underline: Container(),
      ),
    );
  }

  // Helper method to show a confirmation dialog
  void _showConfirmDialog(String title, String message, Function() onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to show help dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'App Appearance',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Change how the app looks including theme settings.'),
              SizedBox(height: 8),
              Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Control how and when you receive notifications.'),
              SizedBox(height: 8),
              Text(
                'Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Manage your account settings, profile, and logout.'),
            ],
          ),
        ),
      ),
    );
  }
}
