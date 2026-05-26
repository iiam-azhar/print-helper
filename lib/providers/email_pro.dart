import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/email_models.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../utils/console_util.dart';
import 'auth_pro.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/loaders.dart';
import '../widgets/toasts.dart';

class EmailPro extends ChangeNotifier {
  EmailData? emailData;
  bool isLoading = false;
  String? connectionError;
  bool isMessageLoading = false;
  bool isAddingAccount = false;
  EmailMessage? selectedMessage;

  String selectedFolder = 'inbox'; // Default folder
  int? selectedFolderId;

  void setFolder(BuildContext context, String folder, {int? folderId}) {
    selectedFolder = folder;
    selectedFolderId = folderId;
    selectedMessage = null; // Clear detail view when switching folders
    fetchMailData(context); // Fetch the list for the new folder
  }

  Future<void> fetchMailData(BuildContext context, {String? nextToken}) async {
    isLoading = true;
    notifyListeners();

    try {
      final auth = Provider.of<AuthPro>(context, listen: false);

      String apiFolder = selectedFolder;
      // If it's a custom folder, the API expects 'folder=inbox' along with the folder_id
      if (![
        'inbox',
        'sent',
        'drafts',
        'outbox',
      ].contains(apiFolder.toLowerCase())) {
        apiFolder = 'inbox';
      }

      String apiUrl = '${ApiRoutes.mail}?folder=$apiFolder';
      if (selectedFolderId != null) {
        apiUrl += '&folder_id=$selectedFolderId';
      }
      if (nextToken != null && nextToken.isNotEmpty) {
        apiUrl += '&next_token=$nextToken';
      }

      printData(title: "FETCH MAIL DATA URL:", data: apiUrl);

      final data = await ApiService().getDataFromApi(
        api: apiUrl,
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      printData(title: "MAIL DATA RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        emailData = EmailData.fromJson(data["data"]);
      }
    } catch (e) {
      printData(title: "FETCH MAIL DATA ERROR:", data: e, e: true);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createFolder(BuildContext context, String folderName) async {
    if (emailData?.selectedAccountId == null) {
      showToast(message: "No account selected");
      return;
    }

    // Optimistic Update: Add the folder to the list immediately
    if (emailData != null) {
      final updatedFolders = List<MailFolder>.from(emailData!.mailFolders);
      // Use a temporary ID (-1) for the optimistic entry
      updatedFolders.add(MailFolder(id: -1, name: folderName));
      emailData = emailData!.copyWith(mailFolders: updatedFolders);
      notifyListeners();
    }

    try {
      final auth = Provider.of<AuthPro>(context, listen: false);
      final body = {
        "name": folderName,
        "account_id": emailData!.selectedAccountId,
      };

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.mailFolders,
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        payload: body,
      );

      printData(title: "CREATE FOLDER RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        showToast(message: "Folder created successfully");
        fetchMailData(context); // Refresh folder list to get real ID
      } else {
        // Revert on failure
        fetchMailData(context);
        showToast(message: data?["message"] ?? "Failed to create folder");
      }
    } catch (e) {
      printData(title: "CREATE FOLDER ERROR:", data: e, e: true);
      // Revert on error
      fetchMailData(context);
      showToast(message: "Something went wrong");
    }
  }

  Future<void> moveMessages(
    BuildContext context,
    int destinationFolderId,
    List<String> messageIds,
  ) async {
    if (emailData?.selectedAccountId == null || messageIds.isEmpty) return;

    Loaders.show();
    try {
      final auth = Provider.of<AuthPro>(context, listen: false);
      final body = {
        "message_ids": messageIds,
        "account_id": emailData!.selectedAccountId,
      };

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.mailMoveMessages(destinationFolderId),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        payload: body,
      );

      printData(title: "MOVE MESSAGES RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        showToast(message: "Messages moved successfully");
        fetchMailData(context); // Refresh folder list
      } else {
        showToast(message: data?["message"] ?? "Failed to move messages");
      }
    } catch (e) {
      printData(title: "MOVE MESSAGES ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> sendMail(
    BuildContext context, {
    required String to,
    String cc = '',
    String bcc = '',
    required String subject,
    required String body,
    String inReplyToId = '',
    List<Map<String, String>> attachments = const [],
  }) async {
    if (emailData?.selectedAccountId == null) {
      showToast(message: "No account selected");
      return false;
    }

    Loaders.show();
    try {
      final auth = Provider.of<AuthPro>(context, listen: false);

      final payload = {
        "action": "send",
        "account_id": emailData!.selectedAccountId.toString(),
        "to": to,
        if (cc.isNotEmpty) "cc": cc,
        if (bcc.isNotEmpty) "bcc": bcc,
        "subject": subject,
        "body": body,
      };
      final filePaths = attachments
          .map((e) => e['path'] ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
      final fileNames = attachments
          .map((e) => e['name'] ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      printData(title: "SEND MAIL REQUEST PAYLOAD:", data: payload);
      if (filePaths.isNotEmpty) {
        printData(
          title: "SEND MAIL ATTACHMENTS:",
          data: {"filePaths": filePaths, "fileNames": fileNames},
        );
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiRoutes.baseUrl}${ApiRoutes.mailSend}'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer ${auth.token}',
        'Accept': 'application/json',
      });

      request.fields['action'] = 'send';
      request.fields['account_id'] = emailData!.selectedAccountId.toString();
      request.fields['to'] = to;
      request.fields['subject'] = subject;
      request.fields['body'] = body;

      if (cc.isNotEmpty) request.fields['cc'] = cc;
      if (bcc.isNotEmpty) request.fields['bcc'] = bcc;
      if (inReplyToId.isNotEmpty) {
        request.fields['in_reply_to_id'] = inReplyToId;
      }

      for (int i = 0; i < filePaths.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath('attachments[]', filePaths[i]),
        );
      }

      printData(title: "SEND MAIL REQUEST:", data: request.fields);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = null;
      }

      printData(title: "SEND MAIL RESPONSE:", data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data != null && data["success"] == true) {
          showToast(message: "Mail sent successfully");
          fetchMailData(
            context,
          ); // Refresh to potentially show new outbox/sent items
          return true;
        } else {
          showToast(message: data?["message"] ?? "Failed to send mail");
          return false;
        }
      } else {
        showToast(message: data?["message"] ?? "Error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      printData(title: "SEND MAIL ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> saveDraft(
    BuildContext context, {
    String to = '',
    String cc = '',
    String bcc = '',
    String subject = '',
    String body = '',
    List<Map<String, String>> attachments = const [],
  }) async {
    if (emailData?.selectedAccountId == null) {
      showToast(message: "No account selected");
      return false;
    }

    Loaders.show();
    try {
      final auth = Provider.of<AuthPro>(context, listen: false);

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiRoutes.baseUrl}${ApiRoutes.mailSend}'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer ${auth.token}',
        'Accept': 'application/json',
      });

      request.fields['action'] = 'draft';
      request.fields['account_id'] = emailData!.selectedAccountId.toString();
      request.fields['to'] = to;
      request.fields['subject'] = subject;
      request.fields['body'] = body;

      if (cc.isNotEmpty) request.fields['cc'] = cc;
      if (bcc.isNotEmpty) request.fields['bcc'] = bcc;

      final filePaths = attachments
          .map((e) => e['path'] ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
      for (int i = 0; i < filePaths.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath('attachments[]', filePaths[i]),
        );
      }

      printData(title: "SAVE DRAFT REQUEST:", data: request.fields);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = null;
      }

      printData(title: "SAVE DRAFT RESPONSE:", data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data != null && data["success"] == true) {
          showToast(message: "Draft saved");
          fetchMailData(context);
          return true;
        } else {
          showToast(message: data?["message"] ?? "Failed to save draft");
          return false;
        }
      } else {
        showToast(message: data?["message"] ?? "Error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      printData(title: "SAVE DRAFT ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<void> connectService(
    BuildContext context,
    String service, {
    String? email,
  }) async {
    Loaders.show();
    try {
      final auth = Provider.of<AuthPro>(context, listen: false);

      final Map<String, String> queryParams = {
        'service': service,
        'app_return_url': 'printhelper://email',
      };

      if (email != null && email.isNotEmpty) {
        queryParams['email'] = email;
      }

      final String apiPath = Uri(
        path: 'mail/connect/redirect',
        queryParameters: queryParams,
      ).toString();

      final data = await ApiService().getDataFromApi(
        api: apiPath,
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      printData(title: "CONNECT SERVICE RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        final authUrl = data["data"]["authorization_url"];
        if (authUrl != null) {
          await launchUrl(
            Uri.parse(authUrl),
            mode: LaunchMode.externalApplication,
          );
          // When the user returns from the browser, refresh the state to see if they are connected
          isAddingAccount = false;
          fetchMailData(context);
        } else {
          showToast(message: "Could not launch authorization URL");
        }
      } else {
        showToast(
          message: data?["message"] ?? "Failed to get authorization URL",
        );
      }
    } catch (e) {
      printData(title: "CONNECT SERVICE ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
    } finally {
      Loaders.hide();
    }
  }

  Future<void> disconnectAccount(BuildContext context, int accountId) async {
    Loaders.show();
    try {
      final auth = Provider.of<AuthPro>(context, listen: false);
      final body = {"account_id": accountId};

      printData(title: "DISCONNECT ACCOUNT PAYLOAD:", data: body);

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.mailDisconnect,
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        payload: body,
      );

      printData(title: "DISCONNECT ACCOUNT RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        showToast(message: "Account disconnected successfully");
        fetchMailData(context); // Refresh to show connection screen
      } else {
        showToast(message: data?["message"] ?? "Failed to disconnect account");
      }
    } catch (e) {
      printData(title: "DISCONNECT ACCOUNT ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
    } finally {
      Loaders.hide();
    }
  }

  Future<void> switchAccount(BuildContext context, int accountId) async {
    Loaders.show();
    try {
      final auth = Provider.of<AuthPro>(context, listen: false);
      final body = {"account_id": accountId};

      printData(title: "SWITCH ACCOUNT PAYLOAD:", data: body);

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.mailSwitch,
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        payload: body,
      );

      printData(title: "SWITCH ACCOUNT RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        connectionError = null; // Clear error on success
        isAddingAccount = false;
        showToast(message: "Switched account successfully");
        fetchMailData(context); // Refresh to show the new account's data
      } else {
        final errorMessage = data?["message"]?.toString() ?? "";
        final accountIdError =
            data?["errors"]?["account_id"]?[0]?.toString() ?? "";

        if (errorMessage.contains("Validation failed") &&
            accountIdError.contains("sign in")) {
          connectionError = accountIdError; // Set error to show in UI
          notifyListeners();
        } else {
          showToast(
            message: errorMessage.isNotEmpty
                ? errorMessage
                : "Failed to switch account",
          );
        }
      }
    } catch (e) {
      printData(title: "SWITCH ACCOUNT ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
    } finally {
      Loaders.hide();
    }
  }

  Future<void> deleteAccount(BuildContext context, int accountId) async {
    Loaders.show();
    try {
      final auth = Provider.of<AuthPro>(context, listen: false);

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.mailDeleteAccount(accountId),
        isDelete: true,
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      printData(title: "DELETE ACCOUNT RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        showToast(message: "Account deleted successfully");
        selectedMessage = null; // Clear detail view
        fetchMailData(context); // Refresh to reflect changes
      } else {
        showToast(message: data?["message"] ?? "Failed to delete account");
      }
    } catch (e) {
      printData(title: "DELETE ACCOUNT ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
    } finally {
      Loaders.hide();
    }
  }

  void reset() {
    emailData = null;
    isLoading = false;
    notifyListeners();
  }

  void clearSelectedMessage() {
    selectedMessage = null;
    notifyListeners();
  }

  Future<void> fetchMessageDetails(
    BuildContext context,
    String msgId,
    int accountId,
  ) async {
    isMessageLoading = true;
    notifyListeners();

    try {
      final auth = Provider.of<AuthPro>(context, listen: false);
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.mailMessageDetails(msgId, accountId),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      printData(title: "MESSAGE DETAILS RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        var msgData = data["data"];
        if (msgData != null && msgData["message"] != null) {
          msgData = msgData["message"];
        }
        selectedMessage = EmailMessage.fromJson(msgData);
      } else {
        showToast(message: data?["message"] ?? "Failed to load message");
      }
    } catch (e) {
      printData(title: "FETCH MESSAGE DETAILS ERROR:", data: e, e: true);
      showToast(message: "Failed to load message");
    } finally {
      isMessageLoading = false;
      notifyListeners();
    }
  }

  String lastSearchQuery = '';

  Future<void> searchMail(
    BuildContext context,
    String query, {
    String? nextToken,
  }) async {
    if (query.trim().isEmpty && nextToken == null) {
      lastSearchQuery = '';
      fetchMailData(context);
      return;
    }

    if (nextToken == null) {
      lastSearchQuery = query.trim();
    }

    isLoading = true;
    notifyListeners();

    try {
      final auth = Provider.of<AuthPro>(context, listen: false);
      final accountId = emailData?.selectedAccountId;

      if (accountId == null) {
        showToast(message: "No account selected");
        return;
      }

      final apiUrl = ApiRoutes.mailSearch(
        lastSearchQuery,
        accountId,
        nextToken: nextToken,
      );
      printData(title: "SEARCH MAIL URL:", data: apiUrl);

      final data = await ApiService().getDataFromApi(
        api: apiUrl,
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      printData(title: "SEARCH MAIL RESPONSE:", data: data);

      if (data != null && data["success"] == true) {
        emailData = EmailData.fromJson(data["data"]);
      } else {
        showToast(message: data?["message"] ?? "Search failed");
      }
    } catch (e) {
      printData(title: "SEARCH MAIL ERROR:", data: e, e: true);
      showToast(message: "Search failed");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void refresh() => notifyListeners();
}
