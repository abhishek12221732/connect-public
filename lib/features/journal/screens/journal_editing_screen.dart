// lib/features/journal/screens/journal_editing_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/user_provider.dart';
import '../widgets/shared_journal_quill_editor.dart';

class JournalEditingScreen extends StatefulWidget {
  final Map<String, dynamic>? entryData;
  final bool isShared;

  const JournalEditingScreen({
    super.key,
    this.entryData,
    required this.isShared,
  });

  @override
  _JournalEditingScreenState createState() => _JournalEditingScreenState();
}

class _JournalEditingScreenState extends State<JournalEditingScreen>
    with SingleTickerProviderStateMixin {

      Map<String, dynamic>? _currentEntryData;
      
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  late String _initialContent;
  int _wordCount = 0;

  bool _isSaving = false;
  late String _initialTitle;
  late String _currentUserId;
  late String _partnerId;
  List<Map<String, dynamic>> _sharedSegments = [];
  List<Map<String, dynamic>> _initialSharedSegments = [];
  
  Timer? _autoSaveTimer;
  bool _justSaved = false;
  Timer? _justSavedTimer;

  late AnimationController _syncAnimationController;


  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _currentUserId = userProvider.getUserId() ?? 'unknown';
    _partnerId = userProvider.partnerData?['userId'] ?? 'partner';
    
    // ✨ [MODIFY] Initialize our new state variable
    _currentEntryData = widget.entryData;
    
    // ✨ [MODIFY] Use _currentEntryData from now on, not widget.entryData
    _initialTitle = _currentEntryData?['title'] ?? '';
    _titleController.text = _initialTitle;

    if (widget.isShared) {
      // ✨ [MODIFY] Use _currentEntryData
      if (_currentEntryData?['segments'] != null) {
        final segs = _currentEntryData!['segments'] as List<dynamic>;
        _sharedSegments = segs.map((s) => Map<String, dynamic>.from(s)).toList();
        _initialSharedSegments = List.from(_sharedSegments);
      }
    } else {
      // ✨ [MODIFY] Use _currentEntryData
      _initialContent = _currentEntryData?['content'] ?? '';
      _contentController.text = _initialContent;
      _updateWordCount();
      _contentController.addListener(_updateWordCount);
    }
    
    _startAutoSaveTimer();
    
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _autoSaveTimer?.cancel(); 
    _justSavedTimer?.cancel(); 
    _syncAnimationController.dispose();
    super.dispose();
  }
  
  void _startAutoSaveTimer() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isSaving || !_hasUnsavedChanges || !mounted) {
        return;
      }
      _saveEntry();
    });
  }


  bool get _hasUnsavedChanges {
    if (widget.isShared) {
      return _titleController.text.trim() != _initialTitle || !_listEquals(_sharedSegments, _initialSharedSegments);
    } else {
      return _titleController.text.trim() != _initialTitle || _contentController.text.trim() != _initialContent;
    }
  }

  bool _listEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['text'] != b[i]['text'] || a[i]['userId'] != b[i]['userId']) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges && !_isSaving) {
      _saveEntry(isExiting: true);
    }
    return true;
  }

  void _updateWordCount() {
    setState(() {
      _wordCount = _contentController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    });
  }

  // ✨ [MODIFIED] This function now handles minimum duration and uses a success flag
  Future<void> _saveEntry({bool isExiting = false}) async {
    if (_isSaving) return;

    // ✨ Record start time
    final saveStartTime = DateTime.now();

    if (!isExiting) {
      setState(() {
        _isSaving = true;
        _justSaved = false;
      });
    } else {
      _isSaving = true;
    }

    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    
    bool saveSucceeded = false; // ✨ Use a flag to track success

    try {
      if (widget.isShared) {
        final coupleId = userProvider.coupleId;
        if (coupleId == null) throw Exception("Could not save. No couple found.");
        Map<String, dynamic> entryData = {
          'title': _titleController.text.trim(),
          // ✨ [MODIFY] Use _currentEntryData to get createdBy if it exists
          'createdBy': _currentEntryData?['createdBy'] ?? _currentUserId,
          'segments': _sharedSegments,
          'timestamp': DateTime.now(),
        };

        // ✨ [MODIFY] This is the CORE FIX. Check our state variable.
        if (_currentEntryData == null) {
          // It's a new entry. Call 'add' and get the new docRef.
          final docRef = await journalProvider.addSharedJournalEntry(coupleId, entryData);
          
          // ✨ [MODIFY] CRITICAL: Update our state variable with the new data and ID.
          setState(() {
            _currentEntryData = entryData;
            _currentEntryData!['id'] = docRef.id;
          });

        } else {
          // It's an existing entry. Call 'update'.
          await journalProvider.updateSharedJournalEntry(
            coupleId, 
            _currentUserId, 
            _currentEntryData!['id'], // ✨ [MODIFY] Use state variable
            entryData
          );
        }
      } else {
        // ... (Personal journal logic, also updated) ...
        final userId = userProvider.getUserId();
        if (userId == null) throw Exception("Could not save. User not found.");
        Map<String, dynamic> entryData = {
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'timestamp': DateTime.now(),
        };

        // ✨ [MODIFY] Apply same fix to personal journals
        if (_currentEntryData == null) {
          final docRef = await journalProvider.addPersonalJournalEntry(userId, entryData);
          // ✨ [MODIFY] CRITICAL: Update our state variable
          setState(() {
            _currentEntryData = entryData;
            _currentEntryData!['id'] = docRef.id;
          });
        } else {
          await journalProvider.updatePersonalJournalEntry(
            userId, 
            _currentEntryData!['id'], // ✨ [MODIFY] Use state variable
            entryData
          );
        }
      }

      // --- On Success ---
      _initialTitle = _titleController.text.trim();
      if (widget.isShared) {
        _initialSharedSegments = List.from(_sharedSegments.map((s) => Map<String, dynamic>.from(s)));
      } else {
        _initialContent = _contentController.text.trim();
      }
      
      saveSucceeded = true;
      
    } catch (e) {
      // ... (catch block unchanged) ...
    } finally {
      // ... (finally block unchanged) ...
    }
  }
  
  // _handleDelete and _showDeleteConfirmation are unchanged
  Future<void> _handleDelete() async {
      setState(() => _isSaving = true);
      final theme = Theme.of(context);

      try {
        final journalProvider = Provider.of<JournalProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        // ✨ [MODIFY] Use state variable
        if (_currentEntryData == null) {
          throw Exception("Could not delete. Entry not found.");
        }
        String entryId = _currentEntryData!['id'];

        if (widget.isShared) {
          String? coupleId = userProvider.coupleId;
          if (coupleId == null) throw Exception("Could not delete. No couple found.");
          await journalProvider.deleteSharedJournalEntry(coupleId, entryId);
        } else {
          final userId = userProvider.getUserId();
          if (userId == null) throw Exception("Could not delete. User not found.");
          await journalProvider.deletePersonalJournal(userId, entryId);
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.isShared ? 'Shared Journal' : 'Journal entry'} deleted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
  }

  Future<void> _showDeleteConfirmation() async {
    final theme = Theme.of(context);
    
    final contentText = widget.isShared
        ? 'Are you sure you want to delete this shared journal? This will permanently delete both your and your partner\'s contributions.'
        : 'Are you sure you want to delete this journal entry? This action cannot be undone.';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog.adaptive(
          title: Text(widget.isShared ? 'Delete Shared Journal' : 'Delete Journal'),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text("Delete", style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _handleDelete();
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
      ),
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          
          appBar: AppBar(
            title: Text(widget.isShared ? 'Shared Journal' : 'Personal Journal'),
            centerTitle: false,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            actions: [
              
              // ✨ [MODIFIED] Replaced AnimatedSwitcher with a Stack and AnimatedOpacity
              // This ensures both icons are in the *exact* same position.
              SizedBox(
                width: 48, // Standard icon button width
                height: 48,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. The Spinning Sync Icon
                      AnimatedOpacity(
                        opacity: _isSaving ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: RotationTransition(
                          turns: _syncAnimationController,
                          child: Icon(
                            Icons.sync,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      
                      // 2. The "Saved" Checkmark Icon
                      AnimatedOpacity(
                        opacity: _justSaved ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.check_circle_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_currentEntryData != null && !_isSaving)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: colorScheme.error),
                          const SizedBox(width: 8),
                          const Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 8), 
            ],
          ),
          
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Title',
                      hintStyle: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    style: theme.textTheme.headlineMedium,
                    maxLines: 1,
                  ),
                ),
                Expanded(
                  child: widget.isShared
                      ? SharedJournalQuillEditor(
                          initialSegments: _sharedSegments,
                          onChanged: (segments) => setState(() => _sharedSegments = segments),
                          currentUserId: _currentUserId,
                          partnerUserId: _partnerId,
                        )
                      : _buildPersonalEditor(autofocus: _currentEntryData == null),
                ),
                if (!widget.isShared) _buildStatusBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // _buildPersonalEditor is unchanged
  Widget _buildPersonalEditor({bool autofocus = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocusNode,
        autofocus: autofocus,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration.collapsed(
          hintText: 'Start writing your story...',
          hintStyle: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
        style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.6),
      ),
    );
  }

  // _buildStatusBar is unchanged
  Widget _buildStatusBar() {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, 
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -4), 
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$_wordCount words',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}