import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:feelings/providers/question_provider.dart';
// ✨ [ADD] Import UserProvider to get coupleId
import 'package:feelings/providers/user_provider.dart'; 
import 'package:feelings/features/questions/models/question_model.dart';
import 'package:feelings/constants.dart';
import 'package:feelings/features/chat/screens/chat_screen.dart';
import 'package:feelings/widgets/pulsing_dots_indicator.dart';

class QuestionsScreen extends StatefulWidget {
  // ... (unchanged)
  final int initialTabIndex;
  final String? initialCategory;
  final String? initialSubCategory;

  const QuestionsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialCategory,
    this.initialSubCategory,
  });

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen>
    with SingleTickerProviderStateMixin {
  // ... (state variables _auth, _userId, _isAuthReady, _tabController are unchanged) ...
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  bool _isAuthReady = false;
  late TabController _tabController;

  // State for RandomQuestionTab
  String? _selectedCategoryForRandom;
  String? _selectedSubCategoryForRandom;
  List<String> _subCategoriesForRandomDropdown = [];

  // State for BrowseQuestionsTab
  String? _selectedCategoryForBrowse;
  String? _selectedSubCategoryForBrowse;
  List<String> _subCategoriesForBrowseDropdown = [];
  bool _initialBrowseFilterApplied = false;

  @override
  void initState() {
    // ... (initState logic is unchanged) ...
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _userId = user?.uid;
          _isAuthReady = true;
        });
        if (user != null) {
          final questionProvider =
              Provider.of<QuestionProvider>(context, listen: false);
          questionProvider.fetchQuestions(user.uid);
          questionProvider.refreshCategoriesAndSubCategories().then((_) {
            if (!_initialBrowseFilterApplied &&
                widget.initialCategory != null &&
                _tabController.index == 1) {
              _selectedCategoryForBrowse = widget.initialCategory;
              if (widget.initialCategory != null) {
                _subCategoriesForBrowseDropdown =
                    kCategoriesData[widget.initialCategory]?['subCategories']
                            ?.cast<String>() ??
                        [];
              }
              _selectedSubCategoryForBrowse = widget.initialSubCategory;
              _filterQuestions(questionProvider);
              _initialBrowseFilterApplied = true;
            }
          });
        } else {
          Provider.of<QuestionProvider>(context, listen: false)
              .fetchQuestions('');
        }
      }
    });

    _tabController.addListener(() {
      if (_tabController.index == 1 && !_initialBrowseFilterApplied) {
        final questionProvider =
            Provider.of<QuestionProvider>(context, listen: false);
        if (questionProvider.categories.isNotEmpty ||
            questionProvider.isLoading) {
          if (widget.initialCategory != null) {
            _selectedCategoryForBrowse = widget.initialCategory;
            _subCategoriesForBrowseDropdown =
                kCategoriesData[widget.initialCategory]?['subCategories']
                        ?.cast<String>() ??
                    [];
          }
          _selectedSubCategoryForBrowse = widget.initialSubCategory;
          _filterQuestions(questionProvider);
          _initialBrowseFilterApplied = true;
        }
      }
    });
  }

  @override
  void dispose() {
    // ... (unchanged)
    _tabController.dispose();
    super.dispose();
  }

  void _generateQuestion(QuestionProvider provider) async {
    // ... (unchanged)
    if (_userId == null) {
      _showAuthWarning(context);
      return;
    }
    if (_selectedCategoryForRandom != null &&
        _selectedSubCategoryForRandom != null) {
      await provider.fetchRandomAvailableQuestionByCategoryAndSubCategory(
        _userId!,
        _selectedCategoryForRandom!,
        _selectedSubCategoryForRandom!,
      );
    } else if (_selectedCategoryForRandom != null) {
      await provider.fetchRandomAvailableQuestionByCategory(
        _userId!,
        _selectedCategoryForRandom!,
      );
    } else {
      await provider.fetchRandomAvailableQuestion(_userId!);
    }
  }

  // ✨ [MODIFY] Update _askQuestion
  void _askQuestion(QuestionModel question) async {
    if (_userId == null) {
      _showAuthWarning(context);
      return;
    }
    // ✨ [ADD] Get UserProvider and coupleId
    final userProvider = context.read<UserProvider>();
    final coupleId = userProvider.coupleId; 
    
    // ✨ [ADD] Check if coupleId exists
    if (coupleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot mark question as done. Couple connection not found.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            // ... (Dialog unchanged) ...
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: theme.dialogTheme.shape ??
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
              title: Text(
                'Ask in chat?',
                style: theme.textTheme.titleLarge,
              ),
              content: Text(
                '"${question.question}"',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Ask'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      final questionProvider =
          Provider.of<QuestionProvider>(context, listen: false);
      // ✨ [MODIFY] Pass coupleId here
      await questionProvider.markQuestionAsDone(_userId!, question.id, coupleId); 
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            questionToAsk: question.question,
          ),
        ),
      );
    }
  }

  void _filterQuestions(QuestionProvider provider) async {
    // ... (unchanged)
    if (_userId == null) {
      _showAuthWarning(context);
      return;
    }

    if ((_selectedCategoryForBrowse != null &&
            _selectedSubCategoryForBrowse != null) ||
        (_selectedCategoryForBrowse != null) ||
        (_selectedCategoryForBrowse == null &&
            _selectedSubCategoryForBrowse == null)) {
      if (_selectedCategoryForBrowse != null &&
          _selectedSubCategoryForBrowse != null) {
        await provider.fetchQuestionsByCategoryAndSubCategory(
          _selectedCategoryForBrowse!,
          _selectedSubCategoryForBrowse!,
        );
      } else if (_selectedCategoryForBrowse != null) {
        await provider.fetchQuestionsByCategory(_selectedCategoryForBrowse!);
      } else {
        await provider.fetchQuestions(_userId!);
      }
    }
  }

  // ✨ [MODIFY] Update _toggleQuestionDoneStatus
  void _toggleQuestionDoneStatus(
    QuestionProvider provider,
    QuestionModel question,
    bool isCurrentlyDone,
  ) async {
    if (_userId == null) {
      _showAuthWarning(context);
      return;
    }
    // ✨ [ADD] Get UserProvider and coupleId
    final userProvider = context.read<UserProvider>();
    final coupleId = userProvider.coupleId;

    // ✨ [ADD] Check if coupleId exists (only needed when marking *as done*)
    if (!isCurrentlyDone && coupleId == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot mark question as done. Couple connection not found.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (isCurrentlyDone) {
      await provider.removeQuestionFromDone(_userId!, question.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question marked as undone!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      // ✨ [MODIFY] Pass coupleId here
      await provider.markQuestionAsDone(_userId!, question.id, coupleId!); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question marked as done!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  void _showAuthWarning(BuildContext context) {
    // ... (unchanged)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Authentication not ready. Please wait a moment.'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildDropdownCard({
    required String title,
    required Widget child,
  }) {
    // ... (unchanged)
    final theme = Theme.of(context);
    return Card(
      elevation: theme.cardTheme.elevation,
      shape: theme.cardTheme.shape,
      color: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionDisplayCard(
    QuestionModel question,
    QuestionProvider provider,
  ) {
    // ... (unchanged)
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: theme.cardTheme.elevation,
      shape: theme.cardTheme.shape,
      color: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.question,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Category: ${question.category}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Subcategory: ${question.subCategory}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _askQuestion(question),
                  child:  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 16, color:colorScheme.onPrimary),
                      SizedBox(width: 6),
                      Text('Discuss'),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _generateQuestion(provider),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.skip_next, size: 16),
                      SizedBox(width: 6),
                      Text('Next'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (build method logic is largely unchanged, just the calls inside _toggleQuestionDoneStatus and _askQuestion are updated) ...
    final questionProvider = Provider.of<QuestionProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String? currentSelectedCategoryForBrowse = _selectedCategoryForBrowse;
    String? currentSelectedSubCategoryForBrowse = _selectedSubCategoryForBrowse;

    if (currentSelectedCategoryForBrowse != null &&
        !questionProvider.categories
            .contains(currentSelectedCategoryForBrowse)) {
      currentSelectedCategoryForBrowse = null;
      currentSelectedSubCategoryForBrowse = null;
    }

    List<String> currentSubCategoriesForBrowseDropdown = [];
    if (currentSelectedCategoryForBrowse != null) {
      currentSubCategoriesForBrowseDropdown =
          kCategoriesData[currentSelectedCategoryForBrowse]?['subCategories']
                  ?.cast<String>() ??
              [];
    }

    if (currentSelectedSubCategoryForBrowse != null &&
        !currentSubCategoriesForBrowseDropdown
            .contains(currentSelectedSubCategoryForBrowse)) {
      currentSelectedSubCategoryForBrowse = null;
    }

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connect With Questions'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.casino_outlined),
                text: 'Generate',
              ),
              Tab(
                icon: Icon(Icons.library_books_outlined),
                text: 'Browse',
              ),
              Tab(
                icon: Icon(Icons.check_circle_outline),
                text: 'Done',
              ),
            ],
          ),
        ),
        body: questionProvider.isLoading && !_isAuthReady
            ? Center(
                child: PulsingDotsIndicator(
                  size: 80,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary,
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  // --- Generate Question Tab ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDropdownCard(
                          title: 'Filter by Category',
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategoryForRandom, // Use value instead of initialValue
                            hint: Text(
                              'All Categories',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'All Categories',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontSize: 13),
                                ),
                              ),
                              ...questionProvider.categories
                                  .map((category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(
                                          category,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontSize: 13),
                                        ),
                                      )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCategoryForRandom = value;
                                _selectedSubCategoryForRandom = null;
                                if (value != null) {
                                  _subCategoriesForRandomDropdown =
                                      kCategoriesData[value]?['subCategories']
                                              ?.cast<String>() ??
                                          [];
                                } else {
                                  _subCategoriesForRandomDropdown = [];
                                }
                              });
                            },
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 13),
                          ),
                        ),
                        if (_selectedCategoryForRandom != null) ...[
                          const SizedBox(height: 8),
                          _buildDropdownCard(
                            title: 'Filter by Subcategory',
                            child: DropdownButtonFormField<String>(
                              value: _selectedSubCategoryForRandom, // Use value
                              hint: Text(
                                'All Subcategories',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 13),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'All Subcategories',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontSize: 13),
                                  ),
                                ),
                                ..._subCategoriesForRandomDropdown
                                    .map((sub) => DropdownMenuItem(
                                          value: sub,
                                          child: Text(
                                            sub,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(fontSize: 13),
                                          ),
                                        )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedSubCategoryForRandom = value;
                                });
                              },
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: questionProvider.isLoading ||
                                  !_isAuthReady ||
                                  _userId == null
                              ? null
                              : () => _generateQuestion(questionProvider),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.casino_outlined, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                questionProvider.isLoading
                                    ? 'Loading...'
                                    : 'Generate New Question',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        questionProvider.currentRandomQuestion == null
                            ? Center(
                                child: Text(
                                  questionProvider.isLoading
                                      ? 'Fetching options...'
                                      : 'Press "Generate New Question" to begin!',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : _buildQuestionDisplayCard(
                                questionProvider.currentRandomQuestion!,
                                questionProvider,
                              ),
                      ],
                    ),
                  ),

                  // --- Browse Questions Tab ---
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            _buildDropdownCard(
                              title: 'Filter by Category',
                              child: DropdownButtonFormField<String>(
                                value: currentSelectedCategoryForBrowse, // Use value
                                hint: Text(
                                  'All Categories',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 13),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'All Categories',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontSize: 13),
                                    ),
                                  ),
                                  ...questionProvider.categories
                                      .map((category) => DropdownMenuItem(
                                            value: category,
                                            child: Text(
                                              category,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(fontSize: 13),
                                            ),
                                          )),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategoryForBrowse = value;
                                    _selectedSubCategoryForBrowse = null;
                                    if (value != null) {
                                      _subCategoriesForBrowseDropdown =
                                          kCategoriesData[value]
                                                  ?['subCategories']
                                                  ?.cast<String>() ??
                                              [];
                                    } else {
                                      _subCategoriesForBrowseDropdown = [];
                                    }
                                    _initialBrowseFilterApplied = true;
                                  });
                                  _filterQuestions(questionProvider);
                                },
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontSize: 13),
                              ),
                            ),
                            if (currentSelectedCategoryForBrowse != null) ...[
                              const SizedBox(height: 8),
                              _buildDropdownCard(
                                title: 'Filter by Subcategory',
                                child: DropdownButtonFormField<String>(
                                  value: currentSelectedSubCategoryForBrowse, // Use value
                                  hint: Text(
                                    'All Subcategories',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 13),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        'All Subcategories',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(fontSize: 13),
                                      ),
                                    ),
                                    ...currentSubCategoriesForBrowseDropdown
                                        .map((sub) => DropdownMenuItem(
                                              value: sub,
                                              child: Text(
                                                sub,
                                                style: theme.textTheme
                                                    .bodyMedium
                                                    ?.copyWith(fontSize: 13),
                                              ),
                                            )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSubCategoryForBrowse = value;
                                      _initialBrowseFilterApplied = true;
                                    });
                                    _filterQuestions(questionProvider);
                                  },
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontSize: 13),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: questionProvider.questions.isEmpty
                            ? Center(
                                child: Text(
                                  questionProvider.isLoading
                                      ? 'Loading questions...'
                                      : 'No questions found for selected filters.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: questionProvider.questions.length,
                                itemBuilder: (context, index) {
                                  final question =
                                      questionProvider.questions[index];
                                  final isDone = questionProvider.doneQuestions
                                      .contains(question.id);
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: theme.cardTheme.color,
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.shadowColor
                                              .withOpacity(0.1),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            question.question,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              color: isDone
                                                  ? colorScheme.onSurfaceVariant
                                                  : colorScheme.onSurface,
                                              decoration: isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Category: ${question.category}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            'Subcategory: ${question.subCategory}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              if (!isDone)
                                                ElevatedButton.icon(
                                                  onPressed: !_isAuthReady ||
                                                          _userId == null
                                                      ? null
                                                      : () =>
                                                          _toggleQuestionDoneStatus(
                                                            questionProvider,
                                                            question,
                                                            isDone,
                                                          ),
                                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                                  label: const Text('Mark Done'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: colorScheme
                                                        .secondary,
                                                    foregroundColor:
                                                        colorScheme
                                                            .onSecondary,
                                                    textStyle: theme
                                                        .textTheme.labelSmall,
                                                  ),
                                                ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed: !_isAuthReady ||
                                                        _userId == null
                                                    ? null
                                                    : () =>
                                                        _askQuestion(question),
                                                icon: Icon(Icons.chat_bubble_outline, size: 16, color:colorScheme.onPrimary),
                                                label: const Text('Discuss'),
                                                // FIXED: Explicitly set foreground color for contrast
                                                style:
                                                    ElevatedButton.styleFrom(
                                                  foregroundColor:
                                                      colorScheme.onPrimary,
                                                  textStyle: theme
                                                      .textTheme.labelSmall,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // --- Done Questions Tab ---
                  Consumer<QuestionProvider>(
                    builder: (context, questionProvider, child) {
                      if (questionProvider.isLoading &&
                          questionProvider.questions.isEmpty) {
                        return Center(
                          child: PulsingDotsIndicator(
                            size: 30,
                            colors: [
                              Theme.of(context).colorScheme.onError,
                              Theme.of(context).colorScheme.onError,
                              Theme.of(context).colorScheme.onError,
                            ],
                          ),
                        );
                      }

                      final List<QuestionModel> doneQuestionsList =
                          questionProvider.questions
                              .where((q) =>
                                  questionProvider.doneQuestions.contains(q.id))
                              .toList();

                      if (doneQuestionsList.isEmpty) {
                        return Center(
                          child: Text(
                            questionProvider.isLoading
                                ? 'Loading done questions...'
                                : 'No questions marked as done yet.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: doneQuestionsList.length,
                        itemBuilder: (context, index) {
                          final question = doneQuestionsList[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: colorScheme.surfaceContainerHighest,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question.question,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Category: ${question.category}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Subcategory: ${question.subCategory}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed:
                                            !_isAuthReady || _userId == null
                                                ? null
                                                : () =>
                                                    _toggleQuestionDoneStatus(
                                                      questionProvider,
                                                      question,
                                                      true,
                                                    ),
                                        icon: const Icon(Icons.undo, size: 16),
                                        label: const Text('Mark Undone'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              colorScheme.secondary,
                                          foregroundColor:
                                              colorScheme.onSecondary,
                                          textStyle:
                                              theme.textTheme.labelSmall,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        onPressed:
                                            !_isAuthReady || _userId == null
                                                ? null
                                                : () => _askQuestion(question),
                                        icon:  Icon(
                                            Icons.chat_bubble_outline,
                                            size: 16,
                                            color:colorScheme.onPrimary),
                                        label: const Text('Discuss'),
                                        // FIXED: Explicitly set foreground color for contrast
                                        style: ElevatedButton.styleFrom(
                                            foregroundColor:
                                                colorScheme.onPrimary,
                                            textStyle:
                                                theme.textTheme.labelSmall),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}