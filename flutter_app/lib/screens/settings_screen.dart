import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/supabase_auth_service.dart';
import '../services/cloud_sync_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = SupabaseAuthService();
  final _syncService = CloudSyncService();

  bool _isSyncing = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _authService.authStateChanges.listen((state) {
      if (mounted) {
        _loadUserProfile();
      }
    });
  }

  Future<void> _loadUserProfile() async {
    if (_authService.isLoggedIn) {
      final profile = await _authService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } else {
      setState(() {
        _userProfile = null;
      });
    }
  }

  Future<void> _handleManualSync() async {
    setState(() {
      _isSyncing = true;
    });

    final success = await _syncService.syncHealthData();

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      if (success) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Sync Complete'),
            content: const Text('Your health data has been synchronized.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Sync Failed'),
            content: const Text('Unable to sync data. Please check your connection.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? Your local data will remain on this device.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sign Out'),
            onPressed: () async {
              Navigator.pop(context);
              _syncService.stopAutoSync();
              await _authService.signOut();
              setState(() {
                _userProfile = null;
              });
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToLogin() async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const LoginScreen()),
    );

    if (result == true && mounted) {
      _loadUserProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            // Account Section
            CupertinoListSection.insetGrouped(
              header: Text(
                'ACCOUNT',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              children: [
                if (_authService.isLoggedIn) ...[
                  // User Info
                  if (_userProfile != null)
                    CupertinoListTile(
                      title: const Text('Signed In'),
                      subtitle: Text(_userProfile!['email'] ?? 'No email'),
                      trailing: const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: CupertinoColors.activeGreen,
                      ),
                    ),
                  // Sync Status
                  CupertinoListTile(
                    title: const Text('Cloud Sync'),
                    subtitle: Text(
                      _syncService.lastSyncTime != null
                          ? 'Last sync: ${_formatTime(_syncService.lastSyncTime!)}'
                          : 'Never synced',
                    ),
                    trailing: _isSyncing
                        ? const CupertinoActivityIndicator()
                        : CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Icon(CupertinoIcons.refresh),
                            onPressed: _handleManualSync,
                          ),
                  ),
                  // Manual Sync Button
                  CupertinoListTile(
                    title: const Text('Manual Sync'),
                    subtitle: const Text('Sync data to cloud now'),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.cloud_upload),
                      onPressed: _isSyncing ? null : _handleManualSync,
                    ),
                  ),
                  // Sign Out
                  CupertinoListTile(
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                    trailing: const Icon(
                      CupertinoIcons.square_arrow_right,
                      color: CupertinoColors.destructiveRed,
                    ),
                    onTap: _handleSignOut,
                  ),
                ] else ...[
                  // Sign In
                  CupertinoListTile(
                    title: const Text('Sign In / Sign Up'),
                    subtitle: const Text('Sync your health data across devices'),
                    trailing: const Icon(CupertinoIcons.chevron_right),
                    onTap: _navigateToLogin,
                  ),
                ],
              ],
            ),

            // Data Management Section
            CupertinoListSection.insetGrouped(
              header: Text(
                'DATA MANAGEMENT',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              children: [
                CupertinoListTile(
                  title: const Text('Auto Sync'),
                  subtitle: const Text('Sync when on WiFi'),
                  trailing: CupertinoSwitch(
                    value: _authService.isLoggedIn,
                    onChanged: _authService.isLoggedIn
                        ? (value) {
                            if (value) {
                              _syncService.startAutoSync();
                            } else {
                              _syncService.stopAutoSync();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Export Data'),
                  subtitle: const Text('Download your health data'),
                  trailing: const Icon(CupertinoIcons.square_arrow_down),
                  onTap: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Export Data'),
                        content: const Text('This feature will be available soon.'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('OK'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (_authService.isLoggedIn)
                  CupertinoListTile(
                    title: const Text(
                      'Delete Cloud Data',
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                    subtitle: const Text('Remove all data from cloud'),
                    trailing: const Icon(
                      CupertinoIcons.trash,
                      color: CupertinoColors.destructiveRed,
                    ),
                    onTap: () {
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Delete Cloud Data'),
                          content: const Text(
                              'This will permanently delete all your health data from the cloud. Local data will remain on this device.'),
                          actions: [
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: const Text('Delete'),
                              onPressed: () async {
                                Navigator.pop(context);
                                await _syncService.deleteAllCloudData();
                                if (mounted) {
                                  showCupertinoDialog(
                                    context: context,
                                    builder: (context) => CupertinoAlertDialog(
                                      title: const Text('Data Deleted'),
                                      content:
                                          const Text('Your cloud data has been deleted.'),
                                      actions: [
                                        CupertinoDialogAction(
                                          child: const Text('OK'),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                            CupertinoDialogAction(
                              isDefaultAction: true,
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),

            // Privacy Section
            CupertinoListSection.insetGrouped(
              header: Text(
                'PRIVACY',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              children: [
                CupertinoListTile(
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: () {},
                ),
                CupertinoListTile(
                  title: const Text('Terms of Service'),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),

            // App Info Section
            CupertinoListSection.insetGrouped(
              header: Text(
                'ABOUT',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              children: const [
                CupertinoListTile(
                  title: Text('Version'),
                  additionalInfo: Text('1.0.0'),
                ),
                CupertinoListTile(
                  title: Text('Build'),
                  additionalInfo: Text('100'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}