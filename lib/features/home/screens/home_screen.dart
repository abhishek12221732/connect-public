import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

// Providers & Models
import 'package:feelings/features/check_in/models/check_in_model.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/providers/check_in_provider.dart';

// ViewModels & Widgets
import '../view_models/home_screen_view_model.dart';
import '../../mood/widgets/mood_box.dart';
import '../widgets/tips_widget.dart';
import '../widgets/stats_grid.dart';
import '../widgets/events_box.dart';
import '../../connectCouple/screens/connect_couple_screen.dart';
import '../widgets/daily_action_hub.dart';
import '../widgets/partner_shared_insight_card.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/rhm_meter_widget.dart';
import '../screens/rhm_detail_screen.dart';
import 'package:feelings/features/home/widgets/rhm_meter_with_actions.dart';
import 'package:feelings/features/home/widgets/interactive_rhm_meter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeScreenViewModel>();
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    final checkInProvider = context.read<CheckInProvider>();

    Widget buildContent() {
      // ... (Shimmer and Error states are unchanged) ...
      if (viewModel.status == HomeScreenStatus.loading &&
          !viewModel.isInitialized) {
        return const _HomeScreenShimmer();
      }

      if (viewModel.status == HomeScreenStatus.error) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text("Error: ${viewModel.errorMessage}",
                textAlign: TextAlign.center),
          ),
        );
      }

      final coupleId = userProvider.coupleId;
      final bool isPartnerConnected = userProvider.partnerData != null;

      return SingleChildScrollView(
        child: Column(
          children: [
            const MoodBox(),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [


                  if (isPartnerConnected && coupleId != null)
                    FutureBuilder<bool>(
                      future: coupleProvider.isRelationshipInactive(coupleId),
                      builder: (context, snapshot) {
                        // ... (rest of the builder is unchanged) ...
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !viewModel.isInitialized) {
                          return const _HomeScreenShimmer();
                        }

                        final bool isInactive = snapshot.data ?? false;

                        if (isInactive) {
                          return const _InactiveRelationshipState();
                        } else {
                          return Column(
                            children: [
                              if (viewModel.partnerInsight != null &&
                                  (viewModel.partnerInsight?.sharedInsights
                                          .isNotEmpty ??
                                      false))
                                PartnerSharedInsightCard(
                                  partnerName:
                                      userProvider.partnerData?['name'] ??
                                          'Partner',
                                  insightPreview: viewModel
                                      .partnerInsight!.sharedInsights.first,
                                  isFullCheckIn: viewModel
                                      .partnerInsight!.isFullCheckInShared,
                                  onTap: () async {
                                    // ... (onTap logic unchanged)
                                    final insightToShow =
                                        viewModel.partnerInsight;
                                    if (insightToShow == null) return;

                                    await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => _InsightModalContent(
                                        partnerInsight: insightToShow,
                                      ),
                                    );
                                    checkInProvider.markInsightAsRead(
                                      userProvider.getUserId()!,
                                      insightToShow.id,
                                    );
                                  },
                                ),

                              if (viewModel.dateSuggestions
                                  .where((s) => s['status'] == 'pending')
                                  .isNotEmpty)
                                ...viewModel.dateSuggestions
                                    .where((s) => s['status'] == 'pending')
                                    .map((suggestion) => SuggestionCard(
                                          suggestion: suggestion,
                                          userId: userProvider.getUserId()!,
                                          coupleId: coupleId,
                                        ))
                                    .toList(),
                              const SizedBox(height: 12),
                              RhmMeterWithActions(
                                score: viewModel.rhmScore,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RhmDetailPage(
                                        rhmScore: viewModel.rhmScore,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // const SizedBox(height: 12),
                              // DailyActionHub(question: viewModel.dailyQuestion),
                              const SizedBox(height: 8),
                              EventsBox(events: viewModel.upcomingEvents),
                              const SizedBox(height: 14),
                              const TipsWidget(),
                              const SizedBox(height: 12),
                              StatsGrid(
                                journalCount: viewModel.stats.journalCount,
                                bucketListCount:
                                    viewModel.stats.bucketListCount,
                                questionCount: viewModel.stats.questionCount,
                                doneDatesCount: viewModel.stats.doneDatesCount,
                              ),
                            ],
                          );
                        }
                      },
                    )
                  else
                    const _DisconnectedState(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(child: buildContent());
  }
}

// ... (Rest of the file is unchanged: _HomeScreenShimmer, _ShimmerBox, _InsightModalContent, _DisconnectedState, _InactiveRelationshipState) ...
class _HomeScreenShimmer extends StatelessWidget {
  const _HomeScreenShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // Shimmer for MoodBox
            Container(
              height: 120,
              width: double.infinity,
              color: Colors.white,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // ✨ [ADD] Shimmer for RHM Meter
                  _ShimmerBox(height: 110),
                  const SizedBox(height: 14),
                  // ✨ [END ADD]

                  // Shimmer for DailyActionHub
                  _ShimmerBox(height: 150),
                  const SizedBox(height: 14),
                  // Shimmer for EventsBox
                  _ShimmerBox(height: 180),
                  const SizedBox(height: 14),
                  // Shimmer for TipsWidget
                  _ShimmerBox(height: 100),
                  const SizedBox(height: 14),
                  // Shimmer for StatsGrid
                  Row(
                    children: [
                      Expanded(child: _ShimmerBox(height: 100)),
                      const SizedBox(width: 14),
                      Expanded(child: _ShimmerBox(height: 100)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _ShimmerBox(height: 100)),
                      const SizedBox(width: 14),
                      Expanded(child: _ShimmerBox(height: 100)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double width;

  const _ShimmerBox({required this.height, this.width = double.infinity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _InsightModalContent extends StatelessWidget {
  final CheckInModel partnerInsight;
  const _InsightModalContent({required this.partnerInsight});
  // ... (This widget remains unchanged)
  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final theme = Theme.of(context);
    final partner = userProvider.partnerData!;
    final questionsList =
        partnerInsight.questions.map((q) => q.toMap()).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                        radius: 24,
                        backgroundImage:
                            userProvider.getPartnerProfileImageSync()),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "${partner['name']}'s Check-in",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Shared Insights',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 12),
                ...partnerInsight.sharedInsights.map((insight) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(insight,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.5)),
                      ),
                    )),
                if (partnerInsight.isFullCheckInShared &&
                    questionsList.isNotEmpty) ...[
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(height: 1)),
                  Text('Full Check-in Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary)),
                  const SizedBox(height: 16),
                  ...questionsList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final q = entry.value;
                    final answer = partnerInsight.answers[q['id']] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${idx + 1}. ${q['question']}",
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                answer.toString().isNotEmpty
                                    ? answer.toString()
                                    : 'No answer',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onTertiaryContainer)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DisconnectedState extends StatelessWidget {
  const _DisconnectedState();
  // ... (This widget remains unchanged)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: theme.colorScheme.primary.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.people_outline,
                  size: 24, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text('Connect with Your Partner',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'To access all features and share your journey together',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ConnectCoupleScreen())),
              child: const Text("Connect Now"),
            ),
          ],
        ),
      ),
    );
  }
}

class _InactiveRelationshipState extends StatelessWidget {
  const _InactiveRelationshipState();
  // ... (This widget remains unchanged)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.link_off, size: 24, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Your Partner has Disconnected',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Your shared data is saved, but some features are disabled. Go to your profile to manage your connection.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
