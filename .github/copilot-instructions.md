# Print Helper - AI Agent Instructions

## Project Overview
Print Helper is a Flutter-based mobile application for managing print service operations with real-time chat, file management, and multi-role user workflows. The app supports role-based access (Admin, Client, Customer, Staff) and integrates real-time communication via Laravel Reverb/Pusher.

**Base URL**: `https://staging.printhelpers.com/api/`  
**WebSocket**: `wss://staging.printhelpers.com:443`

## Architecture

### State Management Pattern
Uses **Provider** pattern with dedicated `ChangeNotifierProvider` classes (suffixed `Pro`):
- `AuthPro` - Authentication and role-based routing
- `ChatPro` - Real-time messaging with Reverb WebSocket integration  
- `UserPro`, `CustomerPro`, `ClientPro`, `AdminPro` - Domain-specific state
- `FilesPro`, `ProjectPro`, `SettingsPro` - Feature-specific state

All providers registered in `main.dart` via `multiProviders()` function.

### Navigation Architecture
- **Global Navigator Key**: `NavigationService.navigatorKey` enables context-free navigation
- **Role-Based Entry Points**: `splash.dart` routes to role-specific bottom bars:
  - `AdminBottomBar` → Admin dashboard
  - `ClientBottomBar` → Client views  
  - `CustBottomBar` → Customer views
  - `StaffBottomBar` → Staff interface
- Use helper: `navTo(context: context, page: SomeScreen(), removeUntil: true)`

### Storage Strategy
- **Secure Storage** (`FlutterSecureStorage`): User credentials, tokens (see `lib/services/db_service.dart`)
- **SharedPreferences**: Session data like `token`, `role_name`, `customer_id`
- Always retrieve token for API calls: `final prefs = await SharedPreferences.getInstance(); final token = prefs.getString("token")`

### Real-Time Communication
Chat uses **Laravel Reverb** (Pusher protocol) via `dart_pusher_channels`:
1. **User Channel** (`private-user.{userId}`): Global notifications, new conversations
2. **Conversation Channel** (`private-conversation.{conversationId}`): Messages, typing indicators, status updates

**Pattern in `ChatPro`**:
```dart
_chatListSocket = ReverbSocketService(
  onConnected: () => debugPrint("✅ Connected"),
  onMessageReceived: (data) => _handleRealtimeChatListMessage(data, userId),
  onTypingReceived: (isTyping) => /* update UI */,
);
```

### API Service Layer
- **Singleton**: `ApiService()` handles all HTTP (GET/POST/PUT/DELETE)
- **Routes**: Centralized in `lib/services/api_routes.dart`
- **Multipart**: Set `multipart: true` for file uploads
- **Headers**: Always include auth token from SharedPreferences

Example:
```dart
final data = await ApiService().postDataToApi(
  api: ApiRoutes.login,
  payload: {"username": email, "password": password},
);
```

## Key Conventions

### UI & Styling
- **Responsive Design**: `ScreenUtilInit` with design size `393x830` - use `.w`, `.h`, `.sp` extensions for all dimensions
- **Colors**: Use `AppColors` constants (`primary`, `secondary`, `scaffold`) from `lib/constants/colors.dart`
- **Fonts**: Google Fonts via `google_fonts` package
- **Loaders**: Use `Loaders.show()` / `Loaders.hide()` (uses global navigator key)
- **Toasts**: Use `showToast(message: "...")` from `lib/widgets/toasts.dart`

### Common Widgets
Reusable widgets in `lib/widgets/`:
- `CustomButton` - Styled buttons
- `TextWidget` - Typography with `MyFontFam` enum support
- `FieldWidget` - Form inputs
- `CustomAppbar` - Consistent app bars
- `ImageWidget` - Network/asset image handling

### Development Helpers
- **SSL Override**: `MyHttpOverrides` allows development with self-signed certs (see `main.dart`)
- **Debug Logging**: Use `printData(title: "Label", data: someVar)` for colored console output (purple) or `printData(title: "Error", data: e, e: true)` for red error logs
- **Console Utils**: `lib/utils/console_util.dart` provides `printData()` and `logData()` with color-coded output

### File Organization
```
lib/
├── admin/           # Admin role screens (accounts, chat, customers, clients, settings)
├── secondPhase/     # Client/Customer role screens (projects, files, profile)
├── auth/            # Login/authentication screens
├── models/          # Data models (*_models.dart)
├── providers/       # State management (*_pro.dart)
├── services/        # API, DB, navigation, notifications, Reverb socket
├── widgets/         # Reusable UI components
├── utils/           # Helpers, transitions, exceptions
└── constants/       # Colors, strings, paths
```

## Critical Workflows

### Authentication Flow
1. `LoginScreen` → `AuthPro.loginUser()` saves token to SharedPreferences and `FlutterSecureStorage`
2. `Splash` checks token → routes to role-specific bottombar
3. `switchUser()` allows admins to impersonate users (updates token)

### Chat Integration
1. Initialize socket: `ChatPro.initChatListSocket(userId: "1", context: context)`
2. Subscribe to conversation: `connectConversationChannel(conversationId: 123)`
3. Send messages: `ChatPro.sendTextMessage(...)` → API + optimistic UI update
4. Handle typing: Emit on text change with throttling (`_typingThrottle`)

### Voice Recording
Uses `record` package via `VoiceRecorderService`:
```dart
await _voiceRecorder.start(); // Starts recording
File file = await _voiceRecorder.stop(); // Returns audio file
```

### File Uploads
Use multipart in `ApiService`:
```dart
ApiService().postDataToApi(
  api: ApiRoutes.someEndpoint,
  multipart: true,
  filePaths: ['/path/to/file'],
  fileNames: ['filename.jpg'],
  fileKeys: ['image'],
  payload: {'key': 'value'},
);
```

### Notifications
- **Local**: `NotificationService.instance.showChatNotification(title: "...", body: "...")`
- Channel: `chat_channel_new` (high priority for Android 13+)
- Initialize in `main.dart`: `await NotificationService.instance.init()`

## Testing & Running

### Build Commands
```bash
# Run app
flutter run

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Analyze code
flutter analyze
```

### Common Issues
1. **SSL Certificate Errors**: Handled by `MyHttpOverrides` in main.dart (dev only)
2. **WebSocket Connection**: Ensure `apiHeaders()` includes valid Bearer token
3. **Navigation Context**: Use `NavigationService.navigatorKey` for context-free navigation
4. **Responsive Sizing**: Always use `.w`, `.h`, `.sp` extensions (ScreenUtil)

## API Patterns

### Standard Response Structure
```dart
{
  "success": true,
  "message": "Success message",
  "data": { /* payload */ }
}
```

Always check `data["success"]` before proceeding.

### Error Handling
Custom exceptions in `lib/utils/custom_exceptions.dart`:
- `FetchDataException` - Network errors
- `ApiNotRespondingException` - Timeouts

## External Dependencies
- **Pusher/Reverb**: Real-time WebSocket (appKey: `8xK9mP2nL5qR7vW4jH6tY3bF1sD0gX8e`)
- **Sqflite**: Local database (via `sqflite_android`)
- **Audio Waveforms**: Voice message visualization
- **Emoji Picker**: Chat emoji support
- **WebView**: In-app browser for external content

## Best Practices
- Never hardcode API URLs; use `ApiRoutes` constants
- Always use provider context helpers: `Provider.of<AuthPro>(context, listen: false)`
- Dispose controllers/subscriptions in `dispose()` methods
- Use `notifyListeners()` after state changes in providers
- Prefix private methods/fields with `_`
- Use `const` constructors for immutable widgets
