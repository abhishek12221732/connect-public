import 'package:flutter/material.dart';

class SharedJournalQuillEditor extends StatefulWidget {
  final List<Map<String, dynamic>>? initialSegments; // [{text, userId}]
  final void Function(List<Map<String, dynamic>> segments) onChanged;
  final bool readOnly;
  final String currentUserId;
  final String partnerUserId;

  const SharedJournalQuillEditor({
    super.key,
    this.initialSegments,
    required this.onChanged,
    required this.currentUserId,
    required this.partnerUserId,
    this.readOnly = false,
  });

  @override
  State<SharedJournalQuillEditor> createState() => _SharedJournalQuillEditorState();
}

class _SharedJournalQuillEditorState extends State<SharedJournalQuillEditor> {
  late List<Map<String, dynamic>> _segments;
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _segments = widget.initialSegments != null
        ? widget.initialSegments!.map((s) => Map<String, dynamic>.from(s)).toList()
        : [];
    for (int i = 0; i < _segments.length; i++) {
      _initControllerAndFocusNode(i);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }
  
  void _initControllerAndFocusNode(int index) {
    if (_segments[index]['userId'] == widget.currentUserId) {
        _controllers[index] = TextEditingController(text: _segments[index]['text'] ?? '');
        _controllers[index]!.addListener(() => _onUserEdit(index));
        _focusNodes[index] = FocusNode();
    }
  }

  void _onUserEdit(int idx) {
    if (_controllers.containsKey(idx) && _controllers[idx]!.text != _segments[idx]['text']) {
        setState(() {
          _segments[idx]['text'] = _controllers[idx]!.text;
        });
        widget.onChanged(_segments);
    }
  }

  void _addUserSegment() {
    setState(() {
      _segments.add({
        'text': '',
        'userId': widget.currentUserId,
      });
      final idx = _segments.length - 1;
      _initControllerAndFocusNode(idx);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNodes.containsKey(idx)) {
          _focusNodes[idx]!.requestFocus();
        }
      });
    });
    widget.onChanged(_segments);
  }

  void _focusLastUserSegment() {
    for (int i = _segments.length - 1; i >= 0; i--) {
      if (_segments[i]['userId'] == widget.currentUserId && _focusNodes.containsKey(i)) {
        if(mounted) {
            _focusNodes[i]!.requestFocus();
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (widget.readOnly) return;
        if (_segments.isEmpty || _segments.last['userId'] != widget.currentUserId) {
          _addUserSegment();
        } else {
          _focusLastUserSegment();
        }
      },
      child: Container(
        color: Colors.transparent,
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            runSpacing: 4.0,
            children: [
              for (int i = 0; i < _segments.length; i++)
                _buildSegmentWidget(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentWidget(int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final segment = _segments[index];
    final bool isUserSegment = segment['userId'] == widget.currentUserId;

    if (isUserSegment) {
      return TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: colorScheme.primary,
        ),
        cursorColor: colorScheme.primary,
        maxLines: null,
        readOnly: widget.readOnly,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          // FIX: The following two lines are removed to make the
          // TextField transparent, showing the container's background color.
          // fillColor: theme.scaffoldBackgroundColor,
          // filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 2),
        ),
      );
    } else {
      return Text(
        '${segment['text'] ?? ''} ',
        style: theme.textTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
      );
    }
  }
}