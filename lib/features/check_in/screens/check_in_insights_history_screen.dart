// lib/features/check_in/screens/check_in_insights_history_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/check_in_loading.dart';

// Helper function to get an icon for a metric. This is fine to keep as it's not theme-related.
IconData _getMetricIcon(String label) {
  switch (label.toLowerCase()) {
    case 'satisfaction':
      return Icons.emoji_emotions;
    case 'connection':
      return Icons.favorite;
    case 'communication':
      return Icons.chat_bubble_outline;
    case 'gratitude':
      return Icons.volunteer_activism;
    case 'stress':
      return Icons.bolt;
    case 'intimacy':
      return Icons.nightlife;
    case 'support':
      return Icons.handshake;
    case 'fun':
      return Icons.celebration;
    case 'goals':
      return Icons.flag;
    default:
      return Icons.insights;
  }
}

class CheckInInsightsHistoryScreen extends StatefulWidget {
  final String userId;
  final String partnerId;
  final String userName;
  final String partnerName;
  const CheckInInsightsHistoryScreen({super.key, required this.userId, required this.partnerId, required this.userName, required this.partnerName});

  @override
  State<CheckInInsightsHistoryScreen> createState() => _CheckInInsightsHistoryScreenState();
}

class _CheckInInsightsHistoryScreenState extends State<CheckInInsightsHistoryScreen> {
  int _selectedDataSource = 0; // 0 = My Data, 1 = Partner Data

  String prettifyKey(String key) {
    return key
        .split('_')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }


Future<List<_UserCheckIn>> _fetchUserCheckIns() async {
  final query = await FirebaseFirestore.instance
      .collection('users')
      .doc(widget.userId)
      .collection('check_ins')
      .where('isCompleted', isEqualTo: true)
      .orderBy('timestamp', descending: true)
      .get();

  final List<_UserCheckIn> checkIns = [];
  for (var doc in query.docs) {
    final data = doc.data();
    
    // Correctly identify and skip check-ins shared by the partner.
    if (data.containsKey('sharedByUserId') && data['sharedByUserId'] != null) {
      continue; 
    }

    if (data['isPartial'] == true) {
      continue;
    }
    
    final timestamp = (data['timestamp'] is Timestamp)
        ? (data['timestamp'] as Timestamp).toDate()
        : (data['timestamp'] is DateTime)
            ? (data['timestamp'] as DateTime)
            : null;
            
    if (timestamp != null) {
      checkIns.add(_UserCheckIn(
        date: timestamp,
        answers: Map<String, dynamic>.from(data['answers'] ?? {}),
        sharedInsights: List<String>.from(data['userInsights'] ?? []),
        isCompleted: data['isCompleted'] ?? false,
      ));
    }
  }
  return checkIns;
}


  Future<List<_PartnerSharedCheckInGroup>> _fetchPartnerSharedInsightsAndFullCheckIns() async {
    // ✨ FIX: This function has been rewritten to correctly query for data shared by the partner.
    final List<_PartnerSharedCheckInGroup> allPartnerData = [];

    // Query for all documents in the current user's collection that were shared by the partner.
    final querySnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId) // We are looking in the current user's collection
        .collection('check_ins')
        .where('sharedByUserId', isEqualTo: widget.partnerId) // For documents shared BY the partner
        .orderBy('timestamp', descending: true)
        .get();

    for (final doc in querySnap.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : (data['completedAt'] is Timestamp)
              ? (data['completedAt'] as Timestamp).toDate()
              : null;
      
      if (timestamp != null) {
        allPartnerData.add(_PartnerSharedCheckInGroup(
          date: timestamp,
          user: widget.partnerName,
          // The 'isFullCheckInShared' field correctly determines if it's a full check-in.
          isFullCheckIn: data['isFullCheckInShared'] ?? false,
          answers: Map<String, dynamic>.from(data['answers'] ?? {}),
          sharedInsights: List<String>.from(data['sharedInsights'] ?? []),
        ));
      }
    }
    
    return allPartnerData;
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Relationship Insights'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<_UserCheckIn>>(
        future: _fetchUserCheckIns(),
        builder: (context, userSnapshot) {
          return FutureBuilder<List<_PartnerSharedCheckInGroup>>(
            future: _fetchPartnerSharedInsightsAndFullCheckIns(),
            builder: (context, partnerSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting || partnerSnapshot.connectionState == ConnectionState.waiting) {
                return const CheckInLoading();
              }
              if (userSnapshot.hasError || partnerSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                      const SizedBox(height: 12),
                      Text('Failed to load insights.', style: theme.textTheme.bodyLarge),
                    ],
                  ),
                );
              }
              final userCheckIns = userSnapshot.data ?? [];
              final partnerInsights = partnerSnapshot.data ?? [];

              final totalCheckIns = userCheckIns.length;
              final streak = _calculateStreak(userCheckIns);
              final avgSatisfaction = _calculateAvg(userCheckIns, 'overall_satisfaction');

              final metrics = [
                _MetricOption('Satisfaction', 'overall_satisfaction', min: 0, max: 10),
                _MetricOption('Connection', 'feeling_connected', min: 0, max: 10),
                _MetricOption('Communication', 'communication_quality', min: 0, max: 10),
                _MetricOption('Stress', 'stress_level', min: 0, max: 10),
                _MetricOption('Intimacy', 'physical_intimacy', min: 0, max: 10),
                _MetricOption('Support', 'emotional_support', min: 0, max: 10),
                _MetricOption('Fun', 'fun_together', min: 0, max: 10),
                _MetricOption('Goals', 'shared_goals', min: 0, max: 10),
              ];

              Widget dataSourceToggle = Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: CupertinoSegmentedControl<int>(
                  children: const <int, Widget>{
                    0: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('My Data', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("Partner's Data", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  },
                  groupValue: _selectedDataSource,
                  onValueChanged: (int value) {
                    setState(() {
                      _selectedDataSource = value;
                    });
                  },
                  selectedColor: colorScheme.primary,
                  borderColor: colorScheme.primary,
                  unselectedColor: colorScheme.surface,
                  pressedColor: colorScheme.primary.withOpacity(0.15),
                ),
              );

              final timeline = _selectedDataSource == 0
                  ? _buildTimeline(userCheckIns, [])
                  : _buildTimeline([], partnerInsights);

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hi ${widget.userName.split(' ').first},', style: theme.textTheme.headlineMedium),
                            const SizedBox(height: 6),
                            Text('Here’s your relationship journey so far:', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _QuickStat(icon: Icons.favorite, label: 'Check-Ins', value: '$totalCheckIns'),
                                _QuickStat(icon: Icons.local_fire_department, label: 'Streak', value: '$streak'),
                                _QuickStat(icon: Icons.emoji_emotions, label: 'Avg. Satisfaction', value: avgSatisfaction.toStringAsFixed(1)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Key Relationship Metrics', style: theme.textTheme.headlineSmall?.copyWith(fontSize: 20)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 170,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: metrics.length,
                                separatorBuilder: (context, i) => const SizedBox(width: 12),
                                itemBuilder: (context, i) {
                                  final m = metrics[i];
                                  return _MetricCard(
                                    metric: m,
                                    userCheckIns: userCheckIns,
                                    selected: false,
                                    onTap: () {},
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      dataSourceToggle,
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Relationship Timeline', style: theme.textTheme.headlineSmall?.copyWith(fontSize: 20)),
                            const SizedBox(height: 10),
                            ...timeline,
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Helper methods for stats and timeline ---
  int _calculateStreak(List<_UserCheckIn> checkIns) {
    if (checkIns.isEmpty) return 0;
    Map<String, bool> weekHasCheckIn = {};
    for (final c in checkIns) {
      if (!c.isCompleted) continue;
      final monday = c.date.subtract(Duration(days: c.date.weekday - 1));
      final weekKey = DateTime(monday.year, monday.month, monday.day).toIso8601String();
      weekHasCheckIn[weekKey] = true;
    }
    if (weekHasCheckIn.isEmpty) return 0;
    final weekKeys = weekHasCheckIn.keys.toList()..sort((a, b) => b.compareTo(a));
    DateTime now = DateTime.now();
    DateTime currentMonday = now.subtract(Duration(days: now.weekday - 1));
    int streak = 0;
    while (true) {
      final weekKey = DateTime(currentMonday.year, currentMonday.month, currentMonday.day).toIso8601String();
      if (weekHasCheckIn[weekKey] == true) {
        streak++;
        currentMonday = currentMonday.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }
    return streak;
  }

  double _calculateAvg(List<_UserCheckIn> checkIns, String key) {
    final values = checkIns.map((c) => c.answers[key]).where((v) => v != null).map((v) => (v as num).toDouble()).toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<Widget> _buildTimeline(List<_UserCheckIn> userCheckIns, List<_PartnerSharedCheckInGroup> partnerInsights) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final List<_TimelineEvent> events = [];
    for (final c in userCheckIns) {
      events.add(_TimelineEvent(date: c.date, isUser: true, userCheckIn: c));
    }
    for (final p in partnerInsights) {
      events.add(_TimelineEvent(date: p.date, isUser: false, partnerInsight: p));
    }
    events.sort((a, b) => b.date.compareTo(a.date));
    
    final Map<String, List<_TimelineEvent>> grouped = {};
    for (final e in events) {
      final month = DateFormat('MMMM yyyy').format(e.date);
      grouped.putIfAbsent(month, () => []).add(e);
    }
    
    final List<Widget> widgets = [];
    grouped.forEach((month, events) {
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(month, style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
      ));
      for (final e in events) {
        if (e.isUser) {
          widgets.add(_UserCheckInFeedCard(checkIn: e.userCheckIn!, userName: widget.userName));
        } else {
          widgets.add(_PartnerInsightFeedCard(group: e.partnerInsight!, partnerName: widget.partnerName));
        }
      }
    });

    if (widgets.isEmpty) {
      widgets.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sentiment_dissatisfied, color: colorScheme.onSurface.withOpacity(0.5), size: 48),
                const SizedBox(height: 12),
                Text('No check-ins or insights yet.', style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

// --- UI Widgets ---
class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _QuickStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.13),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: colorScheme.primary, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MetricOption {
  final String label;
  final String key;
  final double min;
  final double max;
  const _MetricOption(this.label, this.key, {this.min = 0, this.max = 10});
}

class _MetricCard extends StatelessWidget {
  final _MetricOption metric;
  final List<_UserCheckIn> userCheckIns;
  final bool selected;
  final VoidCallback onTap;
  const _MetricCard({required this.metric, required this.userCheckIns, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final values = userCheckIns.map((c) => c.answers[metric.key]).where((v) => v != null).map((v) => (v as num).toDouble()).toList();
    final current = values.isNotEmpty ? values.first : 0.0;
    final best = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 0.0;
    final prev = values.length > 1 ? values[1] : current;
    final change = current - prev;

    // For 'Stress', positive change is bad (red), negative is good (green)
    bool isStress = metric.key == 'stress_level';
    Color getChangeColor() {
      if (change == 0.0) return colorScheme.onSurface.withOpacity(0.5);
      if (isStress) {
        return change > 0
            ? (selected ? colorScheme.onPrimary : colorScheme.error)
            : (selected ? colorScheme.onPrimary : Colors.green);
      } else {
        return change > 0
            ? (selected ? colorScheme.onPrimary : Colors.green)
            : (change < 0
                ? (selected ? colorScheme.onPrimary : colorScheme.error)
                : colorScheme.onSurface.withOpacity(0.5));
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(selected ? 0.18 : 0.07),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: selected ? colorScheme.primary : theme.dividerColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getMetricIcon(metric.label), color: selected ? colorScheme.onPrimary : colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(metric.label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? colorScheme.onPrimary : colorScheme.primary, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: values.length > 1
                  ? _MiniLineChart(values: values, accent: selected ? colorScheme.onPrimary : colorScheme.primary, min: metric.min, max: metric.max)
                  : Center(child: Text('No data', style: TextStyle(color: selected ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.5), fontSize: 13))),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Now', style: TextStyle(color: selected ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                Text(current.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: selected ? colorScheme.onPrimary : colorScheme.primary, fontSize: 16)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Best', style: TextStyle(color: selected ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                Text(best.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: selected ? colorScheme.onPrimary : colorScheme.primary, fontSize: 14)),
                Text(
                  change == 0.0 ? '' : (change > 0 ? '+${change.toStringAsFixed(1)}' : change.toStringAsFixed(1)),
                  style: TextStyle(
                    color: getChangeColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  final List<double> values;
  final Color accent;
  final double min;
  final double max;
  const _MiniLineChart({required this.values, required this.accent, required this.min, required this.max});
  
  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        minY: min,
        maxY: max,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (int i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values.reversed.toList()[i]),
            ],
            isCurved: true,
            barWidth: 2.5,
            color: accent,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}

// --- Timeline Feed Cards ---
class _UserCheckInFeedCard extends StatelessWidget {
  final _UserCheckIn checkIn;
  final String userName;
  const _UserCheckInFeedCard({required this.checkIn, required this.userName});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(checkIn.date);
    final answers = checkIn.answers;
    final keyMetrics = [
      {'key': 'overall_satisfaction', 'label': 'Satisfaction', 'icon': Icons.emoji_emotions, 'color': Colors.green},
      {'key': 'feeling_connected', 'label': 'Connection', 'icon': Icons.favorite, 'color': Colors.pink},
      {'key': 'stress_level', 'label': 'Stress', 'icon': Icons.bolt, 'color': Colors.orange},
      {'key': 'communication_quality', 'label': 'Communication', 'icon': Icons.chat_bubble_outline, 'color': Colors.blue},
      {'key': 'gratitude_score', 'label': 'Gratitude', 'icon': Icons.volunteer_activism, 'color': Colors.purple},
      {'key': 'physical_intimacy', 'label': 'Intimacy', 'icon': Icons.nightlife, 'color': Colors.deepPurple},
      {'key': 'emotional_support', 'label': 'Support', 'icon': Icons.handshake, 'color': Colors.teal},
      {'key': 'fun_together', 'label': 'Fun', 'icon': Icons.celebration, 'color': Colors.amber},
      {'key': 'shared_goals', 'label': 'Goals', 'icon': Icons.flag, 'color': Colors.indigo},
    ];
    
    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor, width: 1.5)
      ),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_turned_in, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(dateStr, style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('My Check-In', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: keyMetrics.where((m) => answers.containsKey(m['key']) && answers[m['key']] != null).map((m) => _AnswerChip(
                icon: m['icon'] as IconData,
                label: m['label'] as String,
                value: answers[m['key']].toString(),
                color: m['color'] as Color,
              )).toList(),
            ),
            const SizedBox(height: 12),
            if (checkIn.sharedInsights.isNotEmpty) ...[
              const Divider(height: 24),
              Text('My Private Insights:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...checkIn.sharedInsights.map((insight) => _QuoteCard(text: insight)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _AnswerChip({required this.icon, required this.label, required this.value, required this.color});
  
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color.withOpacity(0.13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}

class _OtherAnswerChip extends StatelessWidget {
  final String label;
  final String value;
  const _OtherAnswerChip({required this.label, required this.value});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Text('${label.replaceAll('_', ' ').toUpperCase()}: $value', style: const TextStyle(fontSize: 12)),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final String text;
  const _QuoteCard({required this.text});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: colorScheme.onSurface.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerInsightFeedCard extends StatelessWidget {
  final _PartnerSharedCheckInGroup group;
  final String partnerName;
  const _PartnerInsightFeedCard({required this.group, required this.partnerName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(group.date);
    final answers = group.answers ?? {};
    final keyMetrics = [
      {'key': 'overall_satisfaction', 'label': 'Satisfaction', 'icon': Icons.emoji_emotions, 'color': Colors.green},
      {'key': 'feeling_connected', 'label': 'Connection', 'icon': Icons.favorite, 'color': Colors.pink},
      {'key': 'stress_level', 'label': 'Stress', 'icon': Icons.bolt, 'color': Colors.orange},
      {'key': 'communication_quality', 'label': 'Communication', 'icon': Icons.chat_bubble_outline, 'color': Colors.blue},
      {'key': 'gratitude_score', 'label': 'Gratitude', 'icon': Icons.volunteer_activism, 'color': Colors.purple},
      {'key': 'physical_intimacy', 'label': 'Intimacy', 'icon': Icons.nightlife, 'color': Colors.deepPurple},
      {'key': 'emotional_support', 'label': 'Support', 'icon': Icons.handshake, 'color': Colors.teal},
      {'key': 'fun_together', 'label': 'Fun', 'icon': Icons.celebration, 'color': Colors.amber},
      {'key': 'shared_goals', 'label': 'Goals', 'icon': Icons.flag, 'color': Colors.indigo},
    ];
    
    return Card(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor, width: 1.5)
      ),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: colorScheme.secondary, size: 22),
                const SizedBox(width: 8),
                Text(dateStr, style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    group.isFullCheckIn ? 'Full Check-In' : 'Shared Insights',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.secondary)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (group.isFullCheckIn && answers.isNotEmpty) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: keyMetrics.where((m) => answers.containsKey(m['key']) && answers[m['key']] != null).map((m) => _AnswerChip(
                  icon: m['icon'] as IconData,
                  label: m['label'] as String,
                  value: answers[m['key']].toString(),
                  color: m['color'] as Color,
                )).toList(),
              ),
              const SizedBox(height: 12),
              if (answers.keys.any((k) => !keyMetrics.any((m) => m['key'] == k))) ...[
                const Divider(height: 24),
                Text('Other Answers:', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: answers.entries.where((entry) => !keyMetrics.any((m) => m['key'] == entry.key)).map((entry) => _OtherAnswerChip(
                    label: entry.key,
                    value: entry.value.toString(),
                  )).toList(),
                ),
              ],
            ],
            if (group.sharedInsights.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Shared Insights from ${partnerName.split(' ').first}:', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...group.sharedInsights.map((insight) => _QuoteCard(text: insight.replaceAll('Your partner', partnerName.split(' ').first))),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Data Models ---
class _UserCheckIn {
  final DateTime date;
  final Map<String, dynamic> answers;
  final List<String> sharedInsights;
  final bool isCompleted;
  _UserCheckIn({required this.date, required this.answers, required this.sharedInsights, required this.isCompleted});
}

class _PartnerSharedCheckInGroup {
  final DateTime date;
  final String user;
  final bool isFullCheckIn;
  final Map<String, dynamic>? answers; // Only for full check-in
  final List<String> sharedInsights;
  _PartnerSharedCheckInGroup({
    required this.date,
    required this.user,
    required this.isFullCheckIn,
    this.answers,
    required this.sharedInsights,
  });
}

class _TimelineEvent {
  final DateTime date;
  final bool isUser;
  final _UserCheckIn? userCheckIn;
  final _PartnerSharedCheckInGroup? partnerInsight;
  _TimelineEvent({required this.date, required this.isUser, this.userCheckIn, this.partnerInsight});
}