// lib/features/check_in/screens/check_in_questions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:feelings/features/check_in/models/check_in_model.dart';
import 'package:feelings/providers/check_in_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';
import '../repository/check_in_repository.dart';
import 'check_in_summary_screen.dart';


const _kPageAnimationDuration = Duration(milliseconds: 350);
const _kCardAnimationDuration = Duration(milliseconds: 300);
const _kHorizontalPadding = 16.0;

class CheckInQuestionsScreen extends StatefulWidget {
  final String userId;
  final String checkInId;

  const CheckInQuestionsScreen({
    super.key,
    required this.userId,
    required this.checkInId,
  });

  @override
  State<CheckInQuestionsScreen> createState() => _CheckInQuestionsScreenState();
}

class _CheckInQuestionsScreenState extends State<CheckInQuestionsScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final Map<String, dynamic> _answers = {};

  late List<CheckInQuestion> _questions = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isFinishing = false; // Also used for canceling state

  late AnimationController _cardAnimController;
  late Animation<double> _cardScaleAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _pageController.addListener(_onPageChanged);
    _loadQuestions();
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _cardAnimController = AnimationController(vsync: this, duration: _kCardAnimationDuration);
    _cardScaleAnim = Tween<double>(begin: 0.97, end: 1.0)
        .animate(CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutBack));
    _cardAnimController.forward();
  }

  void _onPageChanged() {
    final newIndex = _pageController.page?.round() ?? 0;
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
      _cardAnimController.forward(from: 0.0);
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final repository = CheckInRepository();
      _questions = await repository.generateQuestions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading questions: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _saveAnswer(String questionId, dynamic value) {
    HapticFeedback.selectionClick();
    setState(() => _answers[questionId] = value);
  }

  bool get _isCurrentQuestionAnswered {
    if (_questions.isEmpty) return false;
    final currentQuestionId = _questions[_currentIndex].id;
    final answer = _answers[currentQuestionId];
    return answer != null && answer.toString().isNotEmpty;
  }
  
  void _nextPage() {
    if (_currentIndex < _questions.length - 1) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(duration: _kPageAnimationDuration, curve: Curves.easeInOut);
    } else {
      _finishCheckIn();
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    _pageController.previousPage(duration: _kPageAnimationDuration, curve: Curves.easeInOut);
  }

  Future<void> _cancelCheckIn() async {
    setState(() => _isFinishing = true);
    try {
      final checkInProvider = Provider.of<CheckInProvider>(context, listen: false);
      await checkInProvider.cancelCheckIn(widget.userId, widget.checkInId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel check-in: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFinishing = false);
      }
    }
  }

  Future<void> _finishCheckIn() async {
    setState(() => _isFinishing = true);
    final checkInProvider = Provider.of<CheckInProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      final coupleId = userProvider.coupleId;
      if (coupleId == null) throw Exception('Couple ID not found');
      
      await checkInProvider.completeCheckIn(
        widget.userId,
        widget.checkInId,
        coupleId,
        _questions,
        _answers,
        userProvider.getPartnerId(),
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => CheckInSummaryScreen(
              userId: widget.userId,
              checkInId: widget.checkInId,
            ),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 28),
              const SizedBox(width: 8),
              const Text('Error'),
            ]),
            content: Text('Failed to complete check-in: ${e.toString()}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Relationship Check-in'),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isFinishing ? null : _cancelCheckIn,
            tooltip: 'Cancel Check-in',
          ),
          automaticallyImplyLeading: false,
        ),
        body: _buildBody(),
        bottomNavigationBar: _questions.isNotEmpty ? _buildBottomNavBar() : null,
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(child: PulsingDotsIndicator(size: 80, colors: [theme.colorScheme.primary, theme.colorScheme.primary, theme.colorScheme.primary]),);
    }

    if (_questions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(_kHorizontalPadding),
          child: Text(
            'Could not load questions.\nPlease try again later.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return Stack(
      children: [
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding),
            child: Column(
              children: [
                _ProgressIndicator(
                  currentIndex: _currentIndex,
                  questionCount: _questions.length,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _questions.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return ScaleTransition(
                        scale: _cardScaleAnim,
                        child: _QuestionCard(
                          question: _questions[index],
                          answer: _answers[_questions[index].id],
                          onAnswered: (value) => _saveAnswer(_questions[index].id, value),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isFinishing)
          Container(
            color: theme.colorScheme.scrim.withOpacity(0.5),
            child: Center(
              child: PulsingDotsIndicator(size: 80, colors: [theme.colorScheme.primary, theme.colorScheme.primary, theme.colorScheme.primary]),
            ),
          ),
      ],
    );
  }
  
  Widget _buildBottomNavBar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.bottomAppBarTheme.color ?? theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding, vertical: 12),
      child: SafeArea(
        top: false,
        child: _NavigationControls(
          currentIndex: _currentIndex,
          questionCount: _questions.length,
          isAnswered: _isCurrentQuestionAnswered,
          onBack: _previousPage,
          onNext: _nextPage,
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int currentIndex;
  final int questionCount;

  const _ProgressIndicator({required this.currentIndex, required this.questionCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (currentIndex + 1) / questionCount;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your honesty helps!',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
            Text(
              '${currentIndex + 1} of $questionCount',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          minHeight: 6,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final CheckInQuestion question;
  final dynamic answer;
  final ValueChanged<dynamic> onAnswered;

  const _QuestionCard({
    required this.question,
    required this.answer,
    required this.onAnswered,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData iconData = Icons.psychology_outlined;
    if (question.type == QuestionType.slider) iconData = Icons.tune_rounded;
    if (question.type == QuestionType.textInput) iconData = Icons.edit_note_rounded;
    if (question.type == QuestionType.yesNo) iconData = Icons.rule_rounded;

    return Card(
      elevation: theme.cardTheme.elevation ?? 4,
      shadowColor: theme.cardTheme.shadowColor ?? theme.colorScheme.shadow.withOpacity(0.1),
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: theme.cardTheme.shape ?? const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24.0)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(iconData, size: 28, color: theme.colorScheme.onPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              question.question,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (question.isTrendBased == true) ...[
              const SizedBox(height: 12),
              Chip(
                avatar: Icon(Icons.trending_up, size: 18, color: theme.colorScheme.secondary),
                label: Text('Based on recent trends', style: theme.textTheme.bodySmall),
                backgroundColor: theme.colorScheme.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ],
            const SizedBox(height: 32),
            _buildAnswerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerWidget() {
    switch (question.type) {
      case QuestionType.slider:
        return _SliderAnswer(question: question, answer: answer, onAnswered: onAnswered);
      case QuestionType.textInput:
        return _TextInputAnswer(question: question, answer: answer, onAnswered: onAnswered);
      case QuestionType.yesNo:
        return _YesNoAnswer(answer: answer, onAnswered: onAnswered);
      default:
        return const Text('Unsupported question type');
    }
  }
}

class _SliderAnswer extends StatelessWidget {
  final CheckInQuestion question;
  final dynamic answer;
  final ValueChanged<dynamic> onAnswered;

  const _SliderAnswer({required this.question, this.answer, required this.onAnswered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double value = (answer ?? question.minValue)?.toDouble();
    return Column(
      children: [
        Text(
          value.round().toString(),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Slider(
          value: value,
          min: question.minValue ?? 1.0,
          max: question.maxValue ?? 10.0,
          divisions: ((question.maxValue ?? 10.0) - (question.minValue ?? 1.0)).toInt(),
          label: value.round().toString(),
          onChanged: (newValue) => onAnswered(newValue),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Not at all', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text('Very much', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _YesNoAnswer extends StatelessWidget {
  final dynamic answer;
  final ValueChanged<dynamic> onAnswered;

  const _YesNoAnswer({this.answer, required this.onAnswered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = [answer == 'Yes', answer == 'No'];

    return ToggleButtons(
      isSelected: isSelected,
      onPressed: (index) {
        onAnswered(index == 0 ? 'Yes' : 'No');
      },
      borderRadius: BorderRadius.circular(12.0),
      selectedColor: theme.colorScheme.onPrimary,
      color: theme.colorScheme.primary,
      fillColor: theme.colorScheme.primary,
      borderColor: theme.colorScheme.outline,
      selectedBorderColor: theme.colorScheme.primary,
      constraints: const BoxConstraints(minHeight: 48.0, minWidth: 120.0),
      children: const [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline), SizedBox(width: 8), Text('Yes')]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.highlight_off_outlined), SizedBox(width: 8), Text('No')]),
      ],
    );
  }
}

class _TextInputAnswer extends StatelessWidget {
  final CheckInQuestion question;
  final dynamic answer;
  final ValueChanged<dynamic> onAnswered;

  const _TextInputAnswer({required this.question, this.answer, required this.onAnswered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String text = answer as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextFormField(
          initialValue: text,
          decoration: InputDecoration(
            hintText: question.placeholder ?? 'Share your thoughts here...',
            counterText: '',
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            filled: true,
          ),
          maxLines: 5,
          minLines: 3,
          maxLength: 300,
          onChanged: onAnswered,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(
            '${text.length}/300',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _NavigationControls extends StatelessWidget {
  final int currentIndex;
  final int questionCount;
  final bool isAnswered;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _NavigationControls({
    required this.currentIndex,
    required this.questionCount,
    required this.isAnswered,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastQuestion = currentIndex == questionCount - 1;
    
    return Row(
      children: [
        if (currentIndex > 0)
          TextButton.icon(
            icon:  const Icon(Icons.arrow_back_ios_new, size: 16),
            label: const Text('Back'),
            onPressed: onBack,
            style: theme.textButtonTheme.style,
          ),
        const Spacer(),
        ElevatedButton.icon(
          icon: Icon(isLastQuestion ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, size: 20, color: theme.colorScheme.onPrimary),
          label: Text(isLastQuestion ? 'Finish' : 'Next'),
          onPressed: isAnswered ? onNext : null,
          style: theme.elevatedButtonTheme.style?.copyWith(
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14)
            ),
          ),
        ),
      ],
    );
  }
}