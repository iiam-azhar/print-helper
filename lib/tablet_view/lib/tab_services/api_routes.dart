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
  static const String addAccount = 'accounts';
  static const String clients = 'clients';
  static const String customers = 'customers';
  static const String contacts = 'contacts';
  static const String switchUser = 'auth/switch-user';
  static const String twilioNumbers = 'twilio/numbers';
  static const String twilioClientsWithContacts =
      'twilio/clients-with-contacts';
  static const String twilioStaff = 'twilio/staff';
  static const String twilioCredentials = 'twilio/credentials';
  static const String twilioSyncNumbers = 'twilio/sync-numbers';

  static String serverIp = "production.printhelpers.com";
  static String socketHost = serverIp;
  static int socketPort = 443;
  static String appKey = "8xK9mP2nL5qR7vW4jH6tY3bF1sD0gX8e";
  // App Version
  static String appVersion({required String platform, required String build}) =>
      'api/app-version?platform=$platform&build=$build';
}
