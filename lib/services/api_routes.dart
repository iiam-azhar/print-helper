class ApiRoutes {
  ApiRoutes._internal();
  static final ApiRoutes _instance = ApiRoutes._internal();
  factory ApiRoutes() => _instance;

  static const baseUrl = 'https://production.printhelpers.com/api/';

  static const String login = 'auth/login';
  static const String logout = 'auth/logout';
  static const String account = 'accounts';
  static const String language = 'languages';
  static const String accountType = 'account-types';
  static const String custCmpnyType = 'customer-company-types';
  static const String custRank = 'customer-ranks';
  static const String skill = 'skills';
  static const String clientCmpnyType = 'client-company-types';
  static const String rank = 'ranks';
  static const String settings = 'settings';
  static const String fileSettings = 'file-settings';
  static const String fileSettingsStore = 'file-settings/store';
  static const String addAccount = 'accounts';
  static const String clients = 'clients';
  static const String customers = 'customers';
  static const String switchUser = 'auth/switch-user';
  static const String contacts = 'contacts';
  static const String files = 'files';
  static const String filesFilterOptions = 'files/filter/options';
  static const String filesFolders = 'files/folders';
  static const String filesFoldersRename = 'files/folders/rename';
  static const String filesItemsCopy = 'files/items/copy';
  static const String filesItemsMove = 'files/items/move';
  static const String filesItemsRename = 'files/items/rename';
  static const String filesItemsDelete = 'files/items/delete';
  static const String filesShareToChat = 'files/share/chat';
  static const String filesShareToEmail = 'files/share/email';
  static const String twilioNumbers = 'twilio/numbers';
  static const String twilioClientsWithContacts =
      'twilio/clients-with-contacts';
  static const String twilioStaff = 'twilio/staff';
  static const String twilioCredentials = 'twilio/credentials';
  static const String twilioAccessToken = 'chat/voice/token';
  static const String registerDevice = 'calls/register-device';
  static const String unregisterDevice = 'calls/unregister-device';
  static const String callFromNumbers = 'chat/call-from-numbers';
  static const String outboundVoiceUrl = 'calls/outbound-voice-url';
  static String callPopupData(int conversationId) =>
      'chat/call-popup-data?conversation_id=$conversationId';
  static String checkExistingConversationFiles(int conversationId) =>
      'chat/conversations/$conversationId/files/check-existing';
  static String restoreExistingConversationFile(int conversationId) =>
      'chat/conversations/$conversationId/files/restore-existing';
  static String userTwilioNumbers(int userId) =>
      'chat/users/$userId/twilio-numbers';
  static const String initiateCall = 'calls/initiate';
  static const String twilioSyncNumbers = 'twilio/sync-numbers';
  //chat//
  static String serverIp = "production.printhelpers.com";
  static String socketHost = serverIp;
  static int socketPort = 443;
  static String appKey = "8xK9mP2nL5qR7vW4jH6tY3bF1sD0gX8e";
  static const String groupParticipants = 'chat/group-participants';
  // static String localBaseUrl = "http://$serverIp:8000";
  //end//

  // App Version
  static String appVersion({required String platform, required String build}) =>
      'api/app-version?platform=$platform&build=$build';
}
