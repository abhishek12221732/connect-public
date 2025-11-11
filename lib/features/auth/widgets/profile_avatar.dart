// lib/features/profile/widgets/profile_avatar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'section_helpers.dart';

class ProfileAvatar extends StatelessWidget {
  // ❌ The `newImage` property is no longer needed.
  final VoidCallback onPickImage;

  const ProfileAvatar({
    super.key,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = context.watch<UserProvider>();

    // ✨ This logic is now much simpler.
    final ImageProvider displayImage = userProvider.getProfileImageSync();
    final bool showPlaceholderIcon = displayImage is AssetImage;

    return Column(
      children: [
        buildSectionTitle(context, 'Profile Photo', icon: Icons.person),
        buildInfoCard(
          Center(
            child: GestureDetector(
              onTap: onPickImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    key: ValueKey(displayImage), // Key now just depends on the provider
                    radius: 60,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                    backgroundImage: displayImage,
                    child: showPlaceholderIcon
                        ? Icon(Icons.camera_alt, size: 40, color: theme.colorScheme.onSurface.withOpacity(0.5))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt, color: theme.colorScheme.onPrimary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}