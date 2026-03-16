import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../admin/adminBottombar/admin_bottombar.dart';
import '../admin/client/bottombar/client_bottombar.dart';
import '../admin/customers/bottombar/cust_bottombar.dart';
import '../admin/staff/bottombar/staff_bottombar.dart';
import '../auth/login_screen.dart';
import '../models/auth_models.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../services/call_device_service.dart';
import '../services/helpers.dart';
import '../widgets/loaders.dart';
import '../widgets/toasts.dart';
import '../utils/console_util.dart';
import 'package:print_helper/tablet_view/lib/tab_auth/tab_login_screen.dart';
import 'package:print_helper/tablet_view/lib/tab_sidePanel/dashboard_wrapper.dart';
import '../admin/chat/provider/chat_pro.dart';

class AuthPro extends ChangeNotifier {
  Map<String, String> get headers => {'Content-type': 'application/json'};
  int? custClientId;
  UserModel? user;
  String token = "";
  Future<bool> loginUser({
    required String email,
    required String password,
    required BuildContext ctx,
  }) async {
    Loaders.show();
    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.login,
        payload: {"username": email, "password": password},
      );
      printData(title: "LOGIN RESPONSE:", data: data);
      if (data["success"] == true) {
        final loginModel = LoginResponseModel.fromJson(data);
        await saveUserData(loginModel);
        user = loginModel.user;
        token = loginModel.token;
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("token", loginModel.token);
        prefs.setString("role_name", loginModel.user.roleName);
        prefs.setString("cust_client_id", user!.custClientId.toString());
        prefs.setInt("customer_id", user!.customerId);
        printData(title: "Customer Client ID:", data: user!.custClientId);
        printData(title: "Customer ID:", data: user!.customerId);
        await CallDeviceService.bootstrap(forceRegister: true);
        notifyListeners();
        showToast(message: "Login successful");
        return true;
      } else {
        showToast(message: data["message"] ?? "Invalid credentials");
        return false;
      }
    } catch (e) {
      printData(title: "LOGIN ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<void> switchUser({
    required int userId,
    required dynamic context,
  }) async {
    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final data = await ApiService().postDataToApi(
        api: "${ApiRoutes.switchUser}/$userId",
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "SWITCH USER RESPONSE:", data: data);
      if (data["success"] == true) {
        final user = UserModel.fromJson(data["data"]["user"]);
        final token = data["data"]["token"];
        this.user = user;
        this.token = token;
        printData(title: "USER clientId:", data: user.custClientId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        await prefs.setString("role_name", user.roleName);
        await prefs.setString("user", jsonEncode(user.toJson()));
        await prefs.setInt("cust_client_id", user.custClientId);
        await CallDeviceService.bootstrap(forceRegister: true);
        notifyListeners();

        // 🔄 CRITICAL: Reset chat provider to disconnect old sockets and clear state
        final chatPro = Provider.of<ChatPro>(context, listen: false);
        chatPro.resetForUserSwitch();

        _navigateByRole(user.roleName, context);
      } else {
        showToast(message: data["message"] ?? "Switch failed");
      }
    } catch (e) {
      printData(title: "SWITCH USER ERROR:", data: e, e: true);
      showToast(message: "Something went wrong");
    } finally {
      Loaders.hide();
    }
  }

  Future<void> loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final userStr = prefs.getString("user");
    final savedToken = prefs.getString("token");
    int? savedCustClientId;
    final rawCustId = prefs.get("cust_client_id");
    if (rawCustId is int) {
      savedCustClientId = rawCustId;
    } else if (rawCustId is String) {
      savedCustClientId = int.tryParse(rawCustId);
    }
    if (userStr != null && savedToken != null) {
      user = UserModel.fromJson(jsonDecode(userStr));
      token = savedToken;
      custClientId = savedCustClientId;
      notifyListeners();
    }
  }

  Future<void> saveUserData(LoginResponseModel login) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("user", jsonEncode(login.user.toJson()));
    await prefs.setString("token", login.token);
    await prefs.setString("token_type", login.tokenType);
    await prefs.setInt("user_id", login.user.id);
    await prefs.setString("name", login.user.name);
    await prefs.setString("last_name", login.user.lastName);
    await prefs.setString("email", login.user.email);
    await prefs.setString("role_name", login.user.roleName);
    await prefs.setString("phone", login.user.phone);
    await prefs.setString("image", login.user.image.toString());
  }

  void _navigateByRole(String? role, BuildContext context) {
    bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    switch (role) {
      case "ADMIN":
        navTo(
          context: context,
          page: isTablet
              ? DashboardWrapper(role: "ADMIN")
              : AdminBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;
      case "CONTACT":
        navTo(
          context: context,
          page: isTablet
              ? DashboardWrapper(role: "CONTACT")
              : ClientBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;
      case "STAFF":
        navTo(
          context: context,
          page: isTablet
              ? DashboardWrapper(role: "STAFF")
              : StaffBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;
      case "CUSTOMER":
        navTo(
          context: context,
          page: isTablet
              ? DashboardWrapper(role: "CUSTOMER")
              : CustBottomBar(pageNum: 0),
          removeUntil: true,
        );
        break;
      default:
        navTo(
          context: context,
          page: isTablet ? const TabLoginScreen() : const LoginScreen(),
          removeUntil: true,
        );
    }
  }

  Future<void> logout(dynamic context) async {
    // 1. Show confirmation dialog
    final shouldLogout = await _showLogoutConfirmation(context);
    if (!shouldLogout) {
      printData(title: "LOGOUT", data: "User cancelled logout");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString("token") ?? "";
    Loaders.show();
    try {
      // 2. Disconnect chat sockets FIRST to stop receiving messages/calls
      try {
        final chatPro = Provider.of<ChatPro>(context, listen: false);
        chatPro.disconnectConversationSocket();
        chatPro.disconnectChatListSocket();
        printData(title: "LOGOUT", data: "Chat sockets disconnected");
      } catch (e) {
        printData(
          title: "LOGOUT",
          data: "Error disconnecting chat: $e",
          e: true,
        );
      }

      // 3. Unregister from Twilio and backend BEFORE clearing token
      await CallDeviceService.unregister();

      // 4. Call logout API
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.logout,
        headers: {"Authorization": "Bearer $storedToken"},
      );
      if (data["success"] == true && data["message"] == 'Logout successful') {
        showToast(message: data["message"] ?? "Logout successful");
      } else {
        showToast(message: data["message"]);
      }
    } catch (e) {
      printData(title: "LOGOUT API ERROR:", data: e, e: true);
    }
    Loaders.hide();
    // 5. Clear all user data from SharedPreferences
    await prefs.remove("token");
    await prefs.remove("role_name");
    await prefs.remove("user_id");
    await prefs.remove("name");
    await prefs.remove("email");
    await prefs.remove("customer_id");
    await prefs.remove("cust_client_id");
    // 6. Clear FCM token to prevent notifications reaching after logout
    await prefs.remove("fcm_token");
    // 7. Clear any cached device registration state
    await prefs.remove("registered_fcm_token");
    await prefs.remove("registered_user_id");
    await prefs.remove("registered_device_id");
    user = null;
    token = "";
    notifyListeners();
    bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    navTo(
      context: context,
      page: isTablet ? const TabLoginScreen() : const LoginScreen(),
      removeUntil: true,
    );
  }

  /// Shows a confirmation dialog before logout
  Future<bool> _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  String forgetMail = "";
  Future<bool> forgetPassword({
    required String email,
    required dynamic context,
  }) async {
    try {
      Loaders.show();
      final data = await ApiService().postDataToApi(
        api: 'auth/forgot-password',
        payload: {"email": email},
      );
      printData(title: "forgetPassword response:", data: data);
      final bool isSuccess =
          data['success'] == true ||
          data['message'] == "OTP has been sent to your email address.";
      if (isSuccess) {
        forgetMail = email;
        showToast(message: data["message"]);
        return true;
      } else {
        showToast(message: data["message"] ?? 'Something went wrong');
        return false;
      }
    } catch (e) {
      printData(title: "FromForgetPassword error:", data: e, e: true);
      showToast(message: 'Something went wrong');
      return false;
    } finally {
      Loaders.hide();
      notifyListeners();
    }
  }

  bool validateOtp = false;
  String resetToken = '';
  Future<bool> validateOtpApi({
    required String email,
    required BuildContext context,
    required String otp,
  }) async {
    bool isValid = false;
    try {
      Loaders.show();
      validateOtp = true;
      notifyListeners();
      var data = await ApiService().postDataToApi(
        api: 'auth/verify-otp?',
        payload: {"email": email, "otp": otp},
      );
      printData(title: "validateOtpApi Response:", data: data);
      if (data['message'] ==
              "OTP verified successfully. You can now reset your password." &&
          data['success'] == true) {
        isValid = true;
        showToast(message: "Otp Verified");
      } else {
        showToast(message: data["message"]);
      }
    } catch (e) {
      printData(title: "validateOtpApi Error:", data: e, e: true);
      showToast(message: "Something went wrong, please try again");
    } finally {
      validateOtp = false;
      Loaders.hide();
      notifyListeners();
    }
    return isValid;
  }

  Future<bool> resetPass({
    required String password,
    required String otp,
    required BuildContext context,
  }) async {
    bool isVerify = false;
    try {
      Loaders.show();
      var data = await ApiService().postDataToApi(
        api: 'auth/reset-password?',
        payload: {
          "otp": otp,
          "password": password,
          "password_confirmation": password,
        },
      );
      printData(title: "resetPass Response:", data: data);
      if (data['message'] == "Password has been reset successfully." &&
          data['success'] == true) {
        isVerify = true;
      } else {
        showToast(message: data["message"]);
      }
    } catch (e) {
      printData(title: "resetPass Error:", data: e, e: true);
      showToast(message: "Something went wrong, please try again");
    } finally {
      Loaders.hide();
    }
    return isVerify;
  }
}
