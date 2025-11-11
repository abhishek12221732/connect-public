// lib/features/discover/screens/discover_screen.dart

import 'package:feelings/features/discover/widgets/bucket_list_preview.dart';
import 'package:feelings/features/discover/widgets/date_night_card.dart';
import 'package:flutter/material.dart';
import '../widgets/know_each_other_section.dart';
import '../widgets/relationship_insights_section.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/couple_provider.dart';
import '../widgets/connect_with_partner_card.dart';
import 'package:provider/provider.dart';
import 'package:feelings/features/connectCouple/screens/connect_couple_screen.dart';
// ✨ [REMOVED] The PulsingDotsIndicator is no longer needed in this file.
// import 'package:feelings/widgets/pulsing_dots_indicator.dart';
// ... other imports
import 'package:feelings/features/discover/widgets/send_secret_note_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final partnerData = userProvider.partnerData;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // This logic handles the main content of the screen
              if (partnerData == null)
                _buildDisconnectedState()
              else
                _buildConnectedState(context, userProvider),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for the disconnected state
  Widget _buildDisconnectedState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            ConnectWithPartnerCard(
              title:
                  'Connect with your partner to unlock Discover features!',
              message:
                  'Once connected, you can explore date ideas, bucket lists, and more together.',
              icon: Icons.lock_outline,
              buttonLabel: 'Connect Now',
              onButtonPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConnectCoupleScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: 0.5,
                child: KnowEachOtherSection(),
              ),
            ),
            const SizedBox(height: 30),
            const IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: 0.5,
                child: BucketListPreview(),
              ),
            ),
            const SizedBox(height: 30),
            const IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: 0.5,
                child: DateNightCard(),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Helper widget for the connected state, containing the FutureBuilder
  Widget _buildConnectedState(BuildContext context, UserProvider userProvider) {
  return FutureBuilder<bool>(
    future: userProvider.coupleId != null
        ? Provider.of<CoupleProvider>(context, listen: false)
            .isRelationshipInactive(userProvider.coupleId!)
        : Future.value(false),
    builder: (context, snapshot) {
      // ... (loading state unchanged)

      final bool isInactive = snapshot.data ?? false;

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              if (isInactive)
                const IgnorePointer(
                  // ... (KnowEachOtherSection unchanged)
                )
              else
              const SizedBox(height: 14),
                const KnowEachOtherSection(),

              // ✨ --- ADD THE NEW WIDGET HERE --- ✨
              const SizedBox(height: 20),
              const SendSecretNoteCard(),
              // ✨ --- END OF NEW WIDGET --- ✨

              const SizedBox(height: 20),
              const BucketListPreview(),
              const SizedBox(height: 20),
              const DateNightCard(),
              const SizedBox(height: 20),

              if (isInactive)
                const SizedBox(height: 0)
              else
                const RelationshipInsightsSection(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    },
  );
}
}