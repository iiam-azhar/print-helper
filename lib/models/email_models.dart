class EmailConnectResponse {
  final bool success;
  final String message;
  final EmailData data;

  EmailConnectResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory EmailConnectResponse.fromJson(Map<String, dynamic> json) {
    return EmailConnectResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: EmailData.fromJson(json['data'] ?? {}),
    );
  }
}

class EmailData {
  final List<EmailAccount> accounts;
  final bool connectRequired;
  final ConnectContext? connectContext;
  final List<EmailMessage> messages;
  final int? selectedAccountId;
  final String? selectedAccountEmail;
  final List<String> currentUserLoggedEmails;
  final List<MailFolder> mailFolders;
  final String? nextToken;
  final String? prevToken;
  final int? totalItems;
  final int? startItem;
  final int? endItem;

  EmailData({
    required this.accounts,
    required this.connectRequired,
    this.connectContext,
    this.messages = const [],
    this.selectedAccountId,
    this.selectedAccountEmail,
    this.currentUserLoggedEmails = const [],
    this.mailFolders = const [],
    this.nextToken,
    this.prevToken,
    this.totalItems,
    this.startItem,
    this.endItem,
  });

  EmailData copyWith({
    List<EmailAccount>? accounts,
    bool? connectRequired,
    ConnectContext? connectContext,
    List<EmailMessage>? messages,
    int? selectedAccountId,
    String? selectedAccountEmail,
    List<String>? currentUserLoggedEmails,
    List<MailFolder>? mailFolders,
    String? nextToken,
    String? prevToken,
    int? totalItems,
    int? startItem,
    int? endItem,
  }) {
    return EmailData(
      accounts: accounts ?? this.accounts,
      connectRequired: connectRequired ?? this.connectRequired,
      connectContext: connectContext ?? this.connectContext,
      messages: messages ?? this.messages,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      selectedAccountEmail: selectedAccountEmail ?? this.selectedAccountEmail,
      currentUserLoggedEmails:
          currentUserLoggedEmails ?? this.currentUserLoggedEmails,
      mailFolders: mailFolders ?? this.mailFolders,
      nextToken: nextToken ?? this.nextToken,
      prevToken: prevToken ?? this.prevToken,
      totalItems: totalItems ?? this.totalItems,
      startItem: startItem ?? this.startItem,
      endItem: endItem ?? this.endItem,
    );
  }

  factory EmailData.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>?;
    final accounts =
        (json['accounts'] as List?)
            ?.map((e) => EmailAccount.fromJson(e))
            .toList() ??
        [];

    // Find the current account from the list if not explicitly provided
    EmailAccount? currentAccount;
    try {
      currentAccount = accounts.firstWhere((a) => a.isCurrent);
    } catch (_) {
      if (accounts.isNotEmpty) {
        currentAccount = accounts.first;
      }
    }

    return EmailData(
      accounts: accounts,
      connectRequired: json['connect_required'] ?? false,
      connectContext: json['connect_context'] != null
          ? ConnectContext.fromJson(json['connect_context'])
          : null,
      messages:
          (json['messages'] as List?)
              ?.map((e) => EmailMessage.fromJson(e))
              .toList() ??
          [],
      selectedAccountId: json['selected_account_id'] ?? currentAccount?.id,
      selectedAccountEmail:
          json['selected_account_email'] ?? currentAccount?.email,
      currentUserLoggedEmails:
          (json['current_user_logged_emails'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mailFolders:
          (json['mail_folders'] as List?)
              ?.map((e) => MailFolder.fromJson(e))
              .toList() ??
          [],
      nextToken:
          pagination?['next_token'] ??
          pagination?['nextToken'] ??
          pagination?['nextPageToken'] ??
          json['next_token'],
      prevToken:
          pagination?['prev_token'] ??
          pagination?['prevToken'] ??
          pagination?['prevPageToken'] ??
          json['prev_token'],
      totalItems: pagination?['total_items'] ?? pagination?['totalItems'],
      startItem: pagination?['start_item'] ?? pagination?['startItem'],
      endItem: pagination?['end_item'] ?? pagination?['endItem'],
    );
  }
}

class MailFolder {
  final int id;
  final String name;

  MailFolder({required this.id, required this.name});

  factory MailFolder.fromJson(Map<String, dynamic> json) {
    return MailFolder(id: json['id'] ?? 0, name: json['name'] ?? '');
  }
}

class EmailAccount {
  final int id;
  final String email;
  final String serviceType;
  final bool isCurrent;
  final bool isLoggedIn;
  final bool needsProviderLogin;

  EmailAccount({
    required this.id,
    required this.email,
    required this.serviceType,
    required this.isCurrent,
    required this.isLoggedIn,
    required this.needsProviderLogin,
  });

  factory EmailAccount.fromJson(Map<String, dynamic> json) {
    return EmailAccount(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      serviceType: json['service_type'] ?? '',
      isCurrent: json['is_current'] ?? false,
      isLoggedIn: json['is_logged_in'] ?? false,
      needsProviderLogin: json['needs_provider_login'] ?? false,
    );
  }
}

class ConnectContext {
  final List<EmailService> services;
  final List<String> suggestedEmails;

  ConnectContext({required this.services, required this.suggestedEmails});

  factory ConnectContext.fromJson(Map<String, dynamic> json) {
    return ConnectContext(
      services:
          (json['services'] as List?)
              ?.map((e) => EmailService.fromJson(e))
              .toList() ??
          [],
      suggestedEmails:
          (json['suggested_emails'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class EmailService {
  final String service;
  final String title;
  final bool enabled;

  EmailService({
    required this.service,
    required this.title,
    required this.enabled,
  });

  factory EmailService.fromJson(Map<String, dynamic> json) {
    return EmailService(
      service: json['service'] ?? '',
      title: json['title'] ?? '',
      enabled: json['enabled'] ?? false,
    );
  }
}

class EmailMessageResponse {
  final bool success;
  final String message;
  final EmailMessage? data;

  EmailMessageResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory EmailMessageResponse.fromJson(Map<String, dynamic> json) {
    return EmailMessageResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? EmailMessage.fromJson(json['data']) : null,
    );
  }
}

class EmailMessage {
  final String id;
  final String subject;
  final String from;
  final String fromEmail;
  final String to;
  final String body;
  final String bodySnippet;
  final String date;
  final List<Map<String, dynamic>> attachments;
  final bool isUnread;

  EmailMessage({
    required this.id,
    required this.subject,
    required this.from,
    this.fromEmail = '',
    required this.to,
    required this.body,
    required this.bodySnippet,
    required this.date,
    this.attachments = const [],
    this.isUnread = false,
  });

  factory EmailMessage.fromJson(Map<String, dynamic> json) {
    // Handle 'from' being either a String or a Map
    String fromStr = '';
    String fromEmail = '';
    if (json['from'] is Map) {
      final name = json['from']['name'] ?? '';
      final address = json['from']['address'] ?? '';
      fromStr = name.isNotEmpty ? name : address;
      fromEmail = address.isNotEmpty ? address : fromStr;
    } else {
      fromStr = json['from']?.toString() ?? '';
      fromEmail = fromStr;
    }

    // Parse unread state
    final unreadFlag = json['unread'] == true;
    final sysLabels =
        (json['sysLabels'] as List?)
            ?.map((e) => e.toString().toLowerCase().trim())
            .toList() ??
        const <String>[];
    final hasUnreadLabel = sysLabels.contains('unread');
    final isUnread = unreadFlag || hasUnreadLabel;

    return EmailMessage(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      from: fromStr,
      fromEmail: fromEmail,
      to: json['to']?.toString() ?? '',
      body: json['body'] ?? '',
      bodySnippet: json['bodySnippet'] ?? json['body'] ?? '',
      date: json['receivedAt'] ?? json['date'] ?? '',
      attachments:
          (json['attachments'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      isUnread: isUnread,
    );
  }
}
