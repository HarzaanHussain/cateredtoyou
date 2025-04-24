import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  bool _autoCheckUpdates = true;
  
  
  // Password change related state
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  

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
          
          // App Updates section
          _buildSectionHeader('App Updates'),
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
                          final goRouter = GoRouter.of(context); // Capture GoRouter instance
                          try {
                            await authService.signOut();
                            // Check if widget is still mounted before navigating
                            if (mounted) {
                              // Navigate to login screen using captured GoRouter
                              goRouter.go('/login');
                            }
                          } catch (e) {
                            if (!mounted) return;
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error logging out: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
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
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Terms of Service'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'By using Catered To You, you agree to these terms. The application is provided as-is without warranties. Users are responsible for maintaining the confidentiality of their account and password. Catered To You reserves the right to modify or terminate services for any reason, without notice.',
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
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Privacy Policy'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'We collect information to provide better services to users. This includes account information, usage data, and device information. We use this data to improve our services, develop new features, and enhance security. We do not sell your personal information to third parties.',
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
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Show password change dialog
  void _showChangePasswordDialog(BuildContext context, AuthService authService) {
    // Create stateful flag variables that will be used in the dialog
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) => AlertDialog(
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
                          obscureCurrent ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureCurrent = !obscureCurrent;
                          });
                        },
                      ),
                    ),
                    obscureText: obscureCurrent,
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
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureNew = !obscureNew;
                          });
                        },
                      ),
                    ),
                    obscureText: obscureNew,
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
                          obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                      ),
                    ),
                    obscureText: obscureConfirm,
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

  // Helper method to show a confirmation dialog
  void _showConfirmDialog(String title, String message, Function() onConfirm) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Control how and when you receive notifications about events, tasks, and updates.'),
              SizedBox(height: 8),
              Text(
                'App Updates',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Configure automatic checking for application updates.'),
              SizedBox(height: 8),
              Text(
                'Data Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Clear cache to free up device storage. This doesn\'t delete your important data.'),
              SizedBox(height: 8),
              Text(
                'Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('View your account information, change password, and logout from the application.'),
              SizedBox(height: 8),
              Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('View information about the app, development team, terms of service, and privacy policy.'),
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