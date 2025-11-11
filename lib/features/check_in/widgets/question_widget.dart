import 'package:flutter/material.dart';
import 'package:feelings/features/check_in/models/check_in_model.dart';

class QuestionWidget extends StatefulWidget {
  final CheckInQuestion question;
  final dynamic currentAnswer;
  final Function(dynamic) onAnswerChanged;

  const QuestionWidget({
    super.key,
    required this.question,
    required this.currentAnswer,
    required this.onAnswerChanged,
  });

  @override
  State<QuestionWidget> createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  TextEditingController? _textController;

  @override
  void initState() {
    super.initState();
    if (widget.question.type == QuestionType.textInput) {
      _textController = TextEditingController(text: widget.currentAnswer?.toString() ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant QuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.question.type == QuestionType.textInput) {
      if (_textController == null) {
        _textController = TextEditingController(text: widget.currentAnswer?.toString() ?? '');
      } else if (widget.currentAnswer?.toString() != _textController!.text) {
        _textController!.text = widget.currentAnswer?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.question.type) {
      case QuestionType.slider:
        return _buildSliderQuestion();
      case QuestionType.multipleChoice:
        return _buildMultipleChoiceQuestion();
      case QuestionType.textInput:
        return _buildTextInputQuestion();
      case QuestionType.yesNo:
        return _buildYesNoQuestion();
    }
  }

  Widget _buildSliderQuestion() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final minValue = widget.question.minValue ?? 1.0;
    final maxValue = widget.question.maxValue ?? 10.0;
    final currentValue = (widget.currentAnswer as num?)?.toDouble() ?? minValue;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            currentValue.toStringAsFixed(1),
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // THEME: Slider now uses the global sliderTheme from your app's theme
        Slider(
          value: currentValue,
          min: minValue,
          max: maxValue,
          divisions: (maxValue - minValue).toInt(),
          onChanged: (value) {
            widget.onAnswerChanged(value);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${minValue.toInt()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              '${maxValue.toInt()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceQuestion() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final options = widget.question.options ?? [];
    
    return Column(
      children: options.map((option) {
        final isSelected = widget.currentAnswer == option;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => widget.onAnswerChanged(option),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary.withOpacity(0.4) : colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : theme.dividerColor,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextInputQuestion() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // THEME: This TextField now uses the global inputDecorationTheme
        TextField(
          controller: _textController,
          onChanged: (value) => widget.onAnswerChanged(value),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: widget.question.placeholder ?? 'Share your thoughts...',
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
          ),
          style: theme.textTheme.bodyLarge,
        ),
        if (!widget.question.isRequired) ...[
          const SizedBox(height: 8),
          Text(
            'This question is optional',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildYesNoQuestion() {
    return Row(
      children: [
        Expanded(
          child: _buildYesNoOption('Yes', true),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildYesNoOption('No', false),
        ),
      ],
    );
  }

  Widget _buildYesNoOption(String label, bool value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = widget.currentAnswer == value;
    
    return InkWell(
      onTap: () => widget.onAnswerChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.4) : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : theme.dividerColor,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}