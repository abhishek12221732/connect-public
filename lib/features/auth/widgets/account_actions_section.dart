// lib/features/profile/widgets/account_actions_section.dart

import 'package:flutter/material.dart';
import 'section_helpers.dart';

class AccountActionsSection extends StatelessWidget {
  final VoidCallback onUpdateLocation;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;
  // ✨ [ADD] A new callback for showing the about dialog.
  final VoidCallback onShowAbout;

  const AccountActionsSection({
    super.key,
    required this.onUpdateLocation,
    required this.onChangePassword,
    required this.onDeleteAccount,
    // ✨ [ADD] Require the new callback.
    required this.onShowAbout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle(context, 'Account', icon: Icons.account_circle),
        buildInfoCard(
          Column(
            children: [
              ListTile(
                leading: Icon(Icons.location_on, color: theme.colorScheme.primary),
                title: const Text('Update Location'),
                onTap: onUpdateLocation,
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.lock, color: theme.colorScheme.secondary),
                title: const Text('Change Password'),
                onTap: onChangePassword,
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.info, color: theme.colorScheme.tertiary),
                title: const Text('About App'),
                // ✨ [MODIFY] Use the new callback here.
                onTap: onShowAbout,
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
                title: const Text('Delete Account'),
                onTap: onDeleteAccount,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
}