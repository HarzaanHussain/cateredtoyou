import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/services/auth_service.dart';

/// App Settings Screen
/// This screen allows users to configure app-wide preferences
/// and settings like language, notifications, and account details.
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _selectedLanguage = 'English';
  bool _autoCheckUpdates = true;
  bool _dataSync = true;
  
  // List of available languages (limited to English and Spanish)
  final List<String> _languages = [
    'English',
    'Spanish',
  ];

  // Password change related state
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureCurrentPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Language section
          _buildSectionHeader('Language'),
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
                // Here you would implement the actual language change
                // For example: LocalizationService.changeLocale(value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Language changed to $value'),
                  ),
                );
              }
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
          const Divider(),
          
          // Account section
          _buildSectionHeader('Account'),
          Consumer<AuthService>(
            builder: (context, authService, _) {
              // Get the current user from the auth service
              final currentUser = authService.currentUser;
              final userEmail = currentUser?.email ?? "Not logged in";
              
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Current User'),
                    subtitle: Text(userEmail),
                  ),
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text('Change Password'),
                    onTap: () {
                      _showChangePasswordDialog(context, authService);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout'),
                    onTap: () {
                      _showConfirmDialog(
                        'Logout',
                        'Are you sure you want to logout?',
                        () async {
                          try {
                            await authService.signOut();
                            // Navigate to login screen after successful logout
                            Navigator.of(context).pushReplacementNamed('/login');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error logging out: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terms of Service would open here'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              // Would open privacy policy
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy Policy would open here'),
                ),
              );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deletion would happen here'),
                      ),
                    );
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

  // Show password change dialog
  void _showChangePasswordDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: _passwordFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureCurrentPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear the fields
              _currentPasswordController.clear();
              _passwordController.clear();
              _confirmPasswordController.clear();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_passwordFormKey.currentState!.validate()) {
                try {
                  // Reauthenticate user with current password first
                  final user = authService.currentUser;
                  if (user != null && user.email != null) {
                    // First sign in with current credentials to verify current password
                    final result = await authService.signIn(
                      user.email!,
                      _currentPasswordController.text,
                    );
                    
                    if (result.success) {
                      // Now change the password
                      await user.updatePassword(_passwordController.text);
                      
                      Navigator.of(context).pop();
                      // Clear the fields
                      _currentPasswordController.clear();
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Current password is incorrect: ${result.error}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error changing password: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update Password'),
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
                'Language',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Change the language of the app.'),
              SizedBox(height: 8),
              Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Control how and when you receive notifications.'),
              SizedBox(height: 8),
              Text(
                'Data & Sync',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Configure data synchronization and update settings.'),
              SizedBox(height: 8),
              Text(
                'Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Manage your account settings, password, and logout.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}