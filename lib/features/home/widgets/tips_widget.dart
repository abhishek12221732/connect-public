import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../../providers/user_provider.dart';
import '../../tips/widgets/tip_card.dart';

class TipsWidget extends StatefulWidget {
  const TipsWidget({super.key});

  @override
  _TipsWidgetState createState() => _TipsWidgetState();
}

class _TipsWidgetState extends State<TipsWidget> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final partnerData = userProvider.partnerData;
    
    if (partnerData == null) {
      return const SizedBox.shrink();
    }
    
    // ✨ Get the partner's name, love language, and profile image
    final String? partnerName = partnerData['name'];
    final String? partnerLoveLanguage = partnerData['loveLanguage'];
    final ImageProvider partnerProfileImage = userProvider.getPartnerProfileImageSync();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      // ✨ Pass all the new data to the DynamicTipCard
      child: DynamicTipCard(
        title: "Tip of the Day",
        partnerName: partnerName,
        partnerLoveLanguage: partnerLoveLanguage,
        partnerProfileImage: partnerProfileImage,
      ),
    );
  }
}