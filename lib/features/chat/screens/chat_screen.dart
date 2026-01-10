// lib/features/chat/screens/chat_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:feelings/features/connectCouple/screens/connect_couple_screen.dart';
import 'package:feelings/features/discover/widgets/connect_with_partner_card.dart';
import 'package:feelings/providers/chat_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/services/notification_services.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/message_model.dart';
import '../widgets/chat_empty_state.dart';
import '../widgets/enhanced_chat_input.dart';
import '../widgets/enhanced_message_bubble.dart';
import '../widgets/enhanced_search_bar.dart';

import 'package:feelings/providers/couple_provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';
import 'package:feelings/providers/theme_provider.dart';
import 'package:feelings/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✨ --- NEW IMPORTS --- ✨
import 'package:feelings/providers/secret_note_provider.dart';
import 'package:feelings/features/secret_note/widgets/secret_note_view_dialog.dart';
// ✨ --- END NEW IMPORTS --- ✨

class ChatScreen extends StatefulWidget {
  final String? questionToAsk;
  final String? partnerName;

  const ChatScreen({
    super.key,
    this.questionToAsk,
    this.partnerName,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late final ScrollController _scrollController;

  Timer? _typingTimer;

  bool _isSearching = false;
  String _searchQuery = '';
  final bool _isLoading = false;

  bool _showScrollToBottom = false;
  bool _userHasScrolled = false;

  late UserProvider _userProvider;
  late ChatProvider _chatProvider;

  late final AnimationController _fadeAnimationController;
  late final Animation<double> _fadeAnimation;
  
  // ✨ --- NEW ANIMATION CONTROLLER --- ✨
  late final AnimationController _giftAnimationController;

  // ✨ DEBUG TIMER
  Timer? _debugTimer;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()..addListener(_onScroll);

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeIn),
    );

    // ✨ --- NEW ANIMATION --- ✨
    _giftAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    // ✨ --- END NEW ANIMATION --- ✨

    SystemChannels.lifecycle.setMessageHandler((msg) async {
      if (msg == AppLifecycleState.paused.toString()) {
        _resetTypingStatus();
      }
      return null;
    });
    // ✨ Start animation immediately
    _fadeAnimationController.forward();
    
    // ✨ Handle initial question if present
    if (widget.questionToAsk != null && widget.questionToAsk!.isNotEmpty) {
      _messageController.text = widget.questionToAsk!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Obtain providers without listening endlessly (listen: false is standard for init, 
    // but in didChangeDependencies we often want to react. 
    // Actually, we want to REACT to UserProvider changes if it goes from null -> Loaded.
    
    // Using simple Provider.of with listen: true (default) causes rebuilds, which is fine.
    // But for "triggering an action" like listenToMessages, we should be careful.
    
    final userProvider = Provider.of<UserProvider>(context); // Listen to updates
    final chatProvider = Provider.of<ChatProvider>(context, listen: false); // Don't rebuild chat screen just because chat provider notifies
    
    _userProvider = userProvider;
    _chatProvider = chatProvider; // Update references

    final userId = userProvider.getUserId();
    final partnerId = userProvider.getPartnerId();

    if (userId != null && partnerId != null) {
      // ChatProvider handles deduplication now, so this is safe to call repeatedly.
      chatProvider.listenToMessages(userId, partnerId);
      chatProvider.listenToTypingStatus(userId, partnerId);
      
      // ✨ FIX: Move addListener to initState or check before adding.
      // Since didChangeDependencies can run multiple times, adding listener here causes duplicates.
      // We already added it in initState (guarded by deprecated check, but let's clean that up).
      // Ideally, we don't need manual listeners if we use Consumer.
      // But _onChatProviderChanged handles scrolling.
      // We'll manage it in initState/dispose.
    }
  }

  // ... (rest of initState logic, _initializeChat, _resetTypingStatus, _onChatProviderChanged, _getChatId, _sendMessage, _handleReply, _cancelReply, _startEdit, _commitEdit, _onScroll, _scrollToBottom, _onTextChanged, _showDeleteDialog are all unchanged) ...
  
  void _initializeChat() {
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final userId = _userProvider.getUserId();
    final partnerId = _userProvider.getPartnerId();

    // ⚠️ Deprecated initialization here. Logic moved to didChangeDependencies
    // keeping listener setup for now but guarded.
    
    // Actually, _onChatProviderChanged logic:
    // We should ensure we only add the listener ONCE. 
    // Ideally, use Consumer<ChatProvider> in build() instead of manual listeners.
    // But to respect existing code structure:
    _chatProvider.addListener(_onChatProviderChanged);

    if (userId != null && partnerId != null) {
      // Initial check (legacy support if needed, but didChangeDependencies handles it)
    }

    if (widget.questionToAsk != null && widget.questionToAsk!.isNotEmpty) {
      _messageController.text = widget.questionToAsk!;
    }

    _fadeAnimationController.forward();
    
    // ✨ DEBUG: Heartbeat to force frame updates in Release mode
    _debugTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  void _resetTypingStatus() {
    final userId = _userProvider.getUserId();
    final partnerId = _userProvider.getPartnerId();
    if (userId != null && partnerId != null) {
      _chatProvider.updateTypingStatus(userId, partnerId, false);
    }
  }

  void _onChatProviderChanged() {
    if (!mounted) return;
    
    // ✨ FIX: Force rebuild in release mode.
    // Sometimes Consumer/Riverpod can be optimized away or blocked.
    // This ensures the UI paints the new state.
    setState(() {});

    if (_chatProvider.messages.isNotEmpty && !_userHasScrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: true);
      });
    }
  }

  String _getChatId(String userId, String partnerId) {
    final ids = [userId, partnerId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _sendMessage(String messageContent, File? imageFile) async {
    final userId = _userProvider.getUserId();
    final partnerId = _userProvider.getPartnerId();

    if (_chatProvider.editingMessage != null) return;

    if (userId != null &&
        partnerId != null &&
        (messageContent.isNotEmpty || imageFile != null)) {
      final userFullName = _userProvider.userData?['name'] as String?;
      final senderName = userFullName?.split(' ').first ?? 'You';

      final partnerFullName = _userProvider.partnerData?['name'] as String?;
      final partnerName = partnerFullName?.split(' ').first ?? 'Partner';

      _messageController.clear();
      _scrollToBottom(animated: true);

      try {
        await _chatProvider.sendMessage(
          userId,
          partnerId,
          messageContent,
          senderName: senderName,
          partnerName: partnerName,
          imageFile: imageFile, 
          isEncryptionEnabled: _userProvider.isEncryptionEnforced, // ✨ Pass Preference
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } finally {
        if (_chatProvider.replyingToMessage != null) {
          _cancelReply();
        }
      }
    }
  }

  void _handleReply(MessageModel message) {
    debugPrint("ChatScreen: Handling reply to ${message.id}");
    Provider.of<ChatProvider>(context, listen: false).setReplyingTo(message);
    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    debugPrint("ChatScreen: Canceling reply");
    // ✨ FIX: Use new provider lookup to avoid stale references
    Provider.of<ChatProvider>(context, listen: false).cancelReply();
    // ✨ FIX: Don't unfocus! User might want to keep typing a normal message.
    // _messageFocusNode.unfocus(); 
  }

  void _startEdit(MessageModel message) {
    final userId = _userProvider.getUserId();
    if (userId == null) return;
    if (_chatProvider.canEditMessage(message, userId)) {
      _chatProvider.startEditing(message, userId);
      _messageController.text = message.content;
      _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length));
      _messageFocusNode.requestFocus();
      _scrollToBottom(animated: true);
    }
  }

  Future<void> _commitEdit(String text) async {
    final userId = _userProvider.getUserId();
    final partnerId = _userProvider.getPartnerId();
    if (userId == null || partnerId == null) return;
    await _chatProvider.commitEdit(userId, partnerId, text);
    _messageController.clear();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    if (position.pixels > 100) _userHasScrolled = true;

    final showButton = position.pixels > 200;
    if (showButton != _showScrollToBottom) {
      setState(() => _showScrollToBottom = showButton);
    }

    if (position.pixels >= position.maxScrollExtent - 200 &&
        !_chatProvider.isLoadingMessages &&
        _chatProvider.hasMoreMessages) {
      final userId = _userProvider.getUserId();
      final partnerId = _userProvider.getPartnerId();
      if (userId != null && partnerId != null) {
        _chatProvider.fetchMoreMessages(userId, partnerId);
      }
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _userHasScrolled = false;
      if (_showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      }
    });
  }

  void _onTextChanged(String text) {
    final userId = _userProvider.getUserId();
    final partnerId = _userProvider.getPartnerId();
    if (userId != null && partnerId != null) {
      if (text.isNotEmpty) {
        _typingTimer?.cancel();
        _chatProvider.updateTypingStatus(userId, partnerId, true);
        _typingTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted)
            _chatProvider.updateTypingStatus(userId, partnerId, false);
        });
      } else {
        _typingTimer?.cancel();
        _chatProvider.updateTypingStatus(userId, partnerId, false);
      }
    }
  }

  void _showDeleteDialog(MessageModel message) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('Delete Message'),
          ],
        ),
        content: const Text('Are you sure? This also deletes media and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = _userProvider.getUserId();
              final partnerId = _userProvider.getPartnerId();
              if (userId != null && partnerId != null) {
                await _chatProvider.deleteMessage(
                    _getChatId(userId, partnerId), message);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  void _showMessageActions(MessageModel message, bool isMe) {
    // ... (unchanged) ...
    final theme = Theme.of(context);
    final userId = _userProvider.getUserId();
    final canEdit =
        userId != null && _chatProvider.canEditMessage(message, userId);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                _handleReply(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            if (isMe && message.messageType != 'voice')
              ListTile(
                leading: Icon(Icons.edit,
                    color: canEdit ? null : theme.disabledColor),
                title: Text('Edit',
                    style:
                        TextStyle(color: canEdit ? null : theme.disabledColor)),
                onTap: canEdit
                    ? () {
                        Navigator.pop(ctx);
                        _startEdit(message);
                      }
                    : null,
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteDialog(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    // ... (unchanged) ...
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (DateUtils.isSameDay(date, today)) {
      label = 'Today';
    } else if (DateUtils.isSameDay(date, yesterday)) {
      label = 'Yesterday';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      label = '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedMessages(
      BuildContext context, List<MessageModel> messages) {
    // ... (unchanged) ...
    if (messages.isEmpty) return [];

    final theme = Theme.of(context);
    final groupedWidgets = <Widget>[];
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Group by date
    final Map<DateTime, List<MessageModel>> groupedByDate = {};
    for (final message in messages) {
      final date = DateUtils.dateOnly(message.timestamp.toLocal());
      groupedByDate.putIfAbsent(date, () => []).add(message);
    }

    // Sort by date descending because ListView is reverse: true
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final date in sortedDates) {
      final dayMessages = groupedByDate[date]!;
      for (int i = 0; i < dayMessages.length; i++) {
        final message = dayMessages[i];

        try {
          final userId = userProvider.getUserId();
          final partnerId = userProvider.getPartnerId();
          final isMe = message.senderId == userId;
          final isReplyingToOwnMessage = message.repliedToSenderId == userId;

          final slidableBubble = Slidable(
            key: Key(message.id),
            startActionPane: ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.25,
              dismissible: DismissiblePane(
                dismissThreshold: 0.25,
                closeOnCancel: true,
                onDismissed: () {}, // required by API
                confirmDismiss: () async {
                  _handleReply(message);
                  return false; // veto so it closes back to original position
                },
              ),
              children: [
                SlidableAction(
                  onPressed: (context) => _handleReply(message),
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.primary,
                  icon: Icons.reply,
                  label: 'Reply',
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            endActionPane: (isMe && message.messageType != 'voice')
                ? ActionPane(
                    motion: const BehindMotion(),
                    extentRatio: 0.25,
                    children: [
                      Builder(
                        builder: (context) {
                          final canEdit = userId != null &&
                              _chatProvider.canEditMessage(message, userId);
                          return SlidableAction(
                            onPressed: canEdit
                                ? (context) {
                                    Slidable.of(context)?.close();
                                    Future.microtask(() => _startEdit(message));
                                  }
                                : null,
                            backgroundColor: theme.colorScheme.surface,
                            foregroundColor: canEdit
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.4),
                            icon: Icons.edit,
                            label: 'Edit',
                            borderRadius: BorderRadius.circular(12),
                          );
                        },
                      ),
                    ],
                  )
                : null,
            child: EnhancedMessageBubble(
              message: message,
              isMe: isMe,
              isReplyingToOwnMessage: isReplyingToOwnMessage,
              onLongPress: () => _showMessageActions(message, isMe),
              highlightQuery: _searchQuery,
              showDateHeader: false,
            ),
          );

          if (!isMe &&
              message.status != 'seen' &&
              userId != null &&
              partnerId != null) {
            groupedWidgets.add(
              VisibilityDetector(
                key: Key(message.id),
                onVisibilityChanged: (visibilityInfo) {
                  if (visibilityInfo.visibleFraction > 0.5) {
                    _chatProvider.queueMessageAsSeen(
                        userId, partnerId, message.id);
                  }
                },
                child: slidableBubble,
              ),
            );
          } else {
            groupedWidgets.add(slidableBubble);
          }
        } catch (e, stack) {
          debugPrint("❌ Error building message bubble for ${message.id}: $e");
          groupedWidgets.add(
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Error loading message: $e", 
                style: TextStyle(color: theme.colorScheme.error, fontSize: 10)
              ),
            )
          );
          continue; // Skip this bad message
        }

        if (i == dayMessages.length - 1) {
          groupedWidgets.add(_buildDateHeader(context, date));
        }
      }
    }

    return groupedWidgets;
  }

  @override
  void dispose() {
    _debugTimer?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fadeAnimationController.dispose();
    _giftAnimationController.dispose(); // ✨ --- DISPOSE --- ✨
    if (mounted) {
      _chatProvider.removeListener(_onChatProviderChanged);
      _resetTypingStatus();
    }
    super.dispose();
  }

  String _formatThemeName(AppThemeType theme) {
    // ... (unchanged) ...
    if (theme.name.isEmpty) return '';
    final spacedName = theme.name.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (m) => ' ${m.group(0)}',
    );
    return spacedName[0].toUpperCase() + spacedName.substring(1);
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        // Wrapping in Consumer allows the modal to rebuild immediately upon theme change
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final theme = Theme.of(context);

            return Container(
              // Force background color update
              color: theme.scaffoldBackgroundColor, 
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Select Theme',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        // Force text color update
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: AppThemeType.values.map((themeType) {
                        final isSelected = themeProvider.currentThemeType == themeType;

                        return RadioListTile<AppThemeType>(
                          title: Text(
                            _formatThemeName(themeType),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          activeColor: theme.colorScheme.primary,
                          value: themeType,
                          groupValue: themeProvider.currentThemeType,
                          onChanged: (newTheme) {
                            if (newTheme != null) {
                              // This updates the global theme state
                              themeProvider.setTheme(newTheme);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // ... (unchanged) ...
    final userProvider = Provider.of<UserProvider>(context);
    final partnerData = userProvider.partnerData;

    // debugPrint("🏗️ [ChatScreen] build() called. User: ${userProvider.getUserId()}");
    // debugPrint("🏗️ [ChatScreen] build() called. User: ${userProvider.getUserId()}");
    // Provider.of<ChatProvider>(context, listen: false).addSilentLog("🏗️ Build");

    // ✨ FIX: Removing VisibilityDetector to prevent potential release-mode paint blocking
    // NotificationService.isChatScreenActive tracking will be temporarily disabled or moved.
    // We prioritize SEEING messages first.
    NotificationService.isChatScreenActive = true; 
    return _buildScaffold(context, partnerData, userProvider);
  }

  Widget _buildScaffold(
    BuildContext context,
    Map<String, dynamic>? partnerData,
    UserProvider userProvider,
  ) {
    final theme = Theme.of(context);
    final userId = userProvider.getUserId();
    final partnerName = widget.partnerName ??
        (partnerData != null
            ? (partnerData['name'] as String?)?.split(' ').first ?? 'Partner'
            : 'Partner');
        
    // ✨ --- WATCH THE PROVIDER --- ✨
    final secretNoteProvider = context.watch<SecretNoteProvider>();
    final bool hasSecretNote = 
        secretNoteProvider.activeNoteLocation == SecretNoteLocation.chatAppBar &&
        secretNoteProvider.activeSecretNote != null;

    if (partnerData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(
          child: ConnectWithPartnerCard(
            title: 'Connect with your partner to start chatting!',
            message: 'Once connected, you can send messages and chat here.',
            icon: Icons.chat_bubble_outline,
            buttonLabel: 'Connect Now',
            onButtonPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ConnectCoupleScreen()),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: userProvider.getPartnerProfileImageSync(),
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerData['name'] ?? 'Partner',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, _) {
                      // chatProvider.addSilentLog("🎨 Consumer Rebuild! Msgs: ${chatProvider.messages.length}");
                      return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (chatProvider.isPartnerTyping)
                          Text('Typing...', style: theme.textTheme.bodySmall),


                      ],
                    );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // ✨ DEBUG BUTTON

          // ✨ --- NEW: SECRET NOTE ICON --- ✨
          if (hasSecretNote)
            IconButton(
              tooltip: "A secret note!",
              onPressed: () => _openSecretNote(context, secretNoteProvider),
              icon: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.2).animate(_giftAnimationController),
                child: Icon(
                  Icons.mail_lock_rounded, 
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
            ),
          // ✨ --- END NEW --- ✨
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'search') {
                setState(() {
                  _isSearching = true;
                  _searchQuery = '';
                  _chatProvider.clearSearch();
                });
              } else if (value == 'theme') {
                _showThemeSelector();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Search Chat',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.palette_outlined,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Change Theme',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              firstChild: EnhancedSearchBar(
                searchQuery: _searchQuery,
                onCancel: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _chatProvider.clearSearch();
                  });
                },
                onSearchChanged: (query) {
                  setState(() => _searchQuery = query);
                  _chatProvider.searchMessages(query);
                },
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _isSearching
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
            ),
            Expanded(
              child: Stack(
                children: [
                  // ✨ ROBUST REBUILD STRATEGY: ValueListenableBuilder
                  Builder(
                    builder: (context) {
                       // We need the provider instance, but we will listen via ValueNotifier
                       final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                       
                       return ValueListenableBuilder<List<MessageModel>>(
                         valueListenable: chatProvider.messagesNotifier,
                         builder: (context, messages, _) {
                            // chatProvider.addSilentLog("🚀 ValueListenable Rebuild! Count: ${messages.length}");
                            
                            // Handle Loading/Empty States
                            if (chatProvider.isLoadingMessages && messages.isEmpty) {
                               return Center(
                                  child: PulsingDotsIndicator(
                                    size: 80,
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.primary,
                                    ],
                                  ),
                               );
                            }
                            
                            if (messages.isEmpty) {
                              if (chatProvider.isSearching) {
                                // ... Search Empty State (Simplified) ...
                                return Center(child: Text("No matches"));
                              }
                              return ChatEmptyState(
                                partnerName: widget.partnerName,
                                onStartChat: () {},
                              );
                            }
                            
                            final messageWidgets = _buildGroupedMessages(context, messages);
                            
                            return ListView.builder(
                               key: ValueKey("List_${messages.length}"),
                               controller: _scrollController,
                               reverse: true,
                               padding: const EdgeInsets.symmetric(vertical: 16),
                               itemCount: messageWidgets.length + (chatProvider.isLoadingMessages ? 1 : 0),
                               itemBuilder: (context, index) {
                                  if (index == messageWidgets.length) {
                                     return const Center(child: CircularProgressIndicator());
                                  }
                                  // if (index == 0) chatProvider.addSilentLog("🖼️ VLB Item 0");
                                  return messageWidgets[index];
                               },
                            );
                         },
                       );
                    }
                  ),
                  Positioned(
                    bottom: 16.0,
                    right: 16.0,
                    child: AnimatedOpacity(
                      opacity: _showScrollToBottom ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !_showScrollToBottom,
                        child: FloatingActionButton.small(
                          heroTag: 'scrollToBottom',
                          onPressed: () => _scrollToBottom(animated: true),
                          child: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ✨ OPTIMIZATION: Check active status once or via provider property instead of FutureBuilder in build
            // For now, we'll assume active unless specifically inactive.
            // Ideally CoupleProvider should expose this as a stream or value.
            // Replacing FutureBuilder with a direct Consumer call for now to stop the rebuild cycling
            // and simply executing the check in the background.
            
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                 debugPrint("ChatScreen: Consumer rebuild. ReplyingTo: ${chatProvider.replyingToMessage?.id}"); 
                 return EnhancedChatInput(
                      messageController: _messageController,
                      focusNode: _messageFocusNode, // ✨ Pass it here
                      onSend: _sendMessage,
                      currentUserId: userId!,
                      partnerName: partnerName,
                      onChanged: _onTextChanged,
                      onSendVoice: (File audioFile) {
                        final partnerId = _userProvider.getPartnerId();
                        
                        if (userId == null || partnerId == null) {
                          debugPrint("Error sending voice: User or Partner ID is null.");
                          return;
                        }

                        _chatProvider.sendVoiceMessage(
                          userId,
                          partnerId,
                          audioFile,
                          senderName: _userProvider.userData?['name'] as String? ?? 'You',
                          partnerName: partnerName,
                        );
                      },
                      isLoading: _isLoading,
                      replyingToMessage: chatProvider.replyingToMessage,
                      onCancelReply: _cancelReply,
                      editingMessage: chatProvider.editingMessage,
                      onCancelEdit: () {
                        _chatProvider.cancelEditing();
                        _messageController.clear();
                      },
                      onConfirmEdit: _commitEdit,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}