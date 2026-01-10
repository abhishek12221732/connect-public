// lib/features/mood/widgets/mood_box.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:feelings/providers/couple_provider.dart';
import '../../../providers/user_provider.dart';
import 'dart:math';
import 'dart:ui' as ui; // Needed for PathMetrics
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

// ✨ --- NEW IMPORTS --- ✨
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/secret_note/widgets/secret_note_view_dialog.dart';
import 'package:feelings/theme/mood_theme.dart';
import 'package:feelings/features/mood/utils/mood_categories.dart';
import 'package:feelings/services/review_service.dart';
// ✨ --- END NEW IMPORTS --- ✨

class MoodBox extends StatefulWidget {
  const MoodBox({super.key});

  @override
  State<MoodBox> createState() => _MoodBoxState();
}

class _MoodBoxState extends State<MoodBox> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  
  // ✨ --- NEW ANIMATION CONTROLLER --- ✨
  late final AnimationController _giftAnimationController;
  late final AnimationController _moodChangeController; // ✨ Triggered on mood update
  String? _lastKnownMood; // To detect changes

  // Primary moods - shown by default (most commonly used)
  final List<String> primaryMoods = const [
    'Happy', 'Loved', 'Tired', 'Stressed', 'Sad', 
    'Excited', 'Grateful', 'Anxious', 'Chill'
  ];

  // Extended moods - shown when "More" is tapped
  final List<String> extendedMoods = const [
    'Peaceful', 'Content', 'Bored', 'Lonely', 'Angry', 
    'Confused', 'Hopeful', 'Motivated', 'Silly', 
    'Romantic', 'Focused', 'Sick', 'Sleepy', 'Nostalgic', 'Jealous'
  ];

  // Combined list for lookups
  List<String> get allMoods => [...primaryMoods, ...extendedMoods];

  // ✨ --- NEW: Category Based Color Logic --- ✨
  // No more hardcoded hues here. We use the Theme extension.
  
  final Map<String, String> moodEmojis = const {
    'Happy': '😄', 'Excited': '😆', 'Loved': '🥰', 'Grateful': '🙏',
    'Peaceful': '😌', 'Content': '😊', 'Sad': '😢', 'Stressed': '😰',
    'Lonely': '😔', 'Angry': '😡', 'Anxious': '😨', 'Confused': '😕',
    'Tired': '😴', 'Chill': '😎', 'Bored': '😑', 'Hopeful': '🤞',
    'Motivated': '💪', 'Silly': '🤪', 'Romantic': '😘', 'Focused': '🧐',
    'Sick': '🤒', 'Sleepy': '🥱', 'Nostalgic': '🥲', 'Jealous': '😒',
  };

  final Map<String, IconData> moodIcons = {
    'Happy': Icons.sentiment_satisfied, 'Excited': Icons.sentiment_very_satisfied,
    'Loved': Icons.favorite, 'Grateful': Icons.emoji_emotions,
    'Peaceful': Icons.sentiment_satisfied_alt, 'Content': Icons.sentiment_satisfied_alt,
    'Sad': Icons.sentiment_dissatisfied, 'Stressed': Icons.sentiment_very_dissatisfied,
    'Lonely': Icons.sentiment_neutral, 'Angry': Icons.sentiment_very_dissatisfied,
    'Anxious': Icons.sentiment_dissatisfied, 'Confused': Icons.sentiment_neutral,
    'Tired': Icons.bedtime, 'Chill': Icons.weekend, 'Bored': Icons.sentiment_neutral,
    'Hopeful': Icons.star_outline, 'Motivated': Icons.fitness_center,
    'Silly': Icons.mood, 'Romantic': Icons.favorite_border,
    'Focused': Icons.center_focus_strong, 'Sick': Icons.sick,
    'Sleepy': Icons.nightlight_round, 'Nostalgic': Icons.history,
    'Jealous': Icons.remove_red_eye,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    // ✨ --- NEW ANIMATION --- ✨
    _giftAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    
    _moodChangeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Elastic pop duration
    );
    // ✨ --- END NEW ANIMATION --- ✨
  }

  @override
  void dispose() {
    _animationController.dispose();
    _giftAnimationController.dispose(); 
    _moodChangeController.dispose(); // ✨ --- DISPOSE --- ✨
    super.dispose();
  }

  Color _getAdaptiveMoodColor(String mood, BuildContext context) {
    if (!moodEmojis.containsKey(mood)) return Colors.grey;

    // 1. Get the current MoodTheme extension
    final moodTheme = Theme.of(context).extension<MoodTheme>();
    if (moodTheme == null) return Colors.grey; // Fallback

    // 2. Identify Category
    final category = MoodCategories.getCategory(mood);

    // 3. Get Base Color from Category
    Color baseColor;
    switch (category) {
      case MoodCategory.joy: baseColor = moodTheme.joy; break;
      case MoodCategory.playful: baseColor = moodTheme.playful; break;
      case MoodCategory.love: baseColor = moodTheme.love; break;
      case MoodCategory.warmth: baseColor = moodTheme.warmth; break;
      case MoodCategory.peace: baseColor = moodTheme.peace; break;
      case MoodCategory.focus: baseColor = moodTheme.focus; break;
      case MoodCategory.sadness: baseColor = moodTheme.sadness; break;
      case MoodCategory.anger: baseColor = moodTheme.anger; break;
      case MoodCategory.anxiety: baseColor = moodTheme.anxiety; break;
      case MoodCategory.malaise: baseColor = moodTheme.malaise; break;
      case MoodCategory.fatigue: baseColor = moodTheme.fatigue; break;
      case MoodCategory.ennui: baseColor = moodTheme.ennui; break;
    }

    // 4. Apply Micro-Modifications for distinctness
    final modification = MoodCategories.getModification(mood);
    return modification.applyTo(baseColor);
  }

  Widget _buildEmojiWidget(String emoji, {double fontSize = 20}) {
    if (kIsWeb) {
      String? moodName;
      moodEmojis.forEach((key, value) {
        if (value == emoji) moodName = key;
      });
      return SizedBox(
        width: fontSize, height: fontSize,
        child: Center(
          child: Icon(
            moodName != null ? moodIcons[moodName!] ?? Icons.sentiment_neutral : Icons.sentiment_neutral,
            size: fontSize,
            color: moodName != null ? _getAdaptiveMoodColor(moodName!, context) : Colors.grey,
          ),
        ),
      );
    } else {
      return Text(emoji, style: TextStyle(fontSize: fontSize));
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void _selectMood(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.transparent,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              bool showAllMoods = false;
              
              return _MoodSelectorContent(
                theme: theme,
                colorScheme: colorScheme,
                primaryMoods: primaryMoods,
                extendedMoods: extendedMoods,
                moodEmojis: moodEmojis,
                getAdaptiveMoodColor: _getAdaptiveMoodColor,
                buildEmojiWidget: _buildEmojiWidget,
              );
            },
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final userProvider = context.watch<UserProvider>();
    final coupleProvider = context.watch<CoupleProvider>();
    
    // ✨ --- WATCH THE NEW PROVIDER --- ✨
    final secretNoteProvider = context.watch<SecretNoteProvider>();
    
    final userData = userProvider.userData;
    final partnerData = userProvider.partnerData;
    final coupleId = userProvider.coupleId;

    return FutureBuilder<bool>(
      future: coupleId != null ? coupleProvider.isRelationshipInactive(coupleId) : Future.value(false),
      builder: (context, snapshot) {
        final bool isInactive = snapshot.data ?? false;
        final bool isCoupleActive = partnerData != null && !isInactive;

        final currentMood = userData?['mood'] ?? 'None';
        final partnerMood = isCoupleActive ? (partnerData['mood'] ?? 'None') : 'None';

        // ✨ --- TRIGGER ANIMATION IF MOOD CHANGED --- ✨
        if (_lastKnownMood != null && _lastKnownMood != currentMood) {
           _moodChangeController.forward(from: 0.0);
        }
        _lastKnownMood = currentMood;
        // ✨ --------------------------------------- ✨

        final partnerMoodColor = _getAdaptiveMoodColor(partnerMood, context);
        final moodColor = _getAdaptiveMoodColor(currentMood, context);
        
        final areMoodsSynced = isCoupleActive && 
            currentMood != 'None' && 
            partnerMood != 'None' &&
            MoodCategories.getCategory(currentMood) == MoodCategories.getCategory(partnerMood);

        final double? userLat = userData?['latitude'];
        final double? userLon = userData?['longitude'];
        final double? partnerLat = isCoupleActive ? partnerData['latitude'] : null;
        final double? partnerLon = isCoupleActive ? partnerData['longitude'] : null;

        int distance = 0;
        if (userLat != null && userLon != null && partnerLat != null && partnerLon != null) {
          distance = calculateDistance(userLat, userLon, partnerLat, partnerLon).round();
        }
        
        final startColor = moodColor.withOpacity(0.3);
        final endColor = isCoupleActive ? partnerMoodColor.withOpacity(0.3) : colorScheme.surfaceContainerHighest;

        Widget profileAvatar = GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.surface.withOpacity(0.5),
            backgroundImage: userProvider.isLoading ? null : userProvider.getProfileImageSync(),
            child: userProvider.isLoading ? PulsingDotsIndicator(
            size: 80,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
            ],
          ) : null,
          ),
        );

        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            gradient: LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 5, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 17.0, bottom: 13.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          userData?['name'] != null ? 'Welcome, ${userData!['name']}!' : 'Welcome!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      profileAvatar,
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                SizedBox(
                  height: 185,
                  child: Stack(
                    children: [
                      
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ArcPainter(arcColor: colorScheme.primary.withOpacity(0.4)),
                        ),
                      ),
                      if (areMoodsSynced)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _FluidWaveArcPainter(
                                    animationValue: _animationController.value,
                                    arcColor: moodColor,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      _buildProfileAvatar(
                        context, 
                        userProvider, 
                        isCoupleActive ? partnerData : null,
                        partnerMood, 
                        partnerMoodColor, 
                        leftAligned: true, 
                        showWave: areMoodsSynced, 
                        animationController: _animationController,
                        
                        // ✨ --- PASS THE PROVIDER DATA --- ✨
                        secretNoteProvider: secretNoteProvider,
                        giftAnimationController: _giftAnimationController,
                        moodChangeController: null, // No animation for partner (yet)
                        
                      ),
                      _buildProfileAvatar(
                        context, 
                        userProvider, 
                        userData, 
                        currentMood, 
                        moodColor, 
                        leftAligned: false, 
                        showWave: areMoodsSynced, 
                        animationController: _animationController,
                        
                        // ✨ --- NOT NEEDED FOR "YOU" --- ✨
                        secretNoteProvider: null,
                        giftAnimationController: null,
                        moodChangeController: _moodChangeController, // ✨ Pass controller
                      ),
                      Positioned(
                        left: 0, right: 0, top: 65,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: theme.shadowColor.withOpacity(0.1), blurRadius: 4)],
                            ),
                            child: Text(
                              isCoupleActive ? "$distance km" : "No Partner",
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✨ --- WIDGET SIGNATURE UPDATED --- ✨
  Widget _buildProfileAvatar(
    BuildContext context, 
    UserProvider userProvider, 
    Map<String, dynamic>? userData, 
    String mood, 
    Color color, 
    {
      required bool leftAligned, 
      required bool showWave, 
      required AnimationController animationController,
      required SecretNoteProvider? secretNoteProvider,
      required AnimationController? giftAnimationController,
      // ✨ --- NEW PARAMETER --- ✨
      required AnimationController? moodChangeController,
    }) {
    // ✨ --- END OF SIGNATURE UPDATE --- ✨
      
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final bool shouldShowData = userData != null;
  
    final double shiftAmount = leftAligned ? 5 : -5;
    final isPartner = leftAligned;
  
    final profileImage = shouldShowData ? (isPartner ? userProvider.getPartnerProfileImageSync() : userProvider.getProfileImageSync()) : null;
    final userName = userData?['name'] ?? (isPartner ? 'Partner' : 'You');
    final initial = userName.isNotEmpty ? userName.trim()[0].toUpperCase() : '?';
    final emoji = shouldShowData ? (moodEmojis[mood] ?? '❔') : '👤';
    final moodText = shouldShowData ? (moodEmojis.containsKey(mood) ? mood : 'No Mood') : 'No Partner';

    // ✨ --- NEW LOGIC: CHECK FOR NOTE --- ✨
    final bool showSecretNote = isPartner &&
        secretNoteProvider != null &&
        secretNoteProvider.activeNoteLocation == SecretNoteLocation.moodBox &&
        secretNoteProvider.activeSecretNote != null;
    // ✨ --- END NEW LOGIC --- ✨
  
    // ✨ --- WRAP IN ANIMATION --- ✨
    Widget avatarWidget = GestureDetector(
      onTap: leftAligned ? null : () => _selectMood(context),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: shouldShowData ? color : theme.dividerColor, width: 3),
          boxShadow: [BoxShadow(color: theme.shadowColor.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: CircleAvatar(
          radius: 40,
          backgroundColor: shouldShowData ? colorScheme.surface : colorScheme.surfaceContainerHighest,
          backgroundImage: profileImage,
          child: !shouldShowData
              ? Icon(Icons.person_add_alt_1_rounded, size: 30, color: colorScheme.onSurfaceVariant)
              : (profileImage == null ? Text(initial, style: theme.textTheme.headlineSmall) : null),
        ),
      ),
    );

    if (moodChangeController != null) {
      avatarWidget = ScaleTransition(
        scale: TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.25)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 30, // Fast expand
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.25, end: 1.0)
                .chain(CurveTween(curve: Curves.elasticOut)),
            weight: 70, // Boing back to normal
          ),
        ]).animate(moodChangeController),
        child: avatarWidget,
      );
    }
    // ✨ --- END ANIMATION WRAPPER --- ✨
  
    return Positioned(
      left: leftAligned ? 20 : null,
      right: leftAligned ? null : 20,
      top: 0,
      child: SizedBox(
        width: 120, 
        height: 150, 
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              top: 0,
              left: leftAligned ? 0 : null,
              right: leftAligned ? null : 0,
              child: Transform.translate(
                offset: Offset(-shiftAmount * 1.5, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: theme.shadowColor.withOpacity(0.1), blurRadius: 3)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEmojiWidget(emoji, fontSize: 14),
                      const SizedBox(width: 4),
                      Text(moodText, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            
            Positioned(
              top: 32,
              left: leftAligned ? 25 : null,
              right: leftAligned ? null : 25,
              child: Transform.translate(offset: Offset(shiftAmount, 0), child: CircleAvatar(backgroundColor: colorScheme.surface.withOpacity(0.6), radius: 5)),
            ),
            Positioned(
              top: 45,
              left: leftAligned ? 30 : null,
              right: leftAligned ? null : 30,
              child: Transform.translate(offset: Offset(shiftAmount * 2, 0), child: CircleAvatar(backgroundColor: colorScheme.surface.withOpacity(0.6), radius: 2.5)),
            ),
            
            if (showWave && shouldShowData)
              Transform.translate(
                offset: const Offset(0, 20),
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: animationController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _FluidWaveCirclePainter(
                            animationValue: animationController.value,
                            color: color,
                            radius: 55.0,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            avatarWidget, 
            
            // ✨ --- NEW WIDGET: THE GIFT ICON --- ✨
            if (showSecretNote)
              Positioned(
                bottom: 10,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    // Show the dialog and mark the note as read
                    final note = secretNoteProvider.activeSecretNote!;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => SecretNoteViewDialog(note: note),
                    );
                    secretNoteProvider.markNoteAsRead(note.id);
                  },
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.2).animate(giftAnimationController!),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            // ✨ --- END NEW WIDGET --- ✨
          ],
        ),
      ),
    );
  }
}


class _ArcPainter extends CustomPainter {
  final Color arcColor;
  _ArcPainter({required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    final leftCenter = const Offset(70, 100);
    final rightCenter = Offset(size.width - 70, 100);
    final controlPoint = Offset(size.width / 2, 45);

    final path = Path()
      ..moveTo(leftCenter.dx, leftCenter.dy)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, rightCenter.dx, rightCenter.dy);

    final paint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      const dashWidth = 6.0;
      const dashSpace = 6.0;
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => oldDelegate.arcColor != arcColor;
}

class _FluidWaveArcPainter extends CustomPainter {
  final double animationValue;
  final Color arcColor;

  // Cache static variables to avoid reallocation
  static Path? _cachedBasePath;
  static ui.PathMetric? _cachedMetric;
  static Size? _cachedSize;

  _FluidWaveArcPainter({required this.animationValue, required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. REUSE THE PATH: Only rebuild the base path if the size changes
    if (_cachedSize != size || _cachedBasePath == null) {
      _cachedSize = size;
      _cachedBasePath = Path()
        ..moveTo(70, 100)
        ..quadraticBezierTo(size.width / 2, 45, size.width - 70, 100);
      _cachedMetric = _cachedBasePath!.computeMetrics().first;
    }

    final ui.PathMetric? metric = _cachedMetric;
    if (metric == null) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, 0),
        [
          arcColor.withOpacity(0),
          arcColor,
          arcColor.withOpacity(0)
        ],
        [0.0, 0.5, 1.0],
      )
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10.0);

    final wavePath = Path();

    const double waveFrequency = 4.0;
    const double waveAmplitude = 6.0; 
    final double animationPhase = animationValue * 2 * pi;
    final double length = metric.length;

    // 2. OPTIMIZATION: Increase step from 2 to 6 (3x faster)
    // The blur hides the lack of precision.
    for (double dist = 0.0; dist < length; dist += 6) {
      final ui.Tangent? tangent = metric.getTangentForOffset(dist);
      if (tangent == null) continue;

      final double sineValue = sin((dist / length) * waveFrequency * 2 * pi - animationPhase);
      
      // Manual vector math is slightly faster than creating Offset objects repeatedly, 
      // but the biggest win is the loop step.
      final double dx = tangent.vector.dy * -1; // Normal vector x
      final double dy = tangent.vector.dx;      // Normal vector y
      
      final double x = tangent.position.dx + (dx * sineValue * waveAmplitude);
      final double y = tangent.position.dy + (dy * sineValue * waveAmplitude);

      if (dist == 0.0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }
    canvas.drawPath(wavePath, paint);
  }

  @override
  bool shouldRepaint(covariant _FluidWaveArcPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.arcColor != arcColor;
  }
}




class _FluidWaveCirclePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double radius;

  // Cache
  static Path? _cachedBasePath;
  static ui.PathMetric? _cachedMetric;
  static Size? _cachedSize;

  _FluidWaveCirclePainter({
    required this.animationValue,
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. REUSE THE PATH
    if (_cachedSize != size || _cachedBasePath == null) {
      _cachedSize = size;
      final center = Offset(size.width / 2, size.height / 2);
      final rect = Rect.fromCircle(center: center, radius: radius);
      _cachedBasePath = Path()..addOval(rect);
      _cachedMetric = _cachedBasePath!.computeMetrics().first;
    }

    final ui.PathMetric? metric = _cachedMetric;
    if (metric == null) return;

    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [color, color.withOpacity(0.5), color.withOpacity(0.0)],
        [0.0, 0.7, 1.0],
      )
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10.0);

    final wavePath = Path();
    
    const double waveFrequency = 10.0;
    const double waveAmplitude = 4.0;
    final double animationPhase = animationValue * 2 * pi;
    final double length = metric.length;

    // 2. OPTIMIZATION: Increase step from 2 to 6
    for (double dist = 0.0; dist < length; dist += 6) {
      final ui.Tangent? tangent = metric.getTangentForOffset(dist);
      if (tangent == null) continue;

      final double sineValue = sin((dist / length) * waveFrequency * 2 * pi - animationPhase);
      
      final double dx = tangent.vector.dy * -1;
      final double dy = tangent.vector.dx;

      final double x = tangent.position.dx + (dx * sineValue * waveAmplitude);
      final double y = tangent.position.dy + (dy * sineValue * waveAmplitude);

      if (dist == 0.0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }
    wavePath.close();

    canvas.drawPath(wavePath, paint);
  }

  @override
  bool shouldRepaint(covariant _FluidWaveCirclePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.color != color || 
           oldDelegate.radius != radius;
  }
}



// Expandable Mood Selector Dialog Content
class _MoodSelectorContent extends StatefulWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final List<String> primaryMoods;
  final List<String> extendedMoods;
  final Map<String, String> moodEmojis;
  final Color Function(String mood, BuildContext context) getAdaptiveMoodColor;
  final Widget Function(String emoji, {double fontSize}) buildEmojiWidget;

  const _MoodSelectorContent({
    required this.theme,
    required this.colorScheme,
    required this.primaryMoods,
    required this.extendedMoods,
    required this.moodEmojis,
    required this.getAdaptiveMoodColor,
    required this.buildEmojiWidget,
  });

  @override
  State<_MoodSelectorContent> createState() => _MoodSelectorContentState();
}

class _MoodSelectorContentState extends State<_MoodSelectorContent> {
  bool _showAllMoods = false;

  List<String> get _visibleMoods => _showAllMoods 
      ? [...widget.primaryMoods, ...widget.extendedMoods]
      : widget.primaryMoods;

  @override
  Widget build(BuildContext context) {
    // 3 rows collapsed (~340px), 6 rows expanded (~580px)
    final double gridHeight = _showAllMoods ? 580 : 340;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      constraints: BoxConstraints(maxHeight: gridHeight + 120, maxWidth: 400), // +120 for header and button
      decoration: BoxDecoration(
        color: widget.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: widget.theme.shadowColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.colorScheme.primary.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.mood, color: widget.colorScheme.onPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('How are you feeling?', style: widget.theme.textTheme.titleLarge),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: widget.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close, size: 20, color: widget.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          // Mood Grid - scrollable
          Consumer<UserProvider>(
            builder: (context, userProvider, child) => Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12.0,
                    crossAxisSpacing: 12.0,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _visibleMoods.length,
                  itemBuilder: (context, index) {
                    final mood = _visibleMoods[index];
                    final isSelected = userProvider.userData?['mood'] == mood;
                    final moodColor = widget.getAdaptiveMoodColor(mood, context);

                      return GestureDetector(
                        onTap: () {
                          // Fire and forget - Optimistic update handles the state
                          userProvider.updateUserMood(mood);
                          
                          // ✨ Smart Review Trigger ✨
                          // Only ask if mood is positive (Joy, Love, Playful, etc.)
                          final category = MoodCategories.getCategory(mood);
                          if ([
                            MoodCategory.joy, 
                            MoodCategory.playful, 
                            MoodCategory.love, 
                            MoodCategory.warmth, 
                            MoodCategory.peace, 
                            MoodCategory.focus
                          ].contains(category)) {
                             ReviewService().requestSmartReview(context);
                          }
                          
                          Navigator.pop(context);
                        },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? moodColor.withOpacity(0.2) 
                              : widget.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? moodColor : widget.theme.dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: moodColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: widget.buildEmojiWidget(
                                  widget.moodEmojis[mood]!, 
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Flexible(
                                child: Text(
                                  mood,
                                  style: widget.theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? moodColor : widget.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Expand/collapse button - FIXED at bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: GestureDetector(
              onTap: () => setState(() => _showAllMoods = !_showAllMoods),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAllMoods ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: widget.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showAllMoods ? 'Less' : 'More',
                      style: widget.theme.textTheme.labelMedium?.copyWith(
                        color: widget.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}