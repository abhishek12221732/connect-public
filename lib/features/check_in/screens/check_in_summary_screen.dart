import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:feelings/features/check_in/models/check_in_model.dart';
import 'package:feelings/providers/check_in_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/features/journal/screens/journal_screen.dart';
import 'package:feelings/features/home/screens/bottom_nav_bar.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../widgets/check_in_loading.dart';

class CheckInSummaryScreen extends StatefulWidget {
  final String userId;
  final String checkInId;

  const CheckInSummaryScreen({
    super.key,
    required this.userId,
    required this.checkInId,
  });

  @override
  State<CheckInSummaryScreen> createState() => _CheckInSummaryScreenState();
}

class _CheckInSummaryScreenState extends State<CheckInSummaryScreen> with SingleTickerProviderStateMixin {
  final Set<String> _selectedInsights = {};
  bool _setReminder = false;
  DateTime? _reminderTime;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final ScrollController _scrollController = ScrollController();
  
  List<CheckInModel>? _cachedRecentHistory;
  bool _hasCachedHistory = false;
  List<String>? _cachedInsights;
  List<String>? _cachedPartnerInsights;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _reminderTime = DateTime.now().add(const Duration(days: 7));
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<CheckInProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userData?['userId'] ?? '';
      
      // NOTE: This uses the old method signature. If you have updated your provider,
      // you will need to pass the coupleId here as well.
      await provider.loadCheckIn(widget.userId, widget.checkInId);
      
      if (userId.isNotEmpty) {
        try {
          // NOTE: This uses the old method signature. If you have updated your repository,
          // you will need to pass the coupleId here as well.
          _cachedRecentHistory = await provider.checkInRepository.getRecentCompletedCheckIns(userId, limit: 5);
          _hasCachedHistory = true;
          
          if (provider.currentCheckIn != null) {
            final partnerData = userProvider.partnerData;
            final partnerFullName = partnerData?['name'] ?? '';
            final partnerFirstName = partnerFullName.split(' ').first;
            
            _cachedInsights = provider.generateInsights(
              provider.currentCheckIn!,
              recentHistory: _cachedRecentHistory!,
            );
            
            _cachedPartnerInsights = provider.generateInsights(
              provider.currentCheckIn!,
              recentHistory: _cachedRecentHistory!,
              forPartner: true,
              userName: partnerFirstName,
              partnerName: partnerFirstName,
            );
          }
          
          if (mounted) setState(() {});
        } catch (e) {
          print('Error preloading history: $e');
        }
      }
      
      final partnerId = userProvider.getPartnerId();
      if (provider.currentCheckIn?.isCompleted == true && partnerId != null) {
        // This is a custom method in your UserProvider
        // await userProvider.sendPushNotification(
        //   partnerId,
        //   'Your partner just completed a relationship check-in!'
        // );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()),
      );
      
      if (time != null) {
        setState(() {
          _reminderTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          _setReminder = true;
        });
      }
    }
  }

  Future<void> _shareSelectedInsights(CheckInModel checkIn) async {
    if (_selectedInsights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one insight to share.')),
      );
      return;
    }

    final checkInProvider = Provider.of<CheckInProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final partnerId = userProvider.getPartnerId();
    final userFullName = userProvider.userData?['name'] ?? 'You';
    final userFirstName = userFullName.split(' ').first;

    if (partnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner not found.')),
      );
      return;
    }

    List<CheckInModel> recentHistory = _cachedRecentHistory ?? await checkInProvider.checkInRepository.getRecentCompletedCheckIns(userProvider.userData?['userId'] ?? '', limit: 5);
    final allPartnerInsights = checkInProvider.generateInsights(
      checkIn, recentHistory: recentHistory, forPartner: true, userName: userFirstName,
    );
    final allUserInsights = checkInProvider.generateInsights(checkIn, recentHistory: recentHistory);
    final selectedPartnerInsights = _selectedInsights.map((insight) {
      final idx = allUserInsights.indexOf(insight);
      return (idx != -1 && idx < allPartnerInsights.length) ? allPartnerInsights[idx] : insight;
    }).toList();

    try {
      await checkInProvider.shareSelectedInsights(
        userId:widget.userId,
        partnerId:partnerId,
        coupleId:checkIn.coupleId,
        insights:selectedPartnerInsights,
        checkInId:checkIn.id,
      );
      
      setState(() { _selectedInsights.clear(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Insights shared successfully!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing insights: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _shareFullCheckIn() async {
    final partnerId = Provider.of<UserProvider>(context, listen: false).getPartnerId();
    if (partnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Partner not found."),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    try {
      await Provider.of<CheckInProvider>(context, listen: false)
          .shareFullCheckInWithPartner(widget.userId, partnerId, widget.checkInId);
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Full check-in shared with your partner!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing check-in: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showInsightsModal(BuildContext context, List<String> insights) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            Set<String> localSelected = Set<String>.from(_selectedInsights);
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Select Insights', style: theme.textTheme.headlineSmall),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                if (localSelected.length == insights.length) {
                                  localSelected.clear();
                                } else {
                                  localSelected = Set<String>.from(insights);
                                }
                              });
                            },
                            child: Text(localSelected.length == insights.length ? 'Deselect All' : 'Select All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${localSelected.length} selected',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: insights.length,
                          separatorBuilder: (context, idx) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final insight = insights[index];
                            final isSelected = localSelected.contains(insight);
                            IconData icon = Icons.lightbulb_outline;
                            if (insight.toLowerCase().contains('connection')) {
                              icon = Icons.favorite;
                            } else if (insight.toLowerCase().contains('stress')) icon = Icons.trending_down;
                            else if (insight.toLowerCase().contains('gratitude')) icon = Icons.volunteer_activism;
                            else if (insight.toLowerCase().contains('growth')) icon = Icons.trending_up;
                            else if (insight.toLowerCase().contains('communication')) icon = Icons.chat_bubble_outline;
                            else if (insight.toLowerCase().contains('satisfaction')) icon = Icons.emoji_emotions;
                            
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    localSelected.remove(insight);
                                  } else {
                                    localSelected.add(insight);
                                  }
                                });
                              },
                              child: _QuoteCard(
                                text: insight,
                                selected: isSelected,
                                icon: icon,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          // FIX: Explicitly set the icon's color to the theme's 'onPrimary' color.
                          icon: Icon(Icons.send_rounded, size: 22, color: colorScheme.onPrimary),
                          label: const Text('Share Selected Insights'),
                          onPressed: () {
                            setState(() {
                              _selectedInsights
                                ..clear()
                                ..addAll(localSelected);
                            });
                            Navigator.pop(context); // Close modal
                            final provider = Provider.of<CheckInProvider>(this.context, listen: false);
                            if (provider.currentCheckIn != null) {
                              _shareSelectedInsights(provider.currentCheckIn!);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryContent(CheckInModel checkIn, List<CheckInModel> recentHistory, List<String> insights, List<String> partnerInsights) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userName = userProvider.userData?['name']?.split(' ').first ?? 'You';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: Card(
            color: colorScheme.surface,
            margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              child: Column(
                children: [
                  Icon(Icons.emoji_events, color: colorScheme.primary, size: 48),
                  const SizedBox(height: 10),
                  Text(
                    'Well Done, $userName!',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reflecting regularly helps strengthen your relationship. Take a moment to review your insights and share them with your partner!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_today, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Weekly Check-In Reminder', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            _setReminder && _reminderTime != null
                                ? 'Next: ${DateFormat('MMM d, y - h:mm a').format(_reminderTime!)}'
                                : 'Set a reminder for next time',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _setReminder,
                      onChanged: (val) {
                        setState(() {
                          _setReminder = val;
                          if (val && _reminderTime == null) {
                            _reminderTime = DateTime.now().add(const Duration(days: 7));
                          }
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),
                if (_setReminder) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Change Reminder Time'),
                      onPressed: () => _selectReminderTime(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Insights', style: theme.textTheme.titleMedium),
              OutlinedButton.icon(
                // FIX: Explicitly set the icon color.
                icon: Icon(Icons.visibility_outlined, size: 20, color: colorScheme.primary),
                label: const Text('View & Select'),
                onPressed: () => _showInsightsModal(context, insights),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  // FIX: Explicitly set the icon color.
                  icon: Icon(Icons.share_rounded, size: 22, color: colorScheme.primary),
                  label: const Text('Share Full Check-In'),
                  onPressed: _shareFullCheckIn,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.book_rounded, color: colorScheme.primary, size: 22),
                  label: const Text('Reflect in Shared Journal'),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const BottomNavBar(initialTabIndex: 1),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Check-In Summary'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_selectedInsights.isNotEmpty) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Unsaved Selections'),
                  content: const Text('You have selected insights to share. Are you sure you want to leave without sharing?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Consumer<CheckInProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && !_hasCachedHistory && provider.currentCheckIn == null) {
            return const CheckInLoading();
          }
          
          if (provider.error != null && !_hasCachedHistory) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadCheckIn(widget.userId, widget.checkInId),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final checkIn = provider.currentCheckIn;
          if (checkIn == null) {
            return const CheckInLoading();
          }
          
          final recentHistory = _cachedRecentHistory ?? [];
          final insights = _cachedInsights ?? [];
          final partnerInsights = _cachedPartnerInsights ?? [];
          
          return SafeArea(
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: 1.0,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  minHeight: 4,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: _buildSummaryContent(checkIn, recentHistory, insights, partnerInsights),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: SafeArea(
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () async {
                if (_setReminder && _reminderTime != null) {
                  final checkIn = Provider.of<CheckInProvider>(context, listen: false).currentCheckIn;
                  if (checkIn != null && checkIn.coupleId.isNotEmpty) {
                    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
                    final existing = calendarProvider.events.any((event) =>
                      event.startDate.year == _reminderTime!.year &&
                      event.startDate.month == _reminderTime!.month &&
                      event.startDate.day == _reminderTime!.day &&
                      event.title == 'Relationship Check-In' &&
                      event.isPersonal == true &&
                      event.personalUserId == checkIn.userId);
                    if (!existing) {
                      await calendarProvider.addEvent(
                        checkIn.coupleId,
                        {
                          'title': 'Relationship Check-In',
                          'description': 'Reflect together and keep your relationship strong.',
                          'startDate': Timestamp.fromDate(_reminderTime!),
                          'endDate': Timestamp.fromDate(_reminderTime!.add(const Duration(hours: 1))),
                          'reminderTime': Timestamp.fromDate(_reminderTime!.subtract(const Duration(minutes: 10))),
                          'createdBy': checkIn.userId,
                          'category': 'check_in',
                          'isPersonal': true,
                          'personalUserId': checkIn.userId,
                        },
                      );
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reminder set for ${DateFormat('MMM d, y - h:mm a').format(_reminderTime!)}'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                            content: Text('You already have a check-in reminder set for that day.'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  }
                }
                if(mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const BottomNavBar(initialTabIndex: 4),
                    ),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: const Text('Done'),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final String text;
  final bool selected;
  final IconData icon;
  const _QuoteCard({required this.text, this.selected = false, this.icon = Icons.format_quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIX: The icon color now changes based on the 'selected' state
          // to match the text color, ensuring it's always visible.
          Icon(
            icon,
            color: selected ? colorScheme.onPrimary : colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic, 
                color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant
              ),
            ),
          ),
        ],
      ),
    );
  }
}