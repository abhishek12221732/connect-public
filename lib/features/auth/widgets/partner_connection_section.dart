// lib/features/profile/widgets/partner_connection_section.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✨ [ADDED] For using the clipboard
import 'package:provider/provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/features/connectCouple/screens/connect_couple_screen.dart';
import 'section_helpers.dart';
// ✨ [ADD] Import for the custom loading indicator.
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class PartnerConnectionSection extends StatelessWidget {
  final VoidCallback onDisconnect;

  const PartnerConnectionSection({
    super.key,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final coupleId = userProvider.coupleId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle(context, 'Partner Connection', icon: Icons.favorite, color: theme.colorScheme.errorContainer),
        buildInfoCard(
          coupleId == null
              ? _buildNotConnectedInfo(context)
              : FutureBuilder<bool>(
                  future: coupleProvider.isRelationshipInactive(coupleId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // ✨ [MODIFIED] Replaced the CircularProgressIndicator.
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: PulsingDotsIndicator(
                            size: 60,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary,
                              theme.colorScheme.primary,
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final bool isInactive = snapshot.data ?? true;
                    return _buildPartnerInfo(context, userProvider, isInactive);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPartnerInfo(BuildContext context, UserProvider userProvider, bool isInactive) {
    final theme = Theme.of(context);
    final partnerName = userProvider.partnerData?['name'] ?? 'Your Partner';
    final partnerImage = userProvider.getPartnerProfileImageSync();
    final String? partnerLoveLanguage = userProvider.partnerData?['loveLanguage'];
    // ✨ [ADDED] Get the current user's code to display if inactive
    final String? userCode = userProvider.userData?['coupleCode'];

    return Opacity(
      opacity: isInactive ? 0.6 : 1.0,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: partnerImage,
                backgroundColor: theme.colorScheme.secondary,
                child: (partnerImage is AssetImage)
                    ? Icon(Icons.person, color: theme.colorScheme.onSecondary)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInactive ? "Relationship Inactive" : "Connected with",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isInactive ? theme.colorScheme.error : theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: isInactive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      partnerName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          isInactive ? Icons.link_off : Icons.favorite,
                          color: isInactive ? theme.colorScheme.onSurface.withOpacity(0.6) : theme.colorScheme.primary.withOpacity(0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isInactive ? "Disconnected" : (partnerLoveLanguage ?? "Love language not set"),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.9),
                              fontStyle: isInactive ? FontStyle.italic : FontStyle.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'disconnect') {
                    onDisconnect();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'disconnect',
                    child: ListTile(
                      leading: Icon(Icons.link_off, color: theme.colorScheme.error),
                      title: Text(isInactive ? 'Remove Data' : 'Disconnect', style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // ✨ [ADDED] If the relationship is inactive, show the user's connection code.
          if (isInactive)
            _buildUserCodeDisplay(context, userCode),
        ],
      ),
    );
  }

  Widget _buildNotConnectedInfo(BuildContext context) {
    final theme = Theme.of(context);
    // ✨ [ADDED] Get the current user's code to display
    final userProvider = context.read<UserProvider>();
    final String? userCode = userProvider.userData?['coupleCode'];

    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.favorite_border,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Not Connected to a Partner',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
        // ✨ [ADDED] The user's connection code is now always visible when not connected.
        _buildUserCodeDisplay(context, userCode),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50)),
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ConnectCoupleScreen())),
          child: const Text("Connect With a Code"),
        ),
      ],
    );
  }
  
  // ✨ **[NEW WIDGET]** A reusable widget to display the user's connection code.
  Widget _buildUserCodeDisplay(BuildContext context, String? userCode) {
    final theme = Theme.of(context);

    if (userCode == null || userCode.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text("Generate your connection code from the 'Connect' screen."),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "YOUR CONNECTION CODE",
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userCode,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Copy Code',
              icon: Icon(Icons.copy_rounded, color: theme.colorScheme.primary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: userCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection code copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}