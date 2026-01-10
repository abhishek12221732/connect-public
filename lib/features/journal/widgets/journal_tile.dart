import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/journal_provider.dart';
import 'package:feelings/features/encryption/widgets/encryption_status_bubble.dart';
import '../../../providers/user_provider.dart';
import 'package:feelings/services/encryption_service.dart'; // Import EncryptionService

class JournalTile extends StatefulWidget {
  final String journalId;
  final String title;
  final String? content; // Restore content
  final String? ciphertext; 
  final String? nonce; 
  final String? mac;
  final dynamic timestamp;
  final List<dynamic>? segments;
  final int? encryptionVersion; 
  final VoidCallback onTap;
  final bool isShared;

  const JournalTile({
    super.key,
    required this.journalId,
    required this.title,
    this.content, // Restore content
    this.ciphertext,
    required this.timestamp,
    this.segments,
    this.encryptionVersion,
    required this.onTap,
    required this.isShared,
    this.nonce,
    this.mac,
  });

  @override
  State<JournalTile> createState() => _JournalTileState();
}

class _JournalTileState extends State<JournalTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  
  String _displayContent = "";
  bool _isDecrypting = true;

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
    
    _initAndDecrypt();
  }
  
  @override
  void didUpdateWidget(JournalTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content ||
        widget.ciphertext != oldWidget.ciphertext || 
        widget.segments != oldWidget.segments ||
        widget.encryptionVersion != oldWidget.encryptionVersion ||
        widget.nonce != oldWidget.nonce ||
        widget.mac != oldWidget.mac) {
      _initAndDecrypt();
    }
  }

  Future<void> _initAndDecrypt() async {
     if (!mounted) return;
     
     setState(() {
       _isDecrypting = true;
       _displayContent = "⏳ Waiting for key..."; // Set initial state for decryption
     });

     // 1. Initial simple text (if not encrypted)
     String tempContent = "";
     final safeSegments = (widget.segments is List) ? widget.segments as List : [];
     
     // If there's a ciphertext, it means the content is encrypted.
     // We'll try to decrypt it. If not, we check for segments or fallback.
     if (widget.encryptionVersion == null || widget.encryptionVersion == 0) {
       if (widget.content != null && widget.content!.trim().isNotEmpty) {
          tempContent = widget.content!;
       } else if (widget.ciphertext != null && widget.ciphertext!.trim().isNotEmpty) {
         tempContent = widget.ciphertext!; 
       } else if (safeSegments.isNotEmpty) {
         tempContent = safeSegments.map((seg) => seg['text'] ?? seg['content'] ?? "").join(" ");
       }
     }
     
     // 2. Perform Decryption if needed
     if (widget.encryptionVersion == 1) {
       // A. Main Content Decryption (Personal Journal)
       if (widget.ciphertext != null && widget.nonce != null && widget.mac != null) {
          try {
             final decrypted = await EncryptionService.instance.decryptText(
                widget.ciphertext!, widget.nonce!, widget.mac!);
             if (decrypted != null) tempContent = decrypted;
          } catch (e) {
             debugPrint("⚠️ JournalTile Decryption Failed: $e");
             tempContent = "🔒 Decryption Failed";
          }
       } 
       // B. Segments Decryption (Shared Journal)
       else if (safeSegments.isNotEmpty) {
          List<String> decryptedSegments = [];
          for (var seg in safeSegments) {
             if (seg['encryptionVersion'] == 1 && 
                 seg['ciphertext'] != null && 
                 seg['nonce'] != null && 
                 seg['mac'] != null) {
                try {
                   final decrypted = await EncryptionService.instance.decryptText(
                      seg['ciphertext'], seg['nonce'], seg['mac']);
                   decryptedSegments.add(decrypted ?? "Error");
                } catch (e) {
                   decryptedSegments.add("🔒 Error");
                }
             } else {
                decryptedSegments.add(seg['text'] ?? seg['content'] ?? "");
             }
          }
          if (decryptedSegments.isNotEmpty) {
            tempContent = decryptedSegments.join(" ");
          }
       } else {
         // If encryptionVersion is 1 but no ciphertext/segments, it's likely just a placeholder
         tempContent = "🔒 Encrypted Journal";
       }
     }
     
     if (mounted) {
       setState(() {
         _displayContent = tempContent;
         _isDecrypting = false;
       });
     }
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
    
    // ✨ Handle decryption state
    if (_isDecrypting && widget.encryptionVersion == 1) {
       _displayContent = "⏳ Waiting for key...";
    }
    
    // Only use _displayContent here
    final safeSegments = (widget.segments is List) ? widget.segments as List : [];
    
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
                      
                      if (_displayContent.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        if (_displayContent == "⏳ Waiting for key...")
                          const EncryptionStatusBubble(status: 'waiting')
                        else if (_displayContent == "🔒 Encrypted Journal" || _displayContent == "🔒 Encrypted content" || _displayContent == "🔒 Decryption Failed")
                          const EncryptionStatusBubble(status: 'locked')
                        else
                          Text(
                            _displayContent,
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

                          // ✨ Lock Icon
                          if (widget.encryptionVersion == 1) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.lock, size: 12, color: colorScheme.primary.withOpacity(0.7)),
                          ],
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