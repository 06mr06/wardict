# LUGORENA - Word Duel Game Design Document

## 1. Project General Information

### 1.1 Project Name and Description
- **Project Name**: lugorena
- **Full Name**: LUGORENA - Word Duel Game
- **Description**: Flutter-based mobile word duel game application
- **Version**: 1.0.0+1
- **Platforms**: Android, iOS, Web, Windows, Linux, macOS
- **Development Environment**: Flutter SDK >=3.0.0 <4.0.0

### 1.2 Project Structure
- **Main Directory**: `c:/Users/emre.aktas/Downloads/SDK/wardict_skeleton`
- **Package Name**: com.example.wardict_skeleton (for Android)
- **Theme**: Dark theme, seed color: #6C27FF (purple tone)
- **UI Framework**: Material Design 3

## 2. Technical Infrastructure and Dependencies

### 2.1 Flutter and Dart Configuration
- **Flutter Version**: >=3.0.0 <4.0.0
- **Material Design**: Active (uses-material-design: true)
- **Launcher Icons**: Configured with flutter_launcher_icons package
  - Adaptive icon for Android and iOS
  - Background: #3a4a5c
  - Foreground: assets/images/app_icon.png
  - Min SDK: 21 (Android)
  - Active for web as well

### 2.2 Main Dependencies
- **State Management**: provider: ^6.1.2
- **Data Storage**: shared_preferences: ^2.2.2
- **Sharing**: share_plus: ^7.2.2
- **Animation**: confetti: ^0.8.0
- **Firebase Integration**:
  - firebase_core: ^4.3.0
  - firebase_auth: ^6.1.3
  - cloud_firestore: ^6.1.1
  - google_sign_in: ^7.2.0
- **Ads**: google_mobile_ads: ^7.0.0
- **Purchases**: in_app_purchase: ^3.2.3
- **Audio**: audioplayers: ^6.5.1
- **Package Info**: package_info_plus: ^9.0.0

### 2.3 Development Dependencies
- flutter_test: Included with Flutter SDK
- flutter_lints: ^3.0.0
- flutter_launcher_icons: ^0.14.4

### 2.4 Asset Structure
- **Images**: assets/images/
- **Data Files**: assets/data/
- **Sound Files**: assets/sounds/

## 3. Application Architecture

### 3.1 Main Entry Point (main.dart)
- **WidgetsFlutterBinding.ensureInitialized()**: Initializes Flutter context
- **Service Initializations**:
  - FirebaseService.instance.initialize()
  - AdService.instance.initialize()
  - PurchaseService.instance.initialize()
  - WordUsageService.instance.loadUsageData()
- **Main Widget**: WardictApp()

### 3.2 Application Structure (app.dart)
- **MultiProvider Configuration**:
  - GameProvider
  - PracticeProvider
  - Daily123Provider
  - AuthService (singleton)
- **Theme Configuration**:
  - Material 3 active
  - Dark theme
  - Seed color: Color(0xFF6C27FF)
- **Routes**:
  - '/login': LoginScreen
  - '/home': WelcomeScreen
  - '/7030': SeventyThirtyScreen (practice)
  - '/practice-old': GameScreen
  - '/duel': DuelScreen
  - '/profile': ProfileScreen
  - '/shop': ShopScreen

### 3.3 AuthWrapper Widget
- **Auth Status Control**:
  - AuthStatus.initial: Splash screen (with welcome.png image)
  - AuthStatus.authenticated: WelcomeScreen
  - AuthStatus.unauthenticated/error: LoginScreen
- **Splash Screen Features**:
  - Background: #1A3A5C
  - CircularProgressIndicator: #FFD700 (gold color)

## 4. Data Models

### 4.1 Basic Models
- **achievement.dart**: Achievements system
- **answered_entry.dart**: Answered entries
- **cosmetic_item.dart**: Cosmetic items
- **daily_123.dart**: Daily 123 game
- **feed_item.dart**: Feed items
- **friend.dart**: Friend system
- **league.dart**: League system
- **match_history_item.dart**: Match history
- **powerup.dart**: Power-up items
- **practice_session.dart**: Practice sessions
- **premium.dart**: Premium features
- **quest.dart**: Quest system
- **question.dart**: Question structure
  - prompt: Question text
  - options: List of options
  - answerIndex: Correct answer index
  - mode: QuestionMode
  - baseScore: Base score (default 10)
- **question_mode.dart**: Question modes
- **support_ticket.dart**: Support ticket system
- **user_level.dart**: User level

## 5. State Management (Providers)

### 5.1 Provider Structure
- **base_game_provider.dart**: Base game provider
- **daily_123_provider.dart**: Daily 123 game provider
- **game_provider.dart**: Main game provider
- **practice_provider.dart**: Practice provider

## 6. Screens

### 6.1 Main Screen Folders
- **auth/**: Authentication screens
- **friends/**: Friend management
- **game/**: Game screens
- **home/**: Home screen (WelcomeScreen)
- **leaderboard/**: Leaderboards
- **onboarding/**: First-time tutorial
- **profile/**: Profile management
- **shop/**: Shop
- **support/**: Support system

### 6.2 WelcomeScreen Features (welcome_screen.dart)
- **Animations**:
  - Pulse animation (1.0 - 1.08 scale, 1500ms)
  - Coin animation (bounce effect, 400ms)
  - Bell shake animation (shake effect, 500ms)
- **State Management**:
  - _isLoading: Loading state
  - _canPlayDaily123: Permission to play daily game
  - _userProfile: User profile
  - _coins: Coin amount
  - _pendingInvitationsCount: Pending invitations
  - _isPremium: Premium status
  - _selectedFrameId: Selected frame
- **Timers**:
  - _invitationTimer: Check invitations every 30 seconds
- **Lifecycle Management**:
  - AppLifecycleState.resumed: Update coins

## 7. Services

### 7.1 Firebase Services
- **firebase/**: Firebase sub-services
- **auth_service.dart**: Authentication
- **firestore**: Database operations

### 7.2 Game Services
- **achievement_service.dart**: Achievements
- **ad_service.dart**: Ad management
- **daily_123_service.dart**: Daily 123 service
- **feed_service.dart**: Feed management
- **friend_service.dart**: Friend system
- **network_service.dart**: Network operations
- **online_duel_service.dart**: Online duel
- **purchase_service.dart**: Purchases
- **quest_service.dart**: Quests
- **shop_service.dart**: Shop
- **sound_service.dart**: Sound management
- **support_service.dart**: Support
- **user_profile_service.dart**: User profile
- **word_pool_service.dart**: Word pool
- **word_usage_service.dart**: Word usage

## 8. Data Files (Assets/Data)

### 8.1 Word Files
- **words_a1.json**: A1 level words
- **words_a2.json**: A2 level words
- **words_b1.json**: B1 level words
- **words_b2.json**: B2 level words
- **words_c1.json**: C1 level words
- **words_c2.json**: C2 level words
- **a12b12c12.json**: Special word set
- **synonyms_antonyms.json**: Synonyms and antonyms

### 8.2 Question Files
- **questions.json**: General questions
- **sample_questions.json**: Sample questions

## 9. Widget Structure

### 9.1 Widget Folders
- **common/**: Commonly used widgets
- **game/**: Game-specific widgets

## 10. Firebase Integration

### 10.1 Firebase Services
- **Authentication**: Email/Password, Anonymous login
- **Firestore**: Database
- **Google Sign-In**: Login with Google

### 10.2 Security Rules
- Users can read/write their own profiles
- General read permission (auth required)
- Detailed rules for special collections

## 11. Ads and Payment System

### 11.1 Google Mobile Ads
- **Banner Ads**: At screen bottoms
- **Interstitial Ads**: Between games (every 4 games)
- **Rewarded Ads**: Watch ads for rewards
- **Test IDs**: Configured for development

### 11.2 In-App Purchase
- **Coin Packages**:
  - coins_100: 100 Coins
  - coins_500: 500 Coins
  - coins_1500: 1500 Coins
  - coins_5000: 5000 Coins
- **Premium Subscriptions**:
  - premium_monthly: Monthly Premium
  - premium_yearly: Yearly Premium
- **One-time**: remove_ads: Remove Ads

## 12. Release and Distribution

### 12.1 Android Configuration
- **Keystore**: wardict-release.keystore
- **Gradle Signing**: Configured with key.properties
- **Google Services**: google-services.json
- **Proguard**: proguard-rules.pro

### 12.2 Platform Configurations
- **Android**: build.gradle.kts, settings.gradle.kts
- **iOS**: Runner.xcodeproj, Runner.xcworkspace
- **Web**: index.html, manifest.json
- **Windows/Linux/macOS**: CMakeLists.txt, runner files

### 12.3 Release Steps
- Create and secure keystore
- Configure Gradle signing
- Real AdMob IDs
- Google Play Console setup
- In-App Purchase products
- Store listing preparation
- Create APK/AAB
- Upload to Play Store

## 13. Setup Guides

### 13.1 Firebase Setup
- Create project in Firebase Console
- Add Android/iOS/Web application
- Configure Authentication
- Set up Firestore database
- Security rules

### 13.2 Payment and Ads Setup
- Create AdMob account and application
- Define In-App Purchase products
- Configure Test/Prod IDs
- Platform-specific settings

## 14. Development Notes

### 14.1 Code Quality
- Flutter lints active
- Analysis options configured
- UTF-8 analysis available

### 14.2 Build Structure
- Build files organized
- Platform-specific outputs available
- Assets optimized

### 14.3 Testing and Debugging
- Widget test file available
- Debug banner hidden
- Error catching mechanisms

This design document comprehensively summarizes the current state of the LUGORENA project. The project has been developed as a full-featured word duel game application with Firebase integration, ad system, purchase system, and multi-platform support at a professional level.