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

  final List<String> moods = const [
    'Happy', 'Excited', 'Loved', 'Grateful', 'Peaceful', 'Content',
    'Sad', 'Stressed', 'Lonely', 'Angry', 'Anxious', 'Confused'
  ];

  final Map<String, double> moodHues = const {
    'Happy': 45.0,      // Yellow/Amber Hue
    'Excited': 15.0,    // Orange Hue
    'Loved': 340.0,     // Pink Hue
    'Grateful': 120.0,  // Green Hue
    'Peaceful': 207.0,  // Light Blue Hue
    'Content': 175.0,   // Teal Hue
    'Sad': 210.0,       // Blue Grey Hue
    'Stressed': 5.0,    // Red Hue
    'Lonely': 0.0,      // Grey (Hue doesn't matter much, will be desaturated)
    'Angry': 0.0,       // Dark Red Hue
    'Anxious': 260.0,   // Purple Hue
    'Confused': 230.0,  // Indigo Hue
  };
  
  final Map<String, String> moodEmojis = const {
    'Happy': '😄', 'Excited': '😆', 'Loved': '🥰', 'Grateful': '🙏',
    'Peaceful': '😌', 'Content': '😊', 'Sad': '😢', 'Stressed': '😰',
    'Lonely': '😔', 'Angry': '😡', 'Anxious': '😨', 'Confused': '😕',
  };
  final Map<String, IconData> moodIcons = {
    'Happy': Icons.sentiment_satisfied, 'Excited': Icons.sentiment_very_satisfied,
    'Loved': Icons.favorite, 'Grateful': Icons.emoji_emotions,
    'Peaceful': Icons.sentiment_satisfied_alt, 'Content': Icons.sentiment_satisfied_alt,
    'Sad': Icons.sentiment_dissatisfied, 'Stressed': Icons.sentiment_very_dissatisfied,
    'Lonely': Icons.sentiment_neutral, 'Angry': Icons.sentiment_very_dissatisfied,
    'Anxious': Icons.sentiment_dissatisfied, 'Confused': Icons.sentiment_neutral,
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
    // ✨ --- END NEW ANIMATION --- ✨
  }

  @override
  void dispose() {
    _animationController.dispose();
    _giftAnimationController.dispose(); // ✨ --- DISPOSE --- ✨
    super.dispose();
  }

  Color _getAdaptiveMoodColor(String mood, BuildContext context) {
    if (!moodHues.containsKey(mood)) return Colors.grey;

    final theme = Theme.of(context);
    final HSLColor themeStyle = HSLColor.fromColor(theme.colorScheme.primary);
    final double moodHue = moodHues[mood]!;

    if (mood == 'Lonely') {
      return HSLColor.fromAHSL(1.0, 0, 0.1, themeStyle.lightness * 0.8).toColor();
    }
    if (mood == 'Angry') {
      return HSLColor.fromAHSL(1.0, 0, themeStyle.saturation * 0.9, themeStyle.lightness * 0.7).toColor();
    }

    return HSLColor.fromAHSL(
      1.0,
      moodHue,
      themeStyle.saturation.clamp(0.4, 1.0),
      themeStyle.lightness.clamp(0.4, 0.8),
    ).toColor();
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
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.3),
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
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.mood, color: colorScheme.onPrimary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('How are you feeling?', style: theme.textTheme.titleLarge),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.close, size: 20, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                Consumer<UserProvider>(
                  builder: (context, userProvider, child) => Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 16.0,
                          crossAxisSpacing: 16.0,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: moods.length,
                        itemBuilder: (context, index) {
                          final mood = moods[index];
                          final isSelected = userProvider.userData?['mood'] == mood;
                          
                          final moodColor = _getAdaptiveMoodColor(mood, context);

                          return GestureDetector(
                            onTap: () async {
                              await userProvider.updateUserMood(mood);
                              Navigator.pop(context);
                            },
                            child: FadeInUp(
                              duration: Duration(milliseconds: 300 + (index * 30)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? moodColor.withOpacity(0.2) : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? moodColor : theme.dividerColor,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: moodColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: _buildEmojiWidget(moodEmojis[mood]!),
                                      ),
                                      const SizedBox(height: 4),
                                      Flexible(
                                        child: Text(
                                          mood,
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? moodColor : colorScheme.onSurfaceVariant,
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
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

        final partnerMoodColor = _getAdaptiveMoodColor(partnerMood, context);
        final moodColor = _getAdaptiveMoodColor(currentMood, context);
        
        final areMoodsSynced = isCoupleActive && currentMood != 'None' && currentMood == partnerMood;

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
      // ✨ --- NEW PARAMETERS --- ✨
      required SecretNoteProvider? secretNoteProvider,
      required AnimationController? giftAnimationController,
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

  _FluidWaveArcPainter({required this.animationValue, required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(70, 100)
      ..quadraticBezierTo(size.width / 2, 45, size.width - 70, 100);

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
    final ui.PathMetric metric = path.computeMetrics().first;

    const double waveFrequency = 4.0;
    const double waveAmplitude = 6.0; 
    final double animationPhase = animationValue * 2 * pi;

    for (double dist = 0.0; dist < metric.length; dist += 2) {
      final ui.Tangent? tangent = metric.getTangentForOffset(dist);
      if (tangent == null) continue;

      final double sineValue = sin((dist / metric.length) * waveFrequency * 2 * pi - animationPhase);
      
      final Offset normal = Offset(-tangent.vector.dy, tangent.vector.dx);
      final Offset point = tangent.position + (normal * sineValue * waveAmplitude);

      if (dist == 0.0) {
        wavePath.moveTo(point.dx, point.dy);
      } else {
        wavePath.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(wavePath, paint);
  }

  @override
  bool shouldRepaint(covariant _FluidWaveArcPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _FluidWaveCirclePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final double radius;

  _FluidWaveCirclePainter({
    required this.animationValue,
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path()..addOval(rect);

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
    final ui.PathMetric metric = path.computeMetrics().first;
    const double waveFrequency = 10.0;
    const double waveAmplitude = 4.0;
    final double animationPhase = animationValue * 2 * pi;

    for (double dist = 0.0; dist < metric.length; dist += 2) {
      final ui.Tangent? tangent = metric.getTangentForOffset(dist);
      if (tangent == null) continue;

      final double sineValue = sin((dist / metric.length) * waveFrequency * 2 * pi - animationPhase);
      final Offset normal = Offset(-tangent.vector.dy, tangent.vector.dx);
      final Offset point = tangent.position + (normal * sineValue * waveAmplitude);

      if (dist == 0.0) {
        wavePath.moveTo(point.dx, point.dy);
      } else {
        wavePath.lineTo(point.dx, point.dy);
      }
    }
    wavePath.close();

    canvas.drawPath(wavePath, paint);
  }

  @override
  bool shouldRepaint(covariant _FluidWaveCirclePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color || oldDelegate.radius != radius;
  }
}