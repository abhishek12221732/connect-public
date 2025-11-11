import 'package:flutter/material.dart';

class ShareInsightsDialog extends StatefulWidget {
  final List<String> insights;

  const ShareInsightsDialog({
    super.key,
    required this.insights,
  });

  @override
  State<ShareInsightsDialog> createState() => _ShareInsightsDialogState();
}

class _ShareInsightsDialogState extends State<ShareInsightsDialog> {
  late List<bool> _selected;
  bool _shareFullCheckIn = false;

  @override
  void initState() {
    super.initState();
    _selected = List.generate(widget.insights.length, (_) => true);
  }

  @override
  Widget build(BuildContext context) {
    // THEME: Get theme and colorScheme from context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      // THEME: The title and content text now use the theme's text styles
      title: const Text('Share Insights'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select the insights you\'d like to share with your partner:',
            ),
            
            const SizedBox(height: 16),
            
            // Insights list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.insights.length,
                itemBuilder: (context, index) {
                  final insight = widget.insights[index];
                  final isSelected = _selected[index];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selected[index] = !isSelected;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // THEME: Use theme colors for background and border
                          color: isSelected 
                              ? colorScheme.primary.withOpacity(0.4)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                                ? colorScheme.primary
                                : theme.dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  _selected[index] = value ?? false;
                                });
                              },
                              // THEME: The checkbox is styled by the global checkboxTheme
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                insight,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  // THEME: Use theme colors for text
                                  color: isSelected 
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                  fontWeight: isSelected 
                                      ? FontWeight.w500 
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              children: [
                // THEME: The Switch is styled by the global switchTheme
                Switch(
                  value: _shareFullCheckIn,
                  onChanged: (val) {
                    setState(() {
                      _shareFullCheckIn = val;
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('Share full check-in (all answers)')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        // THEME: This button is styled by the global textButtonTheme
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // THEME: This button is styled by the global elevatedButtonTheme
        ElevatedButton(
          onPressed: () {
            final selected = <String>[];
            for (int i = 0; i < widget.insights.length; i++) {
              if (_selected[i]) selected.add(widget.insights[i]);
            }
            Navigator.of(context).pop({'insights': selected, 'shareFullCheckIn': _shareFullCheckIn});
          },
          child: const Text('Share'),
        ),
      ],
    );
  }
}