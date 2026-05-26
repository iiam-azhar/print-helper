class ApiRoutes {
  ApiRoutes._internal();
  static final ApiRoutes _instance = ApiRoutes._internal();
  factory ApiRoutes() => _instance;

  static const baseUrl = 'https://staging.printhelpers.com/api/';

  static const String login = 'auth/login';
  static const String logout = 'auth/logout';
  static const String account = 'accounts';
  static String accountInfo(int id) => 'accounts/$id/info';
  static String onboardingTraining(int id) =>
      'accounts/$id/onboarding-training';
  static String accountChecklistItemToggle(
    int accountId,
    int checklistId,
    int itemIndex,
  ) => 'accounts/$accountId/checklist/$checklistId/$itemIndex/toggle';
  static String accountContractRules(int id) => 'accounts/$id/contract-rules';
  static String signAccountAgreement(int id) => 'accounts/$id/sign-agreement';
  static String signClientAgreement(int id) => 'clients/$id/sign-agreement';
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
  static String clientInfoTabs(int id) => 'clients/$id/info-tabs';
  static String clientMyNetworkTabs(int id) => 'clients/$id/my-network-tabs';
  static String clientAssignedStaff(int id) => 'clients/$id/assigned-staff';
  static String deleteAssignedStaff(int clientId, int staffId) =>
      'clients/$clientId/assigned-staff/$staffId';
  static String clientChecklistItemToggle(
    int clientId,
    int checklistId,
    int itemIndex,
  ) => 'clients/$clientId/checklist/$checklistId/$itemIndex/toggle';
  static const String customers = 'customers';
  static const String switchUser = 'auth/switch-user';
  static const String contacts = 'contacts';
  static const String resetContactPassword = 'reset-contact-password';
  static const String servicesPricing = 'services/pricing';
  static const String contracts = 'contracts';
  static const String contractsSendReminder = 'contracts/send-reminder';
  static const String templates = 'templates';
  static const String rules = 'rules';
  static const String checklists = 'checklists';
  static const String projects = 'projects';
  static const String projectTasks = 'projects/tasks';
  static String updateProject(int projectId) => 'projects/$projectId/update';
  static String createProjectTask(int projectId) => 'projects/$projectId/tasks';
  static String updateProjectTask(int projectId, int taskId) =>
      'projects/$projectId/tasks/$taskId/update';
  static String deleteProjectTask(int projectId, int taskId) =>
      'projects/$projectId/tasks/$taskId';
  static const String projectLabels = 'project-labels';
  static const String projectSections = 'project-sections';
  static String updateProjectSection(int sectionId) =>
      'project-sections/$sectionId/update';
  static const String projectTaskTemplates = 'projects/task-templates';
  static const String projectBlueprintLibrary = 'projects/blueprints/library';
  static const String projectsFilterProjectAssignees =
      'projects/filterproject-assignees';
  static const String projectsFilterTaskAssignees =
      'projects/filtertask-assignees';
  static String projectFilterProjectAssigneesByProject(int projectId) =>
      'projects/$projectId/filterproject-assignees';
  static const String projectsOptionClients = 'projects/options/clients';
  static const String projectsOptionCustomers = 'projects/options/customers';
  static String projectTaskTemplateDetail(int templateId) =>
      'projects/task-templates/$templateId';
  static String deleteProject(int projectId) => 'projects/$projectId';
  static String projectDetails(int projectId) => 'projects/$projectId';
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
  static const String twilioTextTarget = 'chat/twilio/text-target';
  static const String twilioSendText = 'chat/twilio/send-text';
  static const String twilioSendMms = 'chat/twilio/send-mms';
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
  static const String mail = 'mail';
  static const String mailFolders = 'mail/folders';
  static const String mailSend = 'mail/messages/send';
  static const String mailDisconnect = 'mail/accounts/disconnect';
  static const String mailSwitch = 'mail/accounts/switch';
  static String mailDeleteAccount(int accountId) => 'mail/accounts/$accountId';
  static String mailMoveMessages(int folderId) =>
      'mail/folders/$folderId/messages';
  static String mailConnectRedirect(String service) => 'mail/connect/redirect';
  static String mailMessageDetails(String msgId, int accountId) =>
      'mail/messages/$msgId?account_id=$accountId';
  static String mailSearch(String query, int accountId, {String? nextToken}) {
    String url = 'mail/search?q=$query&account_id=$accountId';
    if (nextToken != null && nextToken.isNotEmpty) {
      url += '&next_token=$nextToken';
    }
    return url;
  }

  static String serverIp = "staging.printhelpers.com";
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
