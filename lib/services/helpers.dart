import 'package:flutter/material.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/providers/cust_pro.dart';
import 'package:print_helper/providers/files_pro.dart';
import 'package:print_helper/providers/project_pro.dart';
import 'package:print_helper/providers/setting_pro.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_pro.dart';
import '../admin/chat/provider/chat_pro.dart';
import '../providers/client_pro.dart';
import '../providers/lang_pro.dart';
import '../providers/user_pro.dart';
import '../utils/console_util.dart';
import '../utils/transitions_util.dart';
import '../widgets/toasts.dart';

//
Widget scrollUp(BuildContext context) =>
    SizedBox(height: MediaQuery.of(context).viewInsets.bottom);

Future<void> delayed({VoidCallback? callback, int millisec = 300}) async {
  await Future.delayed(
    Duration(milliseconds: millisec),
    () => callback?.call(),
  );
}

void postFrameCallback(VoidCallback callback) =>
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());

void dismissInputFocus() => FocusManager.instance.primaryFocus?.unfocus();

Future<void> tryLaunchUrl({
  required String url,
  required String message,
  bool inline = false,
}) async {
  final Uri parsedUrl = Uri.parse(url);
  try {
    // For specific schemes, we prefer externalApplication
    final LaunchMode mode =
        (url.startsWith('mailto:') || url.startsWith('tel:'))
        ? LaunchMode.externalApplication
        : (inline
              ? LaunchMode.inAppBrowserView
              : LaunchMode.externalApplication);

    // canLaunchUrl is sometimes unreliable on Android 11+,
    // so we attempt to launch even if it returns false, using try-catch for safety.
    final bool canLaunch = await canLaunchUrl(parsedUrl);
    if (canLaunch) {
      await launchUrl(parsedUrl, mode: mode);
    } else {
      // Direct attempt fallback
      try {
        await launchUrl(parsedUrl, mode: mode);
      } catch (e) {
        showToast(message: message);
      }
    }
  } catch (e) {
    showToast(message: message);
    debugPrint("Error launching URL: $e");
  }
}

// navigation

Future<T?> navTo<T>({
  required BuildContext context,
  required Widget page,
  bool replace = false,
  bool removeUntil = false,
  bool leftRoute = false,
  bool rightRoute = false,
}) async {
  try {
    final route = leftRoute
        ? SlideLeftRoute<T>(page: page)
        : rightRoute
        ? SlideRightRoute<T>(page: page)
        : FadeRoute<T>(page: page);

    if (removeUntil) {
      return await Navigator.pushAndRemoveUntil<T>(
        context,
        route,
        (route) => false,
      );
    } else if (replace) {
      return await Navigator.pushReplacement<T, T>(context, route);
    } else {
      return await Navigator.push<T>(context, route);
    }
  } catch (e) {
    printData(title: 'from navTo', data: '$e', e: true);
    return null;
  }
}

// providers
final getLangPro = getProvider<LangPro>();
final getAuthPro = getProvider<AuthPro>();
final getUserPro = getProvider<UserPro>();
final getCustPro = getProvider<CustomerPro>();
final getProjPro = getProvider<ProjectPro>();
final getFilePro = getProvider<FilesPro>();
final getAdminPro = getProvider<AdminPro>();
final getClientPro = getProvider<ClientPro>();
final getSettingsPro = getProvider<SettingsPro>();
final getChatPro = getProvider<ChatPro>();

bool get isEn => LangPro.instance.locale == Locales.english;

typedef GetProvider<T> = T Function(BuildContext context, {bool listen});

GetProvider<T> getProvider<T>() =>
    (context, {bool listen = false}) => Provider.of<T>(context, listen: listen);
