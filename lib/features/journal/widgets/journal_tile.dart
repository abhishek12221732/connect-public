import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/journal_provider.dart';
import '../../../providers/user_provider.dart';

class JournalTile extends StatefulWidget {
  final String journalId;
  final String title;
  final String? content;
  final dynamic timestamp;
  final List<dynamic>? segments;
  final VoidCallback onTap;
  final bool isShared;

  const JournalTile({
    super.key,
    required this.journalId,
    required this.title,
    this.content,
    required this.timestamp,
    this.segments,
    required this.onTap,
    required this.isShared,
  });

  @override
  State<JournalTile> createState() => _JournalTileState();
}

class _JournalTileState extends State<JournalTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _timeAgo {
    try {
      if (widget.timestamp == null) return '';
      final date = (widget.timestamp is DateTime)
          ? widget.timestamp
          : widget.timestamp.toDate();
      final difference = DateTime.now().difference(date);

      if (difference.inDays > 0) return '${difference.inDays}d ago';
      if (difference.inHours > 0) return '${difference.inHours}h ago';
      if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }

  void _confirmDelete(BuildContext context) {
    final theme = Theme.of(context);
    final isShared = widget.isShared;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isShared ? "Delete Shared Journal" : "Delete Journal"),
          content: Text(isShared
              ? "Are you sure you want to delete this shared journal? This will permanently delete both your and your partner's contributions."
              : "Are you sure you want to delete this journal entry? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final journalProvider =
                    Provider.of<JournalProvider>(context, listen: false);
                final userProvider =
                    Provider.of<UserProvider>(context, listen: false);

                if (isShared) {
                  final coupleId = userProvider.coupleId;
                  if (coupleId != null) {
                    journalProvider.deleteSharedJournalEntry(
                        coupleId, widget.journalId);
                  }
                } else {
                  final userId = userProvider.userData?['userId'];
                  if (userId != null) {
                    journalProvider.deletePersonalJournal(userId, widget.journalId);
                  }
                }

                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final safeSegments =
        (widget.segments is List) ? widget.segments as List : <dynamic>[];
    final displayContent =
        (widget.content != null && widget.content!.trim().isNotEmpty)
            ? widget.content!
            : (safeSegments.isNotEmpty
                ? safeSegments.map((seg) => seg['text']).join(" ")
                : "");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              elevation: _isPressed ? 1 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                // ✨ --- NEW: Conditional border for shared journals --- ✨
                side: widget.isShared
                    ? BorderSide(color: colorScheme.primary.withOpacity(0.5), width: 1.5)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                splashColor: colorScheme.primary.withOpacity(0.1),
                highlightColor: colorScheme.primary.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                widget.title,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.isShared)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Icon(Icons.people_alt_outlined, size: 16, color: colorScheme.primary),
                            ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _confirmDelete(context);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: colorScheme.error),
                                    const SizedBox(width: 8),
                                    const Text("Delete"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      if (displayContent.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          displayContent,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Icon(Icons.access_time_filled, size: 14, color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            _timeAgo,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (safeSegments.isNotEmpty && widget.isShared)
                             Text(
                                '${safeSegments.length} ${safeSegments.length == 1 ? 'entry' : 'entries'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}