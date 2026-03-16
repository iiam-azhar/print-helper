import 'dart:convert';

import 'package:flutter/material.dart';

import '../constants/strings.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../utils/console_util.dart';
import '../widgets/loaders.dart';
import '../widgets/toasts.dart';

class UserPro extends ChangeNotifier {
  User _user = User();
  User get user => _user;

  Map<String, String> get headers {
    return {
      'Content-type': 'application/json',
      'Authorization': user.isLoggedIn ? 'Bearer ${user.token}' : '',
    };
  }

  Map<String, String> get multiHeader {
    return {
      'Content-type': 'multipart/form-data',
      'Authorization': 'Bearer ${user.token}',
    };
  }

  Future<void> setUserData(User user) async {
    await DbService.setUserData(user);
  }

  Future<void> getUserData() async {
    _user = await DbService.getUserData();
    notifyListeners();
  }

  Future<void> updateUserData(UpdatedUser updatedUser) async {
    _user = await DbService.updateUserData(updatedUser);
    notifyListeners();
  }

  Future<void> deleteUserData() async {
    _user = await DbService.deleteUserData();
    notifyListeners();
  }

  Future<void> getProfile(BuildContext ctx) async {
    Loaders.show();
    try {
      final data = await ApiService().getDataFromApi(
        api: 'ApiRoutes.getUser',
        headers: headers,
      );

      if (data is Map && data.isNotEmpty) {
        final updatedUser = updatedUserFromJson(data);
        await updateUserData(updatedUser);
      } else {
        showToast(message: data['message'] ?? AppStrings.error);
      }
    } catch (e, st) {
      printData(title: 'from getProfile', data: '$e,$st', e: true);
      showToast(message: AppStrings.error);
    } finally {
      Loaders.hide();
    }
  }

  // Future<String?>

  Future<bool> changePassword({
    required String pass,
    required String newPass,
    required String confirmPass,
    required BuildContext ctx,
  }) async {
    Loaders.show();
    try {
      final body = {
        'password': pass,
        'newPassword': newPass,
        'confirmPassword': confirmPass,
      };

      printData(title: 'changePassword', data: 'body: $body');

      final data = await ApiService().postDataToApi(
        api: 'ApiRoutes.changePass',
        headers: headers,
        payload: json.encode(body),
      );

      if ('${data['message']}'.toLowerCase().contains('password updated')) {
        showToast(message: AppStrings.success);
        return true;
      } else {
        final msg = data['message'];
        final errors = data['errors'];
        final hasError = errors is List && errors.isNotEmpty;
        final message = msg ?? (hasError ? errors[0] : AppStrings.error);
        showToast(message: message);
        return false;
      }
    } catch (e, st) {
      showToast(message: AppStrings.error);
      printData(title: 'changePassword error', data: '$e\n$st', e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<void> deleteAccount(BuildContext ctx) async {
    Loaders.show();
    try {
      final data = await ApiService().postDataToApi(
        isDelete: true,
        api: 'ApiRoutes.deleteAccount',
        headers: headers,
      );

      if (data['status'] == 'success') {
        showToast(message: data['message'] ?? AppStrings.success);
        await deleteUserData();
        await DbService.deleteRemMe();
        if (ctx.mounted) {
          // navTo(context: ctx, removeUntil: true, page: const LoginPage());
        }
      } else {
        showToast(message: data['message'] ?? AppStrings.error);
      }
    } catch (e) {
      printData(title: 'from deleteAccount', data: '$e', e: true);
      showToast(message: AppStrings.error);
    } finally {
      Loaders.hide();
    }
  }
}
