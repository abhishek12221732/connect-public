import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feelings/providers/done_dates_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:intl/intl.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class DoneDatesScreen extends StatefulWidget {
  const DoneDatesScreen({super.key});

  @override
  State<DoneDatesScreen> createState() => _DoneDatesScreenState();
}

class _DoneDatesScreenState extends State<DoneDatesScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDoneDates();
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _selectedFilter = prefs.getString('done_dates_selected_filter') ?? 'all';
        });
      }
    } catch (e) {
      print("[DoneDatesScreen] Error loading preferences: $e");
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('done_dates_selected_filter', _selectedFilter);
    } catch (e) {
      print("[DoneDatesScreen] Error saving preferences: $e");
    }
  }

  Future<void> _initializeDoneDates() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.getUserId() ?? '';
    final coupleId = userProvider.coupleId ?? '';
    
    if (userId.isNotEmpty && coupleId.isNotEmpty) {
      final doneDatesProvider = Provider.of<DoneDatesProvider>(context, listen: false);
      doneDatesProvider.initializeRepository(coupleId);
      await doneDatesProvider.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Dates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Validate Calendar Events',
            onPressed: () async {
              final doneDatesProvider = Provider.of<DoneDatesProvider>(context, listen: false);
              await doneDatesProvider.forceValidateAllCalendarEvents();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Calendar validation completed'),
                    backgroundColor: colorScheme.secondary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
              _savePreferences();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Dates')),
              const PopupMenuItem(value: 'suggestion', child: Text('From Suggestions')),
              const PopupMenuItem(value: 'calendar', child: Text('From Calendar')),
              const PopupMenuItem(value: 'bucket_list', child: Text('From Bucket List')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Consumer2<DoneDatesProvider, UserProvider>(
        builder: (context, doneDatesProvider, userProvider, child) {
          if (doneDatesProvider.isLoading) {
            return Center(child: PulsingDotsIndicator(
                                  size: 50,
                                  colors: [
                                    colorScheme.onPrimary,
                                    colorScheme.onPrimary.withOpacity(0.8),
                                    colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                ));
          }

          if (doneDatesProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: colorScheme.onSurface.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text('Error loading completed dates', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      doneDatesProvider.error!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          List<Map<String, dynamic>> filteredDates = _selectedFilter == 'all'
              ? doneDatesProvider.doneDates
              : doneDatesProvider.getDoneDatesBySource(_selectedFilter);

          if (filteredDates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFilter == 'all' 
                          ? 'No completed dates yet'
                          : 'No dates from ${_getFilterDisplayName(_selectedFilter)}',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFilter == 'all'
                          ? 'Start completing dates to see them here!'
                          : 'Try completing some dates from ${_getFilterDisplayName(_selectedFilter)}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Completed: ${filteredDates.length}',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Filter: ${_getFilterDisplayName(_selectedFilter)}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDates.length,
                  itemBuilder: (context, index) {
                    final date = filteredDates[index];
                    return _buildDateCard(date);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateCard(Map<String, dynamic> date) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sourceColor = _getSourceColor(date['source'] as String? ?? 'unknown', colorScheme);

    final title = date['title'] as String? ?? 'Unknown Date';
    final description = date['description'] as String? ?? '';
    final actualDate = date['actualDate'] as DateTime?;
    final rating = date['rating'] as int?;
    final notes = date['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getSourceIcon(date['source'] as String? ?? 'unknown'), color: sourceColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (rating != null) ...[
                  Icon(Icons.star, color: colorScheme.secondary, size: 16),
                  const SizedBox(width: 4),
                  Text(rating.toString(), style: theme.textTheme.titleSmall),
                ],
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurface.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(
                  actualDate != null ? DateFormat('MMM dd, yyyy').format(actualDate) : 'Date not specified',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sourceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getSourceDisplayName(date['source'] as String? ?? 'unknown'),
                    style: theme.textTheme.labelSmall?.copyWith(color: sourceColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(notes, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'suggestion': return Icons.chat_bubble;
      case 'calendar': return Icons.calendar_today;
      case 'bucket_list': return Icons.check_box;
      default: return Icons.event;
    }
  }

  Color _getSourceColor(String source, ColorScheme colorScheme) {
    switch (source) {
      case 'suggestion': return colorScheme.primary;
      case 'calendar': return colorScheme.secondary;
      case 'bucket_list': return colorScheme.tertiary;
      default: return colorScheme.onSurface.withOpacity(0.7);
    }
  }

  String _getSourceDisplayName(String source) {
    switch (source) {
      case 'suggestion': return 'Suggestion';
      case 'calendar': return 'Calendar';
      case 'bucket_list': return 'Bucket List';
      default: return 'Unknown';
    }
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'all': return 'All Sources';
      case 'suggestion': return 'Suggestions';
      case 'calendar': return 'Calendar';
      case 'bucket_list': return 'Bucket List';
      default: return 'Unknown';
    }
  }
}