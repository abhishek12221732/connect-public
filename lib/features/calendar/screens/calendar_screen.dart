// lib/features/calendar/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feelings/providers/calendar_provider.dart';
import 'package:feelings/providers/user_provider.dart';
import 'package:feelings/providers/date_idea_provider.dart';
// ✨ [ADD] Import RhmRepository
import 'package:feelings/features/rhm/repository/rhm_repository.dart';
import 'dart:math';
import '../services/reminder_service.dart';
import '../../discover/widgets/connect_with_partner_card.dart';
import 'package:feelings/features/connectCouple/screens/connect_couple_screen.dart';
import 'calendar_view.dart'; // Import the new View
import 'package:feelings/features/date_night/screens/generated_date_idea_screen.dart';
import '../utils/calendar_utils.dart'; // Import the new Utils
import '../widgets/add_milestone_form.dart';
import '../widgets/edit_milestone_form.dart';
import 'package:feelings/providers/dynamic_actions_provider.dart';
import 'package:feelings/features/calendar/repository/calendar_repository.dart';

class CalendarScreen extends StatefulWidget {
  // ... (unchanged)
 const CalendarScreen({super.key});

 @override
 _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  // ... (state variables _fadeController, _fadeAnimation, coupleId, etc. are unchanged) ...
 late AnimationController _fadeController;
 late Animation<double> _fadeAnimation;

 String? coupleId;
 DateTime _focusedDay = DateTime.now();
 DateTime? _selectedDay;
 bool _showSearchBar = false;
 String _searchQuery = '';
 String _activeCategory = 'all';

 @override
 void initState() {
    // ... (unchanged)
   super.initState();
   _fadeController = AnimationController(
     duration: const Duration(milliseconds: 500),
     vsync: this,
   );
   _fadeAnimation =
       CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
   _fadeController.forward();

   _initCoupleId();
 }

 @override
 void dispose() {
    // ... (unchanged)
   _fadeController.dispose();
   super.dispose();
 }

 Future<void> _initCoupleId() async {
    // ... (unchanged)
   final userProvider = Provider.of<UserProvider>(context, listen: false);
   final fetchedCoupleId = userProvider.coupleId;
   if (mounted) {
     setState(() {
       coupleId = fetchedCoupleId;
     });
   }
 }

 Future<void> _cancelReminder(int? notificationId) async {
    // ... (unchanged)
   if (notificationId != null) {
     await ReminderService().cancelNotification(notificationId);
   }
 }

 List _getSortedMilestones(List milestones) {
    // ... (unchanged)
   milestones.sort((a, b) {
     final daysUntilA = calculateDaysUntilMilestone(a.date);
     final daysUntilB = calculateDaysUntilMilestone(b.date);
     if (daysUntilA == 0 && daysUntilB != 0) return -1;
     if (daysUntilB == 0 && daysUntilA != 0) return 1;
     if (daysUntilA > 0 && daysUntilB < 0) return -1;
     if (daysUntilB > 0 && daysUntilA < 0) return 1;
     if (daysUntilA > 0 && daysUntilB > 0) {
       return daysUntilA.compareTo(daysUntilB);
     }
     if (daysUntilA < 0 && daysUntilB < 0) {
       return daysUntilB.compareTo(daysUntilA);
     }
     return 0;
   });
   return milestones;
 }

 void _onAddMilestone() async {
    // ... (unchanged)
   await showModalBottomSheet(
     context: context,
     isScrollControlled: true,
     backgroundColor: Theme.of(context).colorScheme.surface,
     shape: const RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
     ),
     builder: (context) => AddMilestoneForm(coupleId: coupleId!),
   );
 }

 void _showEditMilestoneModal(BuildContext context, milestone) {
    // ... (unchanged)
   showModalBottomSheet(
     context: context,
     isScrollControlled: true,
     backgroundColor: Theme.of(context).colorScheme.surface,
     shape: const RoundedRectangleBorder(
       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
     ),
     builder: (context) =>
         EditMilestoneForm(coupleId: coupleId!, milestone: milestone),
   );
 }

 void _onGenerateDateIdea() async {
    // ... (unchanged)
   final userProvider = Provider.of<UserProvider>(context, listen: false);
   final dateIdeaProvider =
       Provider.of<DateIdeaProvider>(context, listen: false);
   final userId = userProvider.getUserId() ?? '';
   final coupleId = userProvider.coupleId ?? '';

   if (userId.isEmpty || coupleId.isEmpty) {
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Please wait, loading your profile...')),
     );
     return;
   }

   final random = Random();
   dateIdeaProvider.reset();

   const allLocations = ['At Home', 'Outdoors', 'Out & About', 'Getaway'];
   final numLocations = random.nextInt(2) + 1;
   final shuffledLocations = List.from(allLocations)..shuffle();
   for (int i = 0; i < numLocations; i++) {
     dateIdeaProvider.toggleLocation(shuffledLocations[i]);
   }

   const allVibes = [
     'Relaxing',
     'Adventurous',
     'Creative',
     'Learning/Intellectual',
     'Fun & Playful',
     'Romantic/Intimate'
   ];
   dateIdeaProvider.selectVibe(allVibes[random.nextInt(allVibes.length)]);

   const allBudgets = ['Free/Low Cost', 'Moderate', 'Splurge'];
   dateIdeaProvider
       .selectBudget(allBudgets[random.nextInt(allBudgets.length)]);

   const allTimes = ['1-2 Hours', '2-4 Hours', 'Half Day+'];
   dateIdeaProvider.selectTime(allTimes[random.nextInt(allTimes.length)]);

   Navigator.push(
     context,
     MaterialPageRoute(builder: (_) => const GeneratedDateIdeaScreen()),
   );

   await dateIdeaProvider.generateDateIdea(
     userId: userId,
     coupleId: coupleId,
     context: context,
   );
 }

 @override
 Widget build(BuildContext context) {
   final partnerData = Provider.of<UserProvider>(context).partnerData;

   Widget body;
   if (partnerData == null) {
      // ... (unchanged ConnectWithPartnerCard) ...
     body = Center(
       child: ConnectWithPartnerCard(
         title: 'Connect with your partner to use the calendar!',
         message:
             'Once connected, you can add and view shared events and milestones here.',
         icon: Icons.calendar_today_outlined,
         buttonLabel: 'Connect Now',
         onButtonPressed: () => Navigator.push(
           context,
           MaterialPageRoute(builder: (_) => const ConnectCoupleScreen()),
         ),
       ),
     );
   } else if (coupleId == null) {
     body = const SizedBox.shrink();
   } else {
     // ✨ [MODIFY] Update the create function for CalendarProvider
     body = ChangeNotifierProvider<CalendarProvider>(
       create: (innerContext) { // Use innerContext to avoid conflicts
         final dynamicActionsProvider =
             Provider.of<DynamicActionsProvider>(innerContext, listen: false);
         // ✨ [ADD] Read RhmRepository
         final rhmRepository = innerContext.read<RhmRepository>();
         // ✨ [ADD] Read CalendarRepository (needed by constructor)
         final calendarRepository = innerContext.read<CalendarRepository>();

         // ✨ [MODIFY] Pass rhmRepository and calendarRepository to the constructor
         final provider = CalendarProvider(
           dynamicActionsProvider,
           calendarRepository: calendarRepository, // Pass it here
           rhmRepository: rhmRepository,          // Pass it here
         )
           ..listenToEvents(coupleId!)
           ..listenToMilestones(coupleId!);

         // ... (rest of the create function is unchanged) ...
         final userProvider = Provider.of<UserProvider>(innerContext, listen: false);
         final userId = userProvider.getUserId();
         if (userId != null) provider.setCurrentUserId(userId);

         return provider;
       },
       child: CalendarView(
         // ... (rest of CalendarView parameters are unchanged) ...
         coupleId: coupleId!,
         focusedDay: _focusedDay,
         selectedDay: _selectedDay,
         activeCategory: _activeCategory,
         searchQuery: _searchQuery,
         showSearchBar: _showSearchBar,
         getSortedMilestones: _getSortedMilestones,
         onAddMilestone: _onAddMilestone,
         onEditMilestone: (milestone) =>
             _showEditMilestoneModal(context, milestone),
         onFocusDayChanged: (day) => setState(() => _focusedDay = day),
         onSelectDayChanged: (day) => setState(() {
           _selectedDay = day;
           _focusedDay = day;
         }),
         onCategoryChanged: (category) =>
             setState(() => _activeCategory = category),
         onSearchChanged: (query) => setState(() => _searchQuery = query),
         onSearchToggle: () {
           setState(() {
             _showSearchBar = !_showSearchBar;
             if (!_showSearchBar) {
               _searchQuery = '';
             }
           });
         },
         onShowAll: () => setState(() => _selectedDay = null),
         onCancelReminder: _cancelReminder,
         onGenerateDateIdea: _onGenerateDateIdea,
       ),
     );
   }

   return Scaffold(
     body: FadeTransition(
       opacity: _fadeAnimation,
       child: body,
     ),
   );
 }
}