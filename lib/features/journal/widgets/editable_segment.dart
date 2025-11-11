import 'package:flutter/material.dart';

class EditableSegment extends StatefulWidget {
  final TextEditingController controller;
  final bool isOwnSegment;
  final TextStyle textStyle;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  const EditableSegment({
    super.key,
    required this.controller,
    required this.isOwnSegment,
    required this.textStyle,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  _EditableSegmentState createState() => _EditableSegmentState();
}

class _EditableSegmentState extends State<EditableSegment> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.isOwnSegment) {
      return _isEditing
          ? Card(
              // THEME: The Card now uses the global cardTheme for its appearance
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                // THEME: Use a theme-aware border color
                side: BorderSide(color: colorScheme.primary.withOpacity(0.15)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        autofocus: true,
                        maxLines: null,
                        style: widget.textStyle,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: widget.onChanged,
                        onEditingComplete: () {
                          if (widget.controller.text.trim().isEmpty) {
                            widget.onDelete();
                          }
                          setState(() => _isEditing = false);
                        },
                      ),
                    ),
                    IconButton(
                      // THEME: Use the theme's error color for delete actions
                      icon: Icon(Icons.delete, color: colorScheme.error, size: 20),
                      onPressed: widget.onDelete,
                      tooltip: 'Delete Segment',
                    ),
                  ],
                ),
              ),
            )
          : GestureDetector(
              onTap: () => setState(() => _isEditing = true),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.10)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.controller.text,
                          style: widget.textStyle,
                          textAlign: TextAlign.left,
                        ),
                      ),
                      IconButton(
                        // THEME: Use the theme's primary color for edit actions
                        icon: Icon(Icons.edit, color: colorScheme.primary, size: 18),
                        onPressed: () => setState(() => _isEditing = true),
                        tooltip: 'Edit Segment',
                      ),
                    ],
                  ),
                ),
              ),
            );
    } else {
      // Non-editable segment for the partner
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // THEME: Use a subtle, theme-aware border
          side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            widget.controller.text,
            style: widget.textStyle,
            textAlign: TextAlign.left,
          ),
        ),
      );
    }
  }
}