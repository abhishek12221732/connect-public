// lib/features/bucket_list/screens/bucket_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/bucket_list_provider.dart';
import '../../../providers/user_provider.dart';
// ✨ [ADD] Import for the custom loading indicator.
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class BucketListScreen extends StatefulWidget {
  final bool showAddItemModal;

  const BucketListScreen({
    super.key,
    this.showAddItemModal = false, // Default to false
  });

  @override
  _BucketListScreenState createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final bucketListProvider = Provider.of<BucketListProvider>(context, listen: false);
      final userId = userProvider.getUserId();
      if (userId != null) {
        // Original logic preserved as requested
        bucketListProvider.bucketList;
      }
      if (widget.showAddItemModal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showAddItemDialog();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showAddItemDialog() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor, // Use theme color for the sheet
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Adventure',
              // THEME FIX: Using theme.textTheme and theme.colorScheme
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              // THEME FIX: Relying on the global inputDecorationTheme
              decoration: const InputDecoration(
                labelText: "What do you want to do together?",
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              // THEME FIX: Relying on the global elevatedButtonTheme
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () async {
                if (_controller.text.isNotEmpty) {
                  final bucketListProvider =
                      Provider.of<BucketListProvider>(context, listen: false);
                  await bucketListProvider.addItem(_controller.text);
                  _controller.clear();
                  if (mounted) Navigator.pop(context);
                }
              },
              // THEME FIX: Relying on elevatedButtonTheme for text style
              child: const Text('Save'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showItemOptions(Map<String, dynamic> item, String userId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCurrentUser = item['createdBy'] == userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              item['completed'] ? Icons.undo : Icons.check,
              color: Colors.green, // Kept for status indication
            ),
            title: Text(
              item['completed'] ? 'Mark as not completed' : 'Mark as completed',
              // THEME FIX: Text color is inherited from the theme
            ),
            onTap: () {
              Provider.of<BucketListProvider>(context, listen: false)
                  .toggleItemCompletion(item['id'], !item['completed']);
              Navigator.pop(context);
            },
          ),
          if (isCurrentUser) ...[
            const Divider(height: 1),
            ListTile(
              // THEME FIX: Using color from theme
              leading: Icon(Icons.edit, color: colorScheme.onSurface),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditItemDialog(item, userId);
              },
            ),
            const Divider(height: 1),
            ListTile(
              // THEME FIX: Using color from theme
              leading: Icon(Icons.delete, color: colorScheme.error),
              title: Text('Delete', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Provider.of<BucketListProvider>(context, listen: false)
                    .deleteItem(item['id']);
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showEditItemDialog(Map<String, dynamic> item, String userId) {
    final theme = Theme.of(context);
    final editController = TextEditingController(text: item['title']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Adventure',
              // THEME FIX: Using theme.textTheme
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: editController,
              autofocus: true,
              // THEME FIX: Relying on the global inputDecorationTheme
              decoration: const InputDecoration(
                labelText: "Edit your adventure",
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              // THEME FIX: Relying on the global elevatedButtonTheme
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                if (editController.text.isNotEmpty) {
                  Provider.of<BucketListProvider>(context, listen: false)
                      .updateItem(item['id'], {'title': editController.text});
                  Navigator.pop(context);
                }
              },
              // THEME FIX: Original text "Save" is preserved
              child: const Text('Save'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bucketListProvider = Provider.of<BucketListProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.getUserId();

    if (userId == null || bucketListProvider.isLoading) {
      return Scaffold(
        body: Center(
          child: PulsingDotsIndicator(
            size: 80,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary,
            ],
          ),
        ),
      );
    }

    final processedItems = bucketListProvider.filteredBucketList;

    return Scaffold(
      // THEME FIX: AppBar is now styled by the global appBarTheme
      appBar: AppBar(
        // Original back button is preserved
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Shared Bucket List',
          // THEME FIX: The title text style comes from appBarTheme, but fontWeight is preserved
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showSortFilterOptions,
          ),
        ],
      ),
      // THEME FIX: FAB is styled by the global floatingActionButtonTheme
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        heroTag: 'addBucketItem',
        child: Icon(Icons.add, size: 24, color: colorScheme.onPrimary),

      ),
      // THEME FIX: Body background color comes from scaffoldBackgroundColor
      body: processedItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.landscape, size: 60, color: colorScheme.primary.withOpacity(0.18)),
                  const SizedBox(height: 16),
                  Text(
                    bucketListProvider.showCompleted
                        ? 'No completed adventures yet'
                        : 'Your adventure list is empty',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bucketListProvider.showCompleted
                        ? 'Start checking off items!'
                        : 'Add your first adventure',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: processedItems.length,
              itemBuilder: (context, index) {
                final item = processedItems[index];
                final isCurrentUser = item['createdBy'] == userId;
                final createdAt = item['createdAt'] as DateTime;
                final formattedDate = DateFormat('MMM d').format(createdAt);

                // Original Container structure preserved
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    // THEME FIX: Using color from theme's colorScheme
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundImage: isCurrentUser
                          ? userProvider.getProfileImageSync()
                          : userProvider.getPartnerProfileImageSync(),
                    ),
                    title: Text(
                      item['title'],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: item['completed'] ? TextDecoration.lineThrough : null,
                        color: item['completed']
                            ? colorScheme.onSurface.withOpacity(0.5)
                            : colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Added $formattedDate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        item['completed'] ? Icons.check_circle : Icons.circle_outlined,
                        color: item['completed'] ? Colors.green : colorScheme.primary,
                      ),
                      onPressed: () {
                        bucketListProvider.toggleItemCompletion(item['id'], !item['completed']);
                      },
                    ),
                    onTap: () => _showItemOptions(item, userId),
                  ),
                );
              },
            ),
    );
  }

  void _showSortFilterOptions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bucketListProvider = Provider.of<BucketListProvider>(context, listen: false);
    String tempSortBy = bucketListProvider.sortBy;
    String tempFilterBy = bucketListProvider.filterBy;
    bool tempShowCompleted = bucketListProvider.showCompleted;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sort & Filter',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await bucketListProvider.resetPreferences();
                        if (mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      // Original style override preserved
                      label: Text('Reset', style: theme.textTheme.labelMedium?.copyWith(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurface.withOpacity(0.6), // Secondary text color
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Sort by:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                RadioListTile(
                  title: const Text('Date added'),
                  value: 'date',
                  groupValue: tempSortBy,
                  activeColor: colorScheme.primary,
                  onChanged: (value) {
                    setModalState(() => tempSortBy = value.toString());
                  },
                ),
                RadioListTile(
                  title: const Text('Alphabetical'),
                  value: 'alpha',
                  groupValue: tempSortBy,
                  activeColor: colorScheme.primary,
                  onChanged: (value) {
                    setModalState(() => tempSortBy = value.toString());
                  },
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text('Filter by:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                RadioListTile(
                  title: const Text('All items'),
                  value: 'all',
                  groupValue: tempFilterBy,
                  activeColor: colorScheme.primary,
                  onChanged: (value) {
                    setModalState(() => tempFilterBy = value.toString());
                  },
                ),
                RadioListTile(
                  title: const Text('My items'),
                  value: 'mine',
                  groupValue: tempFilterBy,
                  activeColor: colorScheme.primary,
                  onChanged: (value) {
                    setModalState(() => tempFilterBy = value.toString());
                  },
                ),
                RadioListTile(
                  title: const Text("Partner's items"),
                  value: 'partner',
                  groupValue: tempFilterBy,
                  activeColor: colorScheme.primary,
                  onChanged: (value) {
                    setModalState(() => tempFilterBy = value.toString());
                  },
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Show completed items'),
                  value: tempShowCompleted,
                  activeThumbColor: colorScheme.primary,
                  onChanged: (value) {
                    setModalState(() => tempShowCompleted = value);
                  },
                ),
                const SizedBox(height: 16),
                SafeArea(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      bucketListProvider.setSortBy(tempSortBy);
                      bucketListProvider.setFilterBy(tempFilterBy);
                      bucketListProvider.setShowCompleted(tempShowCompleted);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}