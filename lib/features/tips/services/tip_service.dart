import 'dart:math';
import '../models/tip_model.dart';
import '../data/static_tips.dart';
import '../../check_in/models/check_in_model.dart';

class TipService {
  final Random _random = Random();

  /// Generate dynamic tips based on user mood and check-in data
  List<TipModel> generateDynamicTips({
    required String userMood,
    required String? partnerMood,
    required List<CheckInModel> recentCheckIns,
    required Map<String, dynamic>? userData,
    required Map<String, dynamic>? partnerData,
  }) {
    print('🔍 [TipService] Starting tip generation...');
    print('🔍 [TipService] User Mood: $userMood');
    print('🔍 [TipService] Partner Mood: $partnerMood');
    print('🔍 [TipService] Recent Check-ins: ${recentCheckIns.length}');
    print('🔍 [TipService] User Data Available: ${userData != null}');
    print('🔍 [TipService] Partner Data Available: ${partnerData != null}');
    
    final List<TipModel> tips = [];

    // 1. Mood-based tips
    print('🔍 [TipService] Generating mood-based tips...');
    final moodTips = _generateMoodBasedTips(userMood, partnerMood);
    tips.addAll(moodTips);
    print('🔍 [TipService] Generated ${moodTips.length} mood-based tips');

    // 2. Check-in based tips
    if (recentCheckIns.isNotEmpty) {
      print('🔍 [TipService] Generating check-in based tips...');
      final checkInTips = _generateCheckInBasedTips(recentCheckIns);
      tips.addAll(checkInTips);
      print('🔍 [TipService] Generated ${checkInTips.length} check-in based tips');
    } else {
      print('🔍 [TipService] No recent check-ins available for tip generation');
    }

    // 3. Static tips from data file
    print('🔍 [TipService] Generating static tips...');
    final staticTips = _generateStaticTips();
    tips.addAll(staticTips);
    print('🔍 [TipService] Generated ${staticTips.length} static tips');

    // 4. Partner-specific tips
    if (partnerData != null) {
      print('🔍 [TipService] Generating partner-specific tips...');
      final partnerTips = _generatePartnerSpecificTips(userData, partnerData);
      tips.addAll(partnerTips);
      print('🔍 [TipService] Generated ${partnerTips.length} partner-specific tips');
    } else {
      print('🔍 [TipService] No partner data available for partner-specific tips');
    }

    print('🔍 [TipService] Total tips before sorting: ${tips.length}');

    // Sort by priority and return top tips
    tips.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    final finalTips = tips.take(10).toList();
    print('🔍 [TipService] Final tips after sorting and limiting: ${finalTips.length}');
    
    // Print details of each final tip
    for (int i = 0; i < finalTips.length; i++) {
      final tip = finalTips[i];
      print('🔍 [TipService] Tip ${i + 1}: ${tip.title} (${tip.category}, ${tip.priority})');
      print('🔍 [TipService] Content: ${tip.content}');
      if (tip.contextData != null) {
        print('🔍 [TipService] Context: ${tip.contextData}');
      }
      print('🔍 [TipService] Dynamic: ${tip.isDynamic}');
      print('---');
    }
    
    return finalTips;
  }

  List<TipModel> _generateStaticTips() {
    final List<TipModel> tips = [];
    
    print('🔍 [TipService] Converting ${staticTips.length} static tips to TipModel objects...');
    
    // Convert static tips to TipModel objects
    for (final tipData in staticTips) {
      tips.add(TipModel(
        id: 'static_${tips.length}_${DateTime.now().millisecondsSinceEpoch}',
        title: _getTitleForCategory(tipData['category']!),
        content: tipData['content']!,
        category: tipData['category']!,
        priority: _getPriorityForCategory(tipData['category']!),
        isDynamic: false,
      ));
    }
    
    // Shuffle and return a subset to avoid overwhelming the user
    tips.shuffle(_random);
    final selectedTips = tips.take(5 + _random.nextInt(5)).toList();
    print('🔍 [TipService] Selected ${selectedTips.length} random static tips');
    
    return selectedTips;
  }

  String _getTitleForCategory(String category) {
    switch (category) {
      case 'communication':
        return 'Communication Tip';
      case 'appreciation':
        return 'Appreciation Tip';
      case 'qualityTime':
        return 'Quality Time Tip';
      case 'intimacy':
        return 'Intimacy Tip';
      case 'stress':
        return 'Stress Management';
      case 'trust':
        return 'Trust Building';
      case 'fun':
        return 'Fun Together';
      case 'growth':
        return 'Growth & Goals';
      case 'conflict':
        return 'Conflict Resolution';
      case 'longDistance':
        return 'Long Distance Love';
      case 'parenting':
        return 'Parenting Together';
      case 'money':
        return 'Financial Harmony';
      case 'health':
        return 'Health & Wellness';
      case 'holidays':
        return 'Holiday Connection';
      case 'milestones':
        return 'Celebrating Milestones';
      case 'everyday':
        return 'Daily Connection';
      case 'crisis':
        return 'Supporting Each Other';
      case 'reconnection':
        return 'Reconnecting';
      case 'newRelationship':
        return 'New Relationship';
      case 'establishedRelationship':
        return 'Established Love';
      default:
        return 'Relationship Tip';
    }
  }

  TipPriority _getPriorityForCategory(String category) {
    switch (category) {
      case 'crisis':
      case 'conflict':
        return TipPriority.high;
      case 'communication':
      case 'trust':
      case 'stress':
        return TipPriority.medium;
      case 'fun':
      case 'appreciation':
      case 'qualityTime':
      case 'intimacy':
      case 'growth':
      case 'longDistance':
      case 'parenting':
      case 'money':
      case 'health':
      case 'holidays':
      case 'milestones':
      case 'everyday':
      case 'reconnection':
      case 'newRelationship':
      case 'establishedRelationship':
        return TipPriority.low;
      default:
        return TipPriority.medium;
    }
  }

  List<TipModel> _generateMoodBasedTips(String userMood, String? partnerMood) {
    final List<TipModel> tips = [];
    
    print('🔍 [TipService] Analyzing user mood: $userMood');

    // User mood tips
    switch (userMood.toLowerCase()) {
      case 'sad':
        print('🔍 [TipService] User is sad - generating sad mood tip');
        tips.add(TipModel(
          id: 'mood_sad_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Feeling Down?',
          content: 'When you\'re feeling sad, try sharing your feelings with your partner. Sometimes just talking about it can help lighten the load.',
          category: 'mood',
          priority: TipPriority.high,
          contextData: {'userMood': userMood},
        ));
        break;
      case 'angry':
        print('🔍 [TipService] User is angry - generating angry mood tip');
        tips.add(TipModel(
          id: 'mood_angry_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Feeling Angry?',
          content: 'Take a moment to breathe before discussing what\'s bothering you. It\'s okay to feel angry, but how we express it matters.',
          category: 'mood',
          priority: TipPriority.high,
          contextData: {'userMood': userMood},
        ));
        break;
      case 'stressed':
        print('🔍 [TipService] User is stressed - generating stress mood tip');
        tips.add(TipModel(
          id: 'mood_stressed_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Feeling Stressed?',
          content: 'Stress can affect relationships. Try doing something relaxing together, like a short walk or meditation.',
          category: 'mood',
          priority: TipPriority.medium,
          contextData: {'userMood': userMood},
        ));
        break;
      case 'happy':
        print('🔍 [TipService] User is happy - generating happy mood tip');
        tips.add(TipModel(
          id: 'mood_happy_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Feeling Happy!',
          content: 'Great mood! Share your joy with your partner. Happiness is contagious and can strengthen your bond.',
          category: 'mood',
          priority: TipPriority.low,
          contextData: {'userMood': userMood},
        ));
        break;
      case 'excited':
        print('🔍 [TipService] User is excited - generating excited mood tip');
        tips.add(TipModel(
          id: 'mood_excited_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Feeling Excited!',
          content: 'Your excitement is wonderful! Channel this energy into planning something fun together.',
          category: 'mood',
          priority: TipPriority.low,
          contextData: {'userMood': userMood},
        ));
        break;
      default:
        print('🔍 [TipService] User mood "$userMood" not recognized - no mood-specific tip generated');
    }

    // Partner mood tips
    if (partnerMood != null) {
      print('🔍 [TipService] Analyzing partner mood: $partnerMood');
      
      switch (partnerMood.toLowerCase()) {
        case 'sad':
          print('🔍 [TipService] Partner is sad - generating partner sad tip');
          tips.add(TipModel(
            id: 'partner_sad_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Partner Feeling Down',
            content: 'Your partner seems sad. A simple "How are you feeling?" and a listening ear can make a big difference.',
            category: 'mood',
            priority: TipPriority.high,
            contextData: {'partnerMood': partnerMood},
          ));
          break;
        case 'angry':
          print('🔍 [TipService] Partner is angry - generating partner angry tip');
          tips.add(TipModel(
            id: 'partner_angry_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Partner Seems Upset',
            content: 'Your partner appears angry. Give them space if needed, but let them know you\'re there when they\'re ready to talk.',
            category: 'mood',
            priority: TipPriority.high,
            contextData: {'partnerMood': partnerMood},
          ));
          break;
        default:
          print('🔍 [TipService] Partner mood "$partnerMood" not recognized for special handling');
      }

      // Mood compatibility tips
      if (userMood.toLowerCase() == 'happy' && partnerMood.toLowerCase() == 'sad') {
        print('🔍 [TipService] Mood mismatch detected (happy user, sad partner) - generating compatibility tip');
        tips.add(TipModel(
          id: 'mood_compatibility_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Different Moods',
          content: 'You\'re in different moods today. That\'s normal! Try to be understanding and supportive of each other.',
          category: 'mood',
          priority: TipPriority.medium,
          contextData: {'userMood': userMood, 'partnerMood': partnerMood},
        ));
      }
    } else {
      print('🔍 [TipService] No partner mood data available');
    }

    return tips;
  }

  List<TipModel> _generateCheckInBasedTips(List<CheckInModel> recentCheckIns) {
    final List<TipModel> tips = [];
    
    print('🔍 [TipService] Analyzing ${recentCheckIns.length} recent check-ins');
    
    if (recentCheckIns.isEmpty) {
      print('🔍 [TipService] No recent check-ins - generating no check-in tip');
      tips.add(TipModel(
        id: 'no_checkins_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Time for a Check-in',
        content: 'It\'s been a while since your last relationship check-in. Take a moment to reflect on how things are going.',
        category: 'checkIn',
        priority: TipPriority.medium,
        contextData: {'lastCheckIn': null},
      ));
      return tips;
    }

    final latestCheckIn = recentCheckIns.first;
    final answers = latestCheckIn.answers;
    
    print('🔍 [TipService] Latest check-in answers: $answers');

    // Analyze satisfaction trends
    if (recentCheckIns.length >= 3) {
      print('🔍 [TipService] Analyzing satisfaction trends from last 3 check-ins...');
      
      final satisfactionScores = recentCheckIns
          .take(3)
          .map((c) => c.answers['overall_satisfaction'])
          .where((score) => score != null)
          .map((score) => score is int ? score.toDouble() : score as double)
          .toList();

      print('🔍 [TipService] Satisfaction scores: $satisfactionScores');

      if (satisfactionScores.length >= 3) {
        if (satisfactionScores[0] < 6 && satisfactionScores[1] < 6 && satisfactionScores[2] < 6) {
          print('🔍 [TipService] Low satisfaction trend detected - generating low satisfaction tip');
          tips.add(TipModel(
            id: 'low_satisfaction_trend_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Satisfaction Trend',
            content: 'Your relationship satisfaction has been low recently. Consider having an open conversation about what might be missing.',
            category: 'checkIn',
            priority: TipPriority.high,
            contextData: {'satisfactionScores': satisfactionScores},
          ));
        } else if (satisfactionScores[0] < satisfactionScores[1] && satisfactionScores[1] < satisfactionScores[2]) {
          print('🔍 [TipService] Declining satisfaction trend detected - generating declining satisfaction tip');
          tips.add(TipModel(
            id: 'declining_satisfaction_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Declining Satisfaction',
            content: 'Your satisfaction has been dropping. What changed? Identifying the cause is the first step to improvement.',
            category: 'checkIn',
            priority: TipPriority.high,
            contextData: {'satisfactionScores': satisfactionScores},
          ));
        } else {
          print('🔍 [TipService] No concerning satisfaction trends detected');
        }
      }
    } else {
      print('🔍 [TipService] Not enough check-ins for trend analysis (need 3+, have ${recentCheckIns.length})');
    }

    // Specific metric-based tips
    if (answers['communication_quality'] != null) {
      final commScore = answers['communication_quality'] is int 
          ? answers['communication_quality'].toDouble() 
          : answers['communication_quality'] as double;
      
      print('🔍 [TipService] Communication quality score: $commScore');
      
      if (commScore < 6) {
        print('🔍 [TipService] Low communication score detected - generating communication tip');
        tips.add(TipModel(
          id: 'communication_tip_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Communication Challenge',
          content: 'You rated communication low. Try using "I feel" statements and active listening techniques.',
          category: 'communication',
          priority: TipPriority.high,
          contextData: {'communicationScore': commScore},
        ));
      }
    }

    if (answers['stress_level'] != null) {
      final stressScore = answers['stress_level'] is int 
          ? answers['stress_level'].toDouble() 
          : answers['stress_level'] as double;
      
      print('🔍 [TipService] Stress level score: $stressScore');
      
      if (stressScore > 7) {
        print('🔍 [TipService] High stress level detected - generating stress tip');
        tips.add(TipModel(
          id: 'stress_tip_${DateTime.now().millisecondsSinceEpoch}',
          title: 'High Stress Level',
          content: 'Stress is affecting your relationship. Consider stress-reduction activities you can do together.',
          category: 'stress',
          priority: TipPriority.medium,
          contextData: {'stressScore': stressScore},
        ));
      }
    }

    if (answers['quality_time'] == 'No') {
      print('🔍 [TipService] No quality time reported - generating quality time tip');
      tips.add(TipModel(
        id: 'quality_time_tip_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Missing Quality Time',
        content: 'You haven\'t spent quality time together this week. Plan something special, even if it\'s just 30 minutes.',
        category: 'qualityTime',
        priority: TipPriority.medium,
        contextData: {'qualityTime': false},
      ));
    }

    if (answers['appreciation'] == null || (answers['appreciation'] as String).trim().isEmpty) {
      print('🔍 [TipService] No appreciation expressed - generating appreciation tip');
      tips.add(TipModel(
        id: 'appreciation_tip_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Express Appreciation',
        content: 'Take a moment to tell your partner something you appreciate about them today.',
        category: 'appreciation',
        priority: TipPriority.medium,
        contextData: {'appreciationExpressed': false},
      ));
    }

    return tips;
  }

  List<TipModel> _generatePartnerSpecificTips(
    Map<String, dynamic>? userData, 
    Map<String, dynamic>? partnerData
  ) {
    final List<TipModel> tips = [];

    print('🔍 [TipService] Analyzing partner-specific data...');

    // Distance-based tips
    if (userData != null && partnerData != null) {
      final userLat = userData['latitude'];
      final userLon = userData['longitude'];
      final partnerLat = partnerData['latitude'];
      final partnerLon = partnerData['longitude'];

      print('🔍 [TipService] User location: ($userLat, $userLon)');
      print('🔍 [TipService] Partner location: ($partnerLat, $partnerLon)');

      if (userLat != null && userLon != null && partnerLat != null && partnerLon != null) {
        final distance = _calculateDistance(userLat, userLon, partnerLat, partnerLon);
        print('🔍 [TipService] Distance between partners: ${distance.toStringAsFixed(1)} km');
        
        if (distance > 50) { // More than 50km apart
          print('🔍 [TipService] Long distance relationship detected - generating long distance tip');
          tips.add(TipModel(
            id: 'long_distance_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Long Distance Love',
            content: 'You\'re far apart. Make the most of technology - video calls, voice messages, and shared activities can help maintain connection.',
            category: 'general',
            priority: TipPriority.medium,
            contextData: {'distance': distance},
          ));
        } else {
          print('🔍 [TipService] Partners are close enough (${distance.toStringAsFixed(1)} km) - no long distance tip needed');
        }
      } else {
        print('🔍 [TipService] Location data incomplete - cannot calculate distance');
      }
    } else {
      print('🔍 [TipService] Missing user or partner data for location analysis');
    }

    return tips;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth's radius in kilometers
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
} 
