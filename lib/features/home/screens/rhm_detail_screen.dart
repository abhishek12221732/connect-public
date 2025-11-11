import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'package:feelings/providers/rhm_detail_provider.dart';
import 'package:feelings/features/rhm/models/rhm_action.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class RhmDetailPage extends StatelessWidget {
  final int rhmScore;
  
  const RhmDetailPage({
    super.key,
    required this.rhmScore,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.getUserId();
    final partnerId = userProvider.partnerData?['userId'];
    final coupleId = userProvider.coupleId;

    if (userId == null || partnerId == null || coupleId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please connect with your partner first'),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (context) {
        final provider = RhmDetailProvider(
          rhmRepository: context.read<RhmRepository>(),
        );
        // Initialize with actual IDs after creation
        provider.initialize(coupleId, userId, partnerId);
        return provider;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relationship Health'),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          // --- BACKGROUND COLOR REMOVED ---
          // This will now use your theme's default AppBarTheme
        ),
        // --- BACKGROUND COLOR REMOVED ---
        // This will now use your theme's default scaffoldBackgroundColor,
        // matching your homescreen.
        body: Consumer<RhmDetailProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.recentActions.isEmpty) {
              return const Center(
                child: PulsingDotsIndicator(),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildScoreCard(context, rhmScore),
                const SizedBox(height: 24),
                _buildContributionCard(context, provider),
                const SizedBox(height: 24),
                _buildHowToImproveCard(context),
                const SizedBox(height: 24),
                _buildRecentActivityCard(context, provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context, int score) {
    final theme = Theme.of(context);

    // This logic is now identical to rhm_meter_with_actions.dart
    ({String status, Color color}) getStatus(int s) {
      if (s >= 85) {
        return (status: 'Thriving', color: Colors.green);
      } else if (s >= 65) {
        return (status: 'Connected', color: Colors.blue);
      } else if (s >= 40) {
        return (status: 'Steady', color: Colors.yellow[700] ?? Colors.yellow);
      } else if (s >= 20) {
        return (status: 'Needs Nurturing', color: Colors.orange);
      } else {
        return (status: 'Needs Care', color: Colors.red);
      }
    }

    final statusInfo = getStatus(score);
    final Color scoreColor = statusInfo.color;

    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // The Card's default color is theme.colorScheme.surface,
      // which will now contrast with the default scaffold background.
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 8,
                    backgroundColor: scoreColor.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      '$score%',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Weekly Score',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${statusInfo.status}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This score is based on your combined activity in the last 7 days.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionCard(BuildContext context, RhmDetailProvider provider) {
    final theme = Theme.of(context);
    final int totalPoints = provider.totalActivityPoints;
    final double userPercentRatio = totalPoints == 0 ? 0.5 : (provider.userScore / totalPoints.toDouble());
    final double partnerPercentRatio = totalPoints == 0 ? 0.5 : (provider.partnerScore / totalPoints.toDouble());

    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contributions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total activity points this week: ${provider.totalActivityPoints}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildContributionLegend(
                  context,
                  'You',
                  userPercentRatio * 100.0,
                  Colors.blue,
                ),
                _buildContributionLegend(
                  context,
                  'Partner',
                  partnerPercentRatio * 100.0,
                  Colors.pink,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    flex: (userPercentRatio * 100).toInt(),
                    child: Container(
                      height: 12,
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    flex: (partnerPercentRatio * 100).toInt(),
                    child: Container(
                      height: 12,
                      color: Colors.pink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionLegend(BuildContext context, String label, double percentage, Color color) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // Choose image based on label
    final ImageProvider avatar = label == 'You'
        ? userProvider.getProfileImageSync()
        : userProvider.getPartnerProfileImageSync();

    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundImage: avatar,
          backgroundColor: color.withOpacity(0.08),
        ),
        const SizedBox(width: 8),
        Text(
          '${percentage.round()}%',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHowToImproveCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to Improve',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildHowToItem(context, Icons.favorite, 'Complete a Date Night', '+5 points'),
            _buildHowToItem(context, Icons.check_circle, 'Do a Weekly Check-In', '+10 points'),
            _buildHowToItem(context, Icons.format_list_bulleted, 'Finish a Bucket List Item', '+5 points'),
            _buildHowToItem(context, Icons.chat, 'Start a Conversation', '+1 point'),
            _buildHowToItem(context, Icons.question_answer, 'Answer the Daily Question', '+1 point'),
            _buildHowToItem(context, Icons.book, 'Write in Shared Journal', '+2 points'),
            _buildHowToItem(context, Icons.note, 'Send a Secret Note', '+3 points'),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToItem(BuildContext context, IconData icon, String title, String points) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          Text(
            points,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context, RhmDetailProvider provider) {
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.getUserId();

    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity (Last 7 Days)',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (provider.recentActions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Text(
                    'No activity logged in the last 7 days.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.recentActions.length,
                itemBuilder: (context, index) {
                  final action = provider.recentActions[index];
                  final bool isUser = action.userId == userId;
                  final Color actionColor = isUser ? Colors.blue : Colors.pink;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: isUser
                              ? userProvider.getProfileImageSync()
                              : userProvider.getPartnerProfileImageSync(),
                          backgroundColor: actionColor.withOpacity(0.08),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, h:mm a').format(action.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${action.points}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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