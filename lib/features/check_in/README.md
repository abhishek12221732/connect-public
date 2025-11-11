# Relationship Health Check-in Feature

## Overview

The Relationship Health Check-in feature is a private, periodic reflection tool designed for each partner to thoughtfully assess various aspects of their relationship. It serves as a proactive way for individuals to gauge their feelings and promote relational well-being.

## Features

### Core Functionality
- **Individual Reflection**: Private space for users to introspect about their relationship
- **Proactive Maintenance**: Encourages consistent attention to relationship health
- **Privacy-First**: All personal answers remain strictly private unless explicitly shared
- **Optional Sharing**: Facilitates controlled sharing of insights with partner

### User Journey
1. **Entry Point**: "Start Check-in" button in the Discover tab's Relationship Insights section
2. **Welcome Screen**: Introduces the purpose and privacy policy
3. **Question Flow**: 5-7 questions with different input types (slider, multiple choice, text, yes/no)
4. **Summary & Insights**: Shows personalized insights and sharing options
5. **Optional Actions**: Share insights, reflect in journal, or set reminders

## File Structure

```
lib/features/check_in/
├── models/
│   └── check_in_model.dart          # Data models for check-ins and questions
├── repository/
│   └── check_in_repository.dart     # Database operations and question generation
├── screens/
│   ├── check_in_screen.dart         # Main check-in flow controller
│   ├── check_in_welcome_screen.dart # Welcome and introduction
│   ├── check_in_questions_screen.dart # Question display and navigation
│   ├── check_in_summary_screen.dart # Results and sharing options
│   └── check_in_history_screen.dart # Past check-ins view
├── widgets/
│   ├── question_widget.dart         # Different question input types
│   ├── insight_card.dart           # Display individual insights
│   └── share_insights_dialog.dart  # Insight selection for sharing
└── README.md                       # This documentation
```

## Data Models

### CheckInModel
- `id`: Unique identifier
- `userId`: User who completed the check-in
- `coupleId`: Couple identifier
- `timestamp`: When the check-in was created
- `questions`: List of questions for this session
- `answers`: User's responses
- `isCompleted`: Whether the check-in is finished
- `completedAt`: When the check-in was completed
- `sharedInsights`: List of insights shared with partner
- `reminderSet`: Whether reminders are enabled

### CheckInQuestion
- `id`: Question identifier
- `question`: The question text
- `type`: Question type (slider, multipleChoice, textInput, yesNo)
- `options`: Available choices (for multiple choice)
- `minValue/maxValue`: Range for slider questions
- `placeholder`: Hint text for text input
- `isRequired`: Whether the question is mandatory
- `category`: Question category for organization

## Question Types

### Slider Questions
- Rating scales (1-10)
- Used for satisfaction, connection, stress levels
- Visual slider with value display

### Multiple Choice
- Predefined options
- Radio button selection
- Used for preferences and choices

### Text Input
- Open-ended responses
- Optional questions
- Used for appreciation and reflections

### Yes/No Questions
- Binary responses
- Simple toggle selection
- Used for factual questions

## Privacy & Sharing

### Privacy Features
- All answers are stored privately in user's collection
- Partner only sees completion notification
- No automatic sharing of responses

### Sharing Options
- **Explicit Sharing**: Select specific insights to share
- **Journal Integration**: Redirect to shared journal for manual writing
- **Partner Notification**: Simple completion notification

## Integration Points

### Discover Tab
- Entry point in Relationship Insights section
- Shows last check-in date
- "Start Check-in" button

### Journal Feature
- Shared insights create journal entries
- Option to continue reflection in shared journal

### Notifications
- Partner notification when check-in completed
- Optional reminder scheduling

## Database Structure

### Collections
```
users/{userId}/check_ins/{checkInId}
├── userId: string
├── coupleId: string
├── timestamp: timestamp
├── questions: array
├── answers: map
├── isCompleted: boolean
├── completedAt: timestamp
├── sharedInsights: array
└── reminderSet: boolean
```

### Couple Notifications
```
couples/{coupleId}/notifications/{notificationId}
├── type: "check_in_completed"
├── message: string
├── timestamp: timestamp
├── read: boolean
└── recipientId: string
```

## Usage

### Starting a Check-in
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const CheckInScreen(),
  ),
);
```

### Accessing Provider
```dart
final checkInProvider = Provider.of<CheckInProvider>(context, listen: false);
```

### Creating a Check-in
```dart
final checkInId = await checkInProvider.createCheckIn(userId, coupleId);
```

## Future Enhancements

- **Trend Analysis**: Track relationship health over time
- **Custom Questions**: Allow users to add personal questions
- **Scheduled Reminders**: Automatic check-in prompts
- **Partner Insights**: Compare partner responses (with consent)
- **Relationship Tips**: Personalized advice based on responses
- **Export Data**: Download check-in history
- **Integration**: Connect with other app features (calendar, journal) 