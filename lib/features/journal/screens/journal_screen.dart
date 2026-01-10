// lib/features/journal/screens/journal_screen.dart

import 'dart:io';
import 'package:feelings/features/auth/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animate_do/animate_do.dart';

import '../../../providers/media_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../media/repository/media_repository.dart'; // ✨ Added
import '../../journal/repository/journal_repository.dart'; // ✨ Added
import '../../media/widgets/memory_card.dart';
import '../widgets/journal_tile.dart';
import 'journal_editing_screen.dart';
import '../../discover/widgets/connect_with_partner_card.dart';
import 'package:feelings/features/connectCouple/screens/connect_couple_screen.dart';
import 'journal_fab_menu.dart';
import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

// ✨ --- NEW IMPORTS --- ✨
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/secret_note/widgets/secret_note_view_dialog.dart';
// ✨ --- END NEW IMPORTS --- ✨


// Helper class to hold different types of items in one unified list.
class JourneyItem {
  final String type; // 'memory', 'personalJournal', 'sharedJournal', or 'secretNote' ✨
  final DateTime timestamp;
  final Map<String, dynamic> data;

  JourneyItem({required this.type, required this.timestamp, required this.data});
}

enum JournalFilterOption { all, personal, shared, memory }
enum JournalSortOption { newest, oldest, titleAZ, titleZA }


class JournalScreen extends StatefulWidget {
 final bool showAddMemoryModal;
  final JournalFilterOption? filterToShow;

  const JournalScreen({
    super.key,
    this.showAddMemoryModal = false,
    this.filterToShow,
  });
  @override
  _JournalScreenState createState() => _JournalScreenState();
}

// ✨ --- ADD TickerProviderStateMixin --- ✨
class _JournalScreenState extends State<JournalScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  JournalSortOption _currentSort = JournalSortOption.newest;
  JournalFilterOption _currentFilter = JournalFilterOption.all;
  bool _isGridView = false;
  bool _isInitialized = false;

  // ✨ --- NEW ANIMATION CONTROLLER --- ✨
  late final AnimationController _giftAnimationController;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initializeData();

    // ✨ --- NEW ANIMATION --- ✨
    _giftAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showAddMemoryModal && mounted) {
        _showAddMemoryDialog();
      }
      if (widget.filterToShow != null && mounted) {
        setState(() {
          // This sets the filter based on which button was pressed.
          _currentFilter = widget.filterToShow!;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _giftAnimationController.dispose(); // ✨ --- DISPOSE --- ✨
    super.dispose();
  }

  // ... (rest of initState, dispose, _loadPreferences, _savePreferences, _initializeData, _openNewEntryScreen are unchanged) ...
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isGridView = prefs.getBool('journal_is_grid_view') ?? false;
        
        final sortValue = prefs.getString('journal_sort_option') ?? 'newest';
        _currentSort = JournalSortOption.values.firstWhere(
          (option) => option.toString().split('.').last == sortValue,
          orElse: () => JournalSortOption.newest,
        );
        
        if (widget.filterToShow != null) {
          _currentFilter = widget.filterToShow!;
        } else {
          final filterValue = prefs.getString('journal_filter_option') ?? 'all';
          _currentFilter = JournalFilterOption.values.firstWhere(
            (option) => option.toString().split('.').last == filterValue,
            orElse: () => JournalFilterOption.all,
          );
        }
      });
    }
  }


  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('journal_is_grid_view', _isGridView);
    await prefs.setString('journal_sort_option', _currentSort.toString().split('.').last);
    await prefs.setString('journal_filter_option', _currentFilter.toString().split('.').last);
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      final mediaProvider = Provider.of<MediaProvider>(context, listen: false);

      String? userId = userProvider.getUserId();
      String? coupleId = userProvider.coupleId;

      if (userId != null) journalProvider.listenToPersonalJournals(userId);
      if (coupleId != null) {
        journalProvider.listenToSharedJournals(coupleId);
        if (!mediaProvider.hasInitialized) mediaProvider.initializeMemoriesStream(coupleId);
      }
      
      if (mounted) setState(() => _isInitialized = true);
    });
  }
  
  void _openNewEntryScreen({required bool isShared}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => JournalEditingScreen(isShared: isShared)));
  }

  // ✨ --- NEW HELPER METHOD --- ✨
  void _openSecretNote(BuildContext context, SecretNoteProvider provider) {
    final note = provider.activeSecretNote;
    if (note == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SecretNoteViewDialog(note: note),
    );
    provider.markNoteAsRead(note.id);
  }

  // ✨ --- MODIFIED: Added secretNoteProvider --- ✨
  List<JourneyItem> _getCombinedAndSortedList(
    JournalProvider journalProvider, 
    MediaProvider mediaProvider,
    SecretNoteProvider secretNoteProvider, // Added
  ) {
    final isConnected = context.read<UserProvider>().coupleId != null;

    final List<JourneyItem> combinedList = [];

    // ✨ --- NEW: Add Secret Note if active --- ✨
    if (secretNoteProvider.activeNoteLocation == SecretNoteLocation.journal &&
        secretNoteProvider.activeSecretNote != null &&
        _currentFilter != JournalFilterOption.memory) { // Don't show if filtering *only* for memories
      combinedList.add(JourneyItem(
        type: 'secretNote',
        // Make it appear at the top by using a future timestamp
        timestamp: DateTime.now().add(const Duration(days: 365)), 
        data: {'id': secretNoteProvider.activeSecretNote!.id},
      ));
    }
    // ✨ --- END NEW --- ✨
    
    combinedList.addAll(journalProvider.personalEntries.map((entry) => JourneyItem(type: 'personalJournal', timestamp: _getTimestamp(entry), data: entry)));

    if (isConnected) {
      if (mediaProvider.optimisticMemory != null) {
        combinedList.add(JourneyItem(
          type: 'memory',
          timestamp: (mediaProvider.optimisticMemory!['createdAt'] as Timestamp).toDate(),
          data: mediaProvider.optimisticMemory!,
        ));
      }
      combinedList.addAll(journalProvider.sharedEntries.map((entry) => JourneyItem(type: 'sharedJournal', timestamp: _getTimestamp(entry), data: entry)));
      combinedList.addAll(mediaProvider.memoriesCache.map((memory) => JourneyItem(type: 'memory', timestamp: _getTimestamp(memory, isMemory: true), data: memory)));
    }

    final uniqueIds = <String>{};
    final uniqueList = combinedList.where((item) {
      if (item.type == 'secretNote') return true; // Always include secret note

      final isOptimisticDuplicate = item.data['isOptimistic'] != true &&
          mediaProvider.optimisticMemory != null &&
          item.data['text'] == mediaProvider.optimisticMemory!['text'];

      final String? itemId = item.type == 'memory' ? item.data['docId'] : item.data['id'];

      if (itemId == null) return true;

      if (isOptimisticDuplicate || !uniqueIds.add(itemId)) {
        return false;
      }
      return true;
    }).toList();


    List<JourneyItem> filteredList = uniqueList;
    if (_searchQuery.isNotEmpty) {
      String query = _searchQuery.toLowerCase();
      filteredList = uniqueList.where((item) {
        if (item.type == 'secretNote') return false; // Don't include secret note in search
        final data = item.data;
        final text = (item.type == 'memory' ? data['text'] : (data['title'] ?? '') + ' ' + (data['content'] ?? '')).toString().toLowerCase();
        return text.contains(query);
      }).toList();
    }

    if (_currentFilter != JournalFilterOption.all) {
      filteredList = filteredList.where((item) {
        // Special case: Keep secret note unless filtering *only* for memories
        if (item.type == 'secretNote') {
          return _currentFilter != JournalFilterOption.memory;
        }
        switch (_currentFilter) {
          case JournalFilterOption.personal:
            return item.type == 'personalJournal';
          case JournalFilterOption.shared:
            return item.type == 'sharedJournal';
          case JournalFilterOption.memory:
            return item.type == 'memory';
          case JournalFilterOption.all:
            return true;
        }
      }).toList();
    }

    filteredList.sort((a, b) {
      // Keep secret note at the top regardless of sort
      if (a.type == 'secretNote') return -1;
      if (b.type == 'secretNote') return 1;

      switch (_currentSort) {
        case JournalSortOption.newest: return b.timestamp.compareTo(a.timestamp);
        case JournalSortOption.oldest: return a.timestamp.compareTo(b.timestamp);
        case JournalSortOption.titleAZ:
          final aTitle = (a.data['title'] ?? a.data['text'] ?? '').toString().toLowerCase();
          final bTitle = (b.data['title'] ?? b.data['text'] ?? '').toString().toLowerCase();
          return aTitle.compareTo(bTitle);
        case JournalSortOption.titleZA:
          final aTitle = (a.data['title'] ?? a.data['text'] ?? '').toString().toLowerCase();
          final bTitle = (b.data['title'] ?? b.data['text'] ?? '').toString().toLowerCase();
          return bTitle.compareTo(aTitle);
      }
    });

    return filteredList;
  }

  DateTime _getTimestamp(Map<String, dynamic> item, {bool isMemory = false}) {
    final key = isMemory ? 'createdAt' : 'timestamp';
    final timestamp = item[key];
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Our Journey'), centerTitle: true),
      // ✨ --- WATCH 5 PROVIDERS --- ✨
      body: Consumer5<JournalProvider, MediaProvider, UserProvider, CoupleProvider, SecretNoteProvider>(
        builder: (context, journalProvider, mediaProvider, userProvider, coupleProvider, secretNoteProvider, _) {
          
          if (!_isInitialized) {
            return _buildLoadingSkeleton();
          }

          // ✨ --- PASS PROVIDER TO LIST --- ✨
          final List<JourneyItem> items = _getCombinedAndSortedList(
            journalProvider, 
            mediaProvider,
            secretNoteProvider,
          );
          final bool isConnected = userProvider.coupleId != null;
           final String? coupleId = userProvider.coupleId;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _isSearching ? _buildSearchBar() : _buildControlBar(),
              ),

              if (coupleId != null)
                _buildInactiveRelationshipWarning(coupleId, coupleProvider),

              if (items.isEmpty && !_isSearching && mediaProvider.optimisticMemory == null)
                Expanded(child: _buildEmptyState(isConnected: isConnected))
              else if (items.isEmpty && _isSearching)
                Expanded(child: _buildEmptySearchState())
              else
                // ✨ --- PASS PROVIDER TO BUILDER --- ✨
                Expanded(child: _buildContentList(items, secretNoteProvider)),
            ],
          );
        },
      ),
      floatingActionButton: JournalFabMenu(
        onAddMemory: _showAddMemoryDialog,
        onAddSharedJournal: () => _openNewEntryScreen(isShared: true),
        onAddPersonalJournal: () => _openNewEntryScreen(isShared: false),
      ),
    );
  }
  
  // ... (_buildControlBar, _getFilterDisplay, _buildFilterButton, _getSortDisplay, _buildSortButton, _buildSearchBar are unchanged) ...
  
  Widget _buildControlBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          _buildFilterButton(),
          const SizedBox(width: 8),
          _buildSortButton(),
          const Spacer(),
          IconButton(icon: const Icon(Icons.search), tooltip: 'Search', onPressed: () => setState(() => _isSearching = true)),
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(_isGridView ? Icons.view_list : Icons.grid_view, key: ValueKey(_isGridView)),
            ),
            tooltip: _isGridView ? 'List View' : 'Grid View',
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
              _savePreferences();
            },
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getFilterDisplay(JournalFilterOption filter) {
    switch (filter) {
      case JournalFilterOption.all:
        return {'label': 'All', 'icon': Icons.all_inclusive_rounded};
      case JournalFilterOption.personal:
        return {'label': 'Personal', 'icon': Icons.person_outline};
      case JournalFilterOption.shared:
        return {'label': 'Shared', 'icon': Icons.people_alt_outlined};
      case JournalFilterOption.memory:
        return {'label': 'Memories', 'icon': Icons.photo_library_outlined};
    }
  }

  Widget _buildFilterButton() {
    final display = _getFilterDisplay(_currentFilter);

    return PopupMenuButton<JournalFilterOption>(
      tooltip: 'Filter By',
      onSelected: (JournalFilterOption result) {
        setState(() {
          _currentFilter = result;
          _savePreferences();
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<JournalFilterOption>>[
        for (final option in JournalFilterOption.values)
          PopupMenuItem<JournalFilterOption>(
            value: option,
            child: Text(_getFilterDisplay(option)['label'] as String),
          ),
      ],
      child: _ControlChip(
        icon: display['icon'] as IconData,
        label: display['label'] as String,
      ),
    );
  }

  Map<String, dynamic> _getSortDisplay(JournalSortOption sort) {
    switch (sort) {
      case JournalSortOption.newest:
        return {'label': 'Newest', 'icon': Icons.arrow_downward_rounded};
      case JournalSortOption.oldest:
        return {'label': 'Oldest', 'icon': Icons.arrow_upward_rounded};
      case JournalSortOption.titleAZ:
        return {'label': 'A-Z', 'icon': Icons.sort_by_alpha_rounded};
      case JournalSortOption.titleZA:
        return {'label': 'Z-A', 'icon': Icons.sort_by_alpha_rounded};
    }
  }

  Widget _buildSortButton() {
    final display = _getSortDisplay(_currentSort);

    return PopupMenuButton<JournalSortOption>(
      tooltip: 'Sort By',
      onSelected: (JournalSortOption result) {
        setState(() {
          _currentSort = result;
          _savePreferences();
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<JournalSortOption>>[
        for (final option in JournalSortOption.values)
          PopupMenuItem<JournalSortOption>(
            value: option,
            child: Text(_getSortDisplay(option)['label'] as String),
          ),
      ],
      child: _ControlChip(
        icon: display['icon'] as IconData,
        label: display['label'] as String,
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search journey...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          }),
        ),
      ),
    );
  }

  // ✨ --- MODIFIED: Added secretNoteProvider --- ✨
  Widget _buildContentList(List<JourneyItem> allItems, SecretNoteProvider secretNoteProvider) {
    final userProvider = context.watch<UserProvider>();
    final isConnected = userProvider.coupleId != null;

    final connectCard = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ConnectWithPartnerCard(
        title: 'Connect with a partner!',
        message: 'Share your journey by adding shared memories and journal entries together.',
        icon: Icons.favorite_border,
        buttonLabel: 'Connect Now',
        onButtonPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectCoupleScreen())),
      ),
    );
    
    if (_isGridView) {
      final double horizontalPadding = 16.0;
      final double spacing = 16.0;
      final double screenWidth = MediaQuery.of(context).size.width;
      final double itemWidth = (screenWidth - (horizontalPadding * 2) - spacing) / 2;

      final List<Widget> gridChildren = allItems.map((item) {
        Widget child;
        // ✨ --- NEW: Check for secretNote type --- ✨
        if (item.type == 'secretNote') {
          child = _SecretNoteGridItem(
            provider: secretNoteProvider,
            animationController: _giftAnimationController,
            onTap: () => _openSecretNote(context, secretNoteProvider),
          );
        } else if (item.type == 'memory') {
          if (item.data['isOptimistic'] == true) {
            child = _UploadingMemoryCard(imageFile: File(item.data['imageId']));
          } else {
            child = MemoryCard(
              docId: item.data['docId'],
              imageId: item.data['imageId'],
              text: item.data['text'],
              isUser: item.data['createdBy'] == context.read<UserProvider>().getUserId(),
              createdAt: Timestamp.fromDate(item.timestamp),
              coupleId: context.read<UserProvider>().coupleId!,
              onDelete: () => _deleteMemory(context.read<MediaProvider>(), context.read<UserProvider>().coupleId!, item.data),
              showTextSection: false,
            );
          }
        } else {
          child = _JournalGridItem(item: item);
        }
        return SizedBox(
          width: itemWidth,
          child: child,
        );
      }).toList();

      return SingleChildScrollView(
        child: Column(
          children: [
            if (!isConnected) connectCard,
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: gridChildren,
              ),
            ),
          ],
        ),
      );
    } else { // ListView (Timeline)
      final List<dynamic> flattenedList = [];
      final groupedItems = _groupItemsByDate(allItems);

      // ✨ --- MODIFIED: Handle secret note in sorting --- ✨
      final List<JourneyItem>? secretNote = groupedItems.remove('secretNote');
      final sortedKeys = groupedItems.keys.toList()
        ..sort((a, b) {
          final dateA = groupedItems[a]!.first.timestamp;
          final dateB = groupedItems[b]!.first.timestamp;
          return dateB.compareTo(dateA);
        });
      
      // Add secret note first (if it exists)
      if (secretNote != null) {
        flattenedList.add('A Secret Note'); // Special header
        flattenedList.addAll(secretNote);
      }
      
      for (var key in sortedKeys) {
        flattenedList.add(key);
        flattenedList.addAll(groupedItems[key]!);
      }

      return Column(
        children: [
          if (!isConnected) connectCard,
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: flattenedList.length,
              itemBuilder: (context, index) {
                final item = flattenedList[index];
                if (item is String) {
                  return _DateHeader(title: item, isSecret: item == 'A Secret Note'); // ✨ Pass flag
                } 
                if (item is JourneyItem) {
                  VoidCallback? onDeleteMemory;
                  if (item.type == 'memory' && item.data['isOptimistic'] != true) {
                    onDeleteMemory = () => _deleteMemory(context.read<MediaProvider>(), context.read<UserProvider>().coupleId!, item.data);
                  }

                  // ✨ --- NEW: Check for secretNote type --- ✨
                  if (item.type == 'secretNote') {
                    return _SecretNoteTimelineItem(
                      provider: secretNoteProvider,
                      animationController: _giftAnimationController,
                      onTap: () => _openSecretNote(context, secretNoteProvider),
                      isFirst: true, // Always first in its "group"
                      isLast: true,  // Always last in its "group"
                    );
                  }

                  return _TimelineEventCard(
                    item: item,
                    isFirst: index > 0 && flattenedList[index - 1] is String,
                    isLast: index == flattenedList.length - 1 || flattenedList[index + 1] is String,
                    onDeleteMemory: onDeleteMemory,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      );
    }
  }

  // ✨ --- MODIFIED: Handle secretNote type --- ✨
  Map<String, List<JourneyItem>> _groupItemsByDate(List<JourneyItem> items) {
    final Map<String, List<JourneyItem>> grouped = {};
    for (var item in items) {
      if (item.type == 'secretNote') {
        grouped['secretNote'] = [item]; // Give it a special key
        continue;
      }
      final dateKey = _formatDate(item.timestamp);
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(item);
    }
    return grouped;
  }

  // ... (rest of file is unchanged: _formatDate, _buildEmptyState, _buildInactiveRelationshipWarning, _buildEmptySearchState, _showAddMemoryDialog, _pickImage, _uploadMedia, _deleteMemory, _showErrorSnackBar, _showSuccessSnackBar, _buildLoadingSkeleton, _ControlChip, _TimelineEventCard, _DateHeader, _JournalGridItem, _UploadingMemoryCard, _AddMemoryBottomSheet) ...
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) return 'Today';
    if (dateToCompare == yesterday) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Widget _buildEmptyState({bool isConnected = true}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Your Journey Starts Here', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              isConnected
                  ? 'Add your first shared memory or journal entry to begin.'
                  : 'Add your first personal journal entry to begin.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          if (!isConnected) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.favorite_border),
              label: const Text('Connect with a Partner'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectCoupleScreen())),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildInactiveRelationshipWarning(String coupleId, CoupleProvider coupleProvider) {
    return FutureBuilder<bool>(
      future: coupleProvider.isRelationshipInactive(coupleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
          final theme = Theme.of(context);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your partner has disconnected. You can still see the shared data.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No Results Found', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Try searching for something else.', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _showAddMemoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddMemoryBottomSheet(
          onPickImage: _pickImage,
          onUpload: (File imageFile, String text) {
            _uploadMedia(
              context.read<MediaProvider>(), 
              context.read<UserProvider>().coupleId!, 
              context.read<UserProvider>().getUserId()!, 
              imageFile, 
              text,
              isEncryptionEnabled: context.read<UserProvider>().isEncryptionEnforced
            );
          },
        ),
      ),
    );
  }

  Future<File?> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    return pickedFile != null ? File(pickedFile.path) : null;
  }
  
  void _uploadMedia(MediaProvider mediaProvider, String coupleId, String userId, File imageFile, String text, {required bool isEncryptionEnabled}) {
    mediaProvider.uploadMedia(coupleId, imageFile, text, userId, isEncryptionEnabled: isEncryptionEnabled)
      .catchError((e) {
        if (mounted) {
          _showErrorSnackBar('Upload failed: ${e.toString()}');
        }
      });
  }

  Future<void> _deleteMemory(MediaProvider mediaProvider, String coupleId, Map<String, dynamic> data) async {
    try {
      await mediaProvider.deletePost(coupleId, data['docId'], data['imageId']);
      _showSuccessSnackBar('Memory deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to delete memory: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }
  
  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(5, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 150, height: 20.0, color: Colors.white, margin: const EdgeInsets.only(bottom: 16)),
              Container(width: double.infinity, height: 150.0, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            ],
          ),
        )),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ControlChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant
          )),
        ],
      ),
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  final JourneyItem item;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onDeleteMemory;

  const _TimelineEventCard({
    required this.item, 
    required this.isFirst, 
    required this.isLast,
    this.onDeleteMemory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;
    final lineColor = theme.dividerColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 1.5, height: 12, color: isFirst ? Colors.transparent : lineColor),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor, width: 1.5),
                ),
                child: Icon(_getIconForItem(item), size: 18, color: iconColor),
              ),
              Expanded(child: Container(width: 1.5, color: isLast ? Colors.transparent : lineColor)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(child: _buildItemContent(context, item)),
        ],
      ),
    );
  }

  IconData _getIconForItem(JourneyItem item) {
    switch (item.type) {
      case 'memory': return Icons.photo_camera_back_outlined;
      case 'sharedJournal': return Icons.people_alt_outlined;
      case 'personalJournal':
      default: return Icons.person_outline;
    }
  }

  Widget _buildItemContent(BuildContext context, JourneyItem item) {
    // ✨ --- LAZY MIGRATION CHECK ---
    final coupleId = context.read<UserProvider>().coupleId;
    if (coupleId != null) {
       _checkMigration(context, item, coupleId);
    }
    
    final data = item.data;

    // ✨ --- ROBUST ERROR HANDLING --- ✨
    try {
      if (item.type == 'memory') {
        // ✨ Skip invalid documents only if docId is missing.
        // If imageId is missing, we'll try to show the card with a placeholder.
        if (data['docId'] == null) {
           debugPrint("⚠️ [JournalScreen] SKIP INVALID MEMORY: Missing docId. Data: $data");
           return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: item.data['isOptimistic'] == true
              ? _UploadingMemoryCard(imageFile: File(item.data['imageId']))
              : MemoryCard(
                  docId: data['docId'] ?? "unknown",
                  imageId: data['imageId'] ?? "",
                  text: data['text'] ?? "", // Handle null text
                  isUser: data['createdBy'] == context.read<UserProvider>().getUserId(),
                  createdAt: Timestamp.fromDate(item.timestamp),
                  coupleId: context.read<UserProvider>().coupleId!,
                  onDelete: onDeleteMemory!,
                  showTextSection: true,
                  encryptionVersion: data['encryptionVersion'],
                  ciphertextId: data['ciphertextId'],
                  nonceId: data['nonceId'],
                  macId: data['macId'],
                  ciphertextText: data['ciphertextText'],
                  nonceText: data['nonceText'],
                  macText: data['macText'],
                ),
        );
      } else {
        // VALIDATE JOURNAL DATA
        if (data['id'] == null) {
           debugPrint("⚠️ [JournalScreen] SKIP INVALID JOURNAL: Missing id. Data: $data");
           return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: JournalTile(
            title: data['title'] ?? 'Untitled',
            content: data['content'],
            segments: (data['segments'] is List) ? data['segments'] as List<dynamic> : null,
            timestamp: Timestamp.fromDate(item.timestamp),
            journalId: data['id'] ?? "unknown",
            isShared: item.type == 'sharedJournal',
            encryptionVersion: data['encryptionVersion'] ?? (
               item.type == 'sharedJournal' && data['segments'] != null
               ? (() {
                   final segs = (data['segments'] as List);
                   // debugPrint("🔍 [JournalScreen] Shared Journal ${data['id']} Segments: $segs");
                   return segs.any((s) => s['encryptionVersion'] != null) ? 1 : null;
                 })()
               : null
            ),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JournalEditingScreen(
              entryData: data,
              isShared: item.type == 'sharedJournal',
            ))),
            ciphertext: data['ciphertext'],
            nonce: data['nonce'],
            mac: data['mac'],
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ [JournalScreen] Error building item content: $e. Data: $data");
      return const SizedBox.shrink();
    }
  }

  // ✨ --- HELPER: Trigger lazy migration for old items ---
  void _checkMigration(BuildContext context, JourneyItem item, String coupleId) {
    if (item.type == 'memory') {
       if (item.data['encryptionVersion'] == null && item.data['isOptimistic'] != true) {
         context.read<MediaRepository>().migrateLegacyMedia(coupleId, item.data['docId'], item.data);
       }
    } else if (item.type == 'sharedJournal') {
       // Check if migration is needed (missing encryption version on segments)
       bool needsMigration = false;
       final segments = item.data['segments'];
       if (segments is List) {
         for (var seg in segments) {
           final isTextType = seg['type'] == 'text' || seg['type'] == null;
           final content = seg['text'] ?? seg['content'];
           
           if (isTextType && seg['encryptionVersion'] == null && content != null && (content as String).isNotEmpty) {
             needsMigration = true;
             debugPrint("🔍 [JournalScreen] Migration needed for Shared Journal ${item.data['id']} (Segment: $content)");
             break;
           }
         }
       }
       
       if (needsMigration) {
         context.read<JournalRepository>().migrateLegacySharedJournal(coupleId, item.data['id'], item.data);
       }
    }
  }
}


class _DateHeader extends StatelessWidget {
  final String title;
  final bool isSecret; // ✨ --- NEW PARAMETER --- ✨

  const _DateHeader({required this.title, this.isSecret = false}); // ✨ --- ADDED --- ✨

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // ✨ --- NEW LOGIC --- ✨
    final Color titleColor = isSecret 
        ? theme.colorScheme.primary 
        : theme.colorScheme.onSurfaceVariant;
    final FontWeight fontWeight = isSecret 
        ? FontWeight.bold 
        : FontWeight.w600;
    final IconData? prefixIcon = isSecret ? Icons.mail_lock_rounded : null;
    // ✨ --- END NEW LOGIC --- ✨

    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
      child: Row( // ✨ --- WRAPPED IN ROW --- ✨
        children: [
          if (prefixIcon != null)
            Icon(prefixIcon, color: titleColor, size: 20),
          if (prefixIcon != null)
            const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: titleColor,
              fontWeight: fontWeight,
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalGridItem extends StatelessWidget {
  final JourneyItem item;
  const _JournalGridItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = context.watch<UserProvider>();
    final data = item.data;
    final isShared = item.type == 'sharedJournal';


    final ImageProvider userImage = userProvider.getProfileImageSync();
    final ImageProvider partnerImage = userProvider.getPartnerProfileImageSync();

    Widget buildAvatarSection() {
      if (isShared) {
        return Center(
          child: SizedBox(
            width: 70,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  right: 0,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: partnerImage,
                      backgroundColor: theme.colorScheme.secondary,
                      child: (partnerImage is AssetImage)
                          ? Icon(Icons.person_outline, color: theme.colorScheme.onSecondary)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: userImage,
                      backgroundColor: theme.colorScheme.primary,
                      child: (userImage is AssetImage)
                          ? Icon(Icons.person, color: theme.colorScheme.onPrimary)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        return Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.scaffoldBackgroundColor,
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: userImage,
                  backgroundColor: theme.colorScheme.primary,
                  child: (userImage is AssetImage)
                      ? Icon(Icons.person, size: 30, color: theme.colorScheme.onPrimary)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.onSurface, width: 1),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return AspectRatio(
      aspectRatio: 0.75,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JournalEditingScreen(
            entryData: data,
            isShared: isShared,
          ))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  child: buildAvatarSection(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data['title'] ?? 'Untitled',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MMM d, yyyy').format(item.timestamp),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                           // ✨ CHECK SEGMENTS FOR ENCRYPTION IF SHARED
                           if (data['encryptionVersion'] == 1 || (
                             isShared && data['segments'] != null && 
                             (data['segments'] as List).any((s) => s['encryptionVersion'] != null)
                           )) ...[
                            const SizedBox(width: 4),
                            Builder(builder: (context) {
                              debugPrint("🔒 [UI] Shared Journal Segment IS ENCRYPTED");
                              return Icon(Icons.lock, size: 12, color: theme.colorScheme.primary.withOpacity(0.7));
                            }),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ✨ --- ALL WIDGETS BELOW ARE NEW --- ✨

/// A special Grid Item for the Secret Note
class _SecretNoteGridItem extends StatelessWidget {
  final SecretNoteProvider provider;
  final AnimationController animationController;
  final VoidCallback onTap;

  const _SecretNoteGridItem({
    required this.provider,
    required this.animationController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 0.75,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.2),
                  theme.colorScheme.primary.withOpacity(0.05),
                ],
              ),
            ),
            child: Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.15)
                    .animate(animationController),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mail_lock_rounded,
                      color: theme.colorScheme.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "A Secret...",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A special Timeline Item for the Secret Note
class _SecretNoteTimelineItem extends StatelessWidget {
  final SecretNoteProvider provider;
  final AnimationController animationController;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _SecretNoteTimelineItem({
    required this.provider,
    required this.animationController,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;
    final lineColor = theme.dividerColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline painter
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 1.5, height: 12, color: isFirst ? Colors.transparent : lineColor),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor, width: 1.5),
                ),
                child: Icon(Icons.card_giftcard_rounded, size: 18, color: iconColor),
              ),
              Expanded(child: Container(width: 1.5, color: isLast ? Colors.transparent : lineColor)),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: FadeIn(
                duration: const Duration(milliseconds: 500),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.15)
                              .animate(animationController),
                          child: Icon(
                            Icons.mail_lock_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "You have a secret note...",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ✨ --- END NEW WIDGETS --- ✨

class _UploadingMemoryCard extends StatelessWidget {
  final File imageFile;

  const _UploadingMemoryCard({required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.75,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              imageFile,
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.5),
              colorBlendMode: BlendMode.dstATop,
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:  Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulsingDotsIndicator(
                                  size: 30,
                                  colors: [
                                    Theme.of(context).colorScheme.onPrimary,
                                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                ),
                    SizedBox(height: 12),
                    Text(
                      'Uploading...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemoryBottomSheet extends StatefulWidget {
  final Future<File?> Function() onPickImage;
  final Function(File imageFile, String text) onUpload;

  const _AddMemoryBottomSheet({
    required this.onPickImage,
    required this.onUpload,
  });

  @override
  State<_AddMemoryBottomSheet> createState() => _AddMemoryBottomSheetState();
}

class _AddMemoryBottomSheetState extends State<_AddMemoryBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  File? _selectedImage;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handlePickImage() async {
    final imageFile = await widget.onPickImage();
    if (imageFile != null && mounted) {
      setState(() => _selectedImage = imageFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaProvider = context.watch<MediaProvider>();
    final canUpload = _selectedImage != null && _textController.text.trim().isNotEmpty && !mediaProvider.isUploading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Memory', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_selectedImage != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_selectedImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, color: Colors.white, size: 16),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 24)),
              onPressed: _handlePickImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Select Photo'),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(hintText: 'Share a memory...'),
            maxLines: 3,
            onChanged: (text) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: canUpload
                ? () {
                    widget.onUpload(_selectedImage!, _textController.text.trim());
                    Navigator.pop(context);
                  }
                : null,
            icon: mediaProvider.isUploading 
              ?  SizedBox(width: 20, height: 20, child: PulsingDotsIndicator(
                                  size: 30,
                                  colors: [
                                    Theme.of(context).colorScheme.onPrimary,
                                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                                    Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
                                  ],
                                ))
              : const Icon(Icons.upload),
            label: Text(mediaProvider.isUploading ? 'Uploading...' : 'Upload Memory'),
          ),
        ],
      ),
    );
  }
}
