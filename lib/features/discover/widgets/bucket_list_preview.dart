// lib/features/discover/widgets/bucket_list_preview.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/bucket_list_provider.dart';
import '../../../providers/user_provider.dart';
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import '../../bucket_list/screens/bucket_list_screen.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

// ✨ --- NEW IMPORTS --- ✨
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/secret_note/widgets/secret_note_view_dialog.dart';
// ✨ --- END NEW IMPORTS --- ✨

class BucketListPreview extends StatefulWidget {
  const BucketListPreview({super.key});

  @override
  State<BucketListPreview> createState() => _BucketListPreviewState();
}

class _BucketListPreviewState extends State<BucketListPreview>
    // ✨ --- ADD TickerProviderStateMixin --- ✨
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isFetched = false;
  bool _showAddField = false;

  // ✨ --- NEW ANIMATION CONTROLLER --- ✨
  late final AnimationController _giftAnimationController;

  @override
  void initState() { // ✨ --- ADD initState --- ✨
    super.initState();
    _giftAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFetched) {
      _isFetched = true;
      Future.microtask(() async {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final bucketListProvider = Provider.of<BucketListProvider>(context, listen: false);
        final rhmRepository = context.read<RhmRepository>();
        
        final userId = userProvider.getUserId();
        final coupleId = userProvider.coupleId;

        if (userId != null && coupleId != null && !bucketListProvider.isInitialized) {
          await bucketListProvider.initialize(
            coupleId: coupleId,
            userId: userId,
            rhmRepository: rhmRepository,
          );
        }
      });
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _giftAnimationController.dispose(); // ✨ --- DISPOSE --- ✨
    super.dispose();
  }

  // ✨ --- NEW HELPER METHOD --- ✨
  void _openSecretNote(BuildContext context, SecretNoteProvider provider) {
    final note = provider.activeSecretNote;
    if (note == null) return;

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SecretNoteViewDialog(note: note),
    );
    // Mark the note as read
    provider.markNoteAsRead(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    
    // ✨ --- WATCH ALL PROVIDERS --- ✨
    final bucketListProvider = Provider.of<BucketListProvider>(context);
    final secretNoteProvider = context.watch<SecretNoteProvider>();
    // ✨ --- END WATCH --- ✨
    
    final userId = userProvider.getUserId();

    if (userId == null || bucketListProvider.isLoading) {
      return Center(child: PulsingDotsIndicator(
          size: 80,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary,
          ],
        ),);
    }

    // ✨ --- NEW: CHECK FOR SECRET NOTE --- ✨
    final bool hasSecretNote =
        secretNoteProvider.activeNoteLocation == SecretNoteLocation.bucketList &&
        secretNoteProvider.activeSecretNote != null;
    // ✨ --- END NEW --- ✨

    final previewItems = bucketListProvider.bucketList.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            "Plan Our Adventures",
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✨ --- NEW: RENDER THE SECRET NOTE ITEM --- ✨
                if (hasSecretNote)
                  _buildSecretNoteItem(
                    context: context,
                    provider: secretNoteProvider,
                  ),
                // ✨ --- END NEW --- ✨

                if (previewItems.isNotEmpty)
                  for (int index = 0; index < previewItems.length; index++)
                    _buildBucketListItem(
                        item: previewItems[index],
                        userId: userId,
                        userProvider: userProvider,
                        bucketListProvider: bucketListProvider),

                if (previewItems.isEmpty && !hasSecretNote) // ✨ Modified
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "Add your first adventure!",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                if (_showAddField)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: "New adventure...",
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.send, size: 20),
                            color: theme.colorScheme.primary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final text = _controller.text.trim();
                              if (text.isNotEmpty) {
                                final coupleId = userProvider.coupleId;
                                if (!bucketListProvider.isInitialized && coupleId != null && userId != null) {
                                  final rhmRepo = context.read<RhmRepository>();
                                  bucketListProvider.initialize(
                                    coupleId: coupleId, 
                                    userId: userId, 
                                    rhmRepository: rhmRepo
                                  ).then((_) {
                                    bucketListProvider.addItem(text);
                                  });
                                } else {
                                  bucketListProvider.addItem(text);
                                }
                                _controller.clear();
                                setState(() => _showAddField = false);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() => _showAddField = !_showAddField);
                        if (!_showAddField) _controller.clear();
                      },
                      child: Text(_showAddField ? "Cancel" : "+ Add"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BucketListScreen(),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("View All"),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✨ --- NEW WIDGET: FAKE BUCKET LIST ITEM --- ✨
  Widget _buildSecretNoteItem({
    required BuildContext context,
    required SecretNoteProvider provider,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => _openSecretNote(context, provider),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pulsing Gift Icon
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.15).animate(_giftAnimationController),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.card_giftcard_rounded,
                  size: 16,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Text
            Expanded(
              child: Text(
                "A secret note for you...",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
  // ✨ --- END NEW WIDGET --- ✨

  Widget _buildBucketListItem({
    required Map<String, dynamic> item,
    required String? userId,
    required UserProvider userProvider,
    required BucketListProvider bucketListProvider,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChecked = item['completed'] ?? false;
    final isCurrentUser = item['createdBy'] == userId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: isCurrentUser
                ? userProvider.getProfileImageSync()
                : userProvider.getPartnerProfileImageSync(),
            backgroundColor: colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item['title'],
              style: theme.textTheme.bodyLarge?.copyWith(
                decoration: isChecked ? TextDecoration.lineThrough : null,
                color: isChecked
                    ? colorScheme.onSurface.withOpacity(0.5)
                    : colorScheme.onSurface,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              bucketListProvider.toggleItemCompletion(item['id'], !isChecked);
            },
            child: Icon(
              isChecked ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: isChecked ? Colors.green : colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}