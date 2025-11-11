import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/check_in_provider.dart';
import 'package:feelings/providers/tips_provider.dart';
import 'package:feelings/features/check_in/screens/check_in_screen.dart';
import 'package:feelings/features/check_in/screens/check_in_insights_history_screen.dart';
import 'package:feelings/features/tips/widgets/tip_card.dart';

class RelationshipInsightsSection extends StatefulWidget {
  const RelationshipInsightsSection({super.key});

  @override
  State<RelationshipInsightsSection> createState() =>
      _RelationshipInsightsSectionState();
}

class _RelationshipInsightsSectionState
    extends State<RelationshipInsightsSection> {
  String? _lastCheckInText;
  int? _daysAgo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLastCheckIn();
      _initializeTips();
    });
  }

  Future<void> _initializeTips() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final tipsProvider = Provider.of<TipsProvider>(context, listen: false);

    if (userProvider.userData != null) {
      final userId = userProvider.userData!['userId'];
      final coupleId = userProvider.coupleId;

      if (userId != null && coupleId != null) {
        await tipsProvider.initialize(
          userId: userId,
          coupleId: coupleId,
          userData: userProvider.userData!,
          partnerData: userProvider.partnerData,
        );
      }
    }
  }

  Future<void> _loadLastCheckIn() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final checkInProvider =
        Provider.of<CheckInProvider>(context, listen: false);
    if (userProvider.userData != null) {
      final userId = userProvider.userData!['userId'];
      final partnerId = userProvider.partnerData?['userId'];
      final lastCheckIn =
          await checkInProvider.getLastCompletedCheckIn(userId, partnerId: partnerId);
      if (mounted) {
        if (lastCheckIn != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final checkInDate = DateTime(
            lastCheckIn.completedAt!.year,
            lastCheckIn.completedAt!.month,
            lastCheckIn.completedAt!.day,
          );
          final daysAgo = today.difference(checkInDate).inDays;
          setState(() {
            _daysAgo = daysAgo;
            if (daysAgo == 0) {
              _lastCheckInText = 'Last check-in: Today';
            } else if (daysAgo == 1) {
              _lastCheckInText = 'Last check-in: Yesterday';
            } else {
              _lastCheckInText = 'Last check-in: $daysAgo days ago';
            }
          });
        } else {
          setState(() {
            _daysAgo = null;
            _lastCheckInText = 'No check-in yet!';
          });
        }
      }
    }
  }

  Widget _buildBorderedAvatar({
    required ImageProvider? avatar,
    required String initial,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 20,
      backgroundColor: theme.cardColor,
      child: CircleAvatar(
        radius: 18,
        backgroundImage: avatar,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: avatar == null
            ? Text(initial, style: theme.textTheme.titleSmall)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userData;
    final partner = userProvider.partnerData;
    final userAvatar = userProvider.getProfileImageSync();
    final partnerAvatar = userProvider.getPartnerProfileImageSync();
    final userInitial = user?['name'] != null && user!['name'].isNotEmpty
        ? user['name'][0].toUpperCase()
        : 'Y';
    final partnerInitial =
        partner?['name'] != null && partner!['name'].isNotEmpty
            ? partner['name'][0].toUpperCase()
            : 'P';

    // Use fixed semantic colors for check-in recency:
    // - Today: green
    // - Within 1-7 days: yellow
    // - Older than 7 days: red
    Color statusColor;
    if (_daysAgo == null) {
      // No check-in yet: muted
      statusColor = colorScheme.onSurfaceVariant;
    } else if (_daysAgo! <= 3) {
      statusColor = Colors.green; // fixed green for 'Today'
    } else if (_daysAgo! <= 7) {
      statusColor = Colors.yellow; // fixed yellow for recent (1-7 days)
    } else {
      statusColor = Colors.red; // fixed red for older than 3 days
    }
    
    final String? partnerName = partner?['name'];
    final String? partnerLoveLanguage = partner?['loveLanguage'];
    final ImageProvider partnerProfileImage = userProvider.getPartnerProfileImageSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Relationship Insights",
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16), // Reduced padding for a tighter layout
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 65, // Reduced width for the avatar stack
                      height: 40,
                      child: Stack(
                        children: [
                          _buildBorderedAvatar(
                            avatar: partnerAvatar,
                            initial: partnerInitial,
                            context: context,
                          ),
                          Positioned(
                            left: 25,
                            child: _buildBorderedAvatar(
                              avatar: userAvatar,
                              initial: userInitial,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✨ --- MODIFICATION: Removed icon and adjusted style to fit --- ✨
                          Text(
                            "Check-In Status",
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (_daysAgo != null)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (_daysAgo != null) const SizedBox(width: 6),
                              // Use Flexible to prevent overflow
                              Flexible(
                                child: Text(
                                  _lastCheckInText ?? 'Loading...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                                builder: (context) => const CheckInScreen()),
                          )
                          .then((_) => _loadLastCheckIn());
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      backgroundColor: colorScheme.primary, // Ensure contrast
                    ),
                    icon: Icon(Icons.favorite, size: 20, color: colorScheme.onPrimary),
                    label: const Text("Start Check-in"),
                  ),
                ),
                if (user != null && partner != null)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon( // Using TextButton for less emphasis
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CheckInInsightsHistoryScreen(
                              userId: user['userId'],
                              partnerId: partner['userId'],
                              userName: user['name'] ?? 'You',
                              partnerName: partner['name'] ?? 'Partner',
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                      ),
                      icon: const Icon(Icons.insights, size: 20),
                      label: const Text("View All Insights"),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        DynamicTipCard(
          title: "Tip of the Day",
          partnerName: partnerName,
          partnerLoveLanguage: partnerLoveLanguage,
          partnerProfileImage: partnerProfileImage,
        ),
      ],
    );
  }
}