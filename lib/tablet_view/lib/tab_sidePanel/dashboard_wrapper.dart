import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/providers/client_pro.dart';
import '../tab_widgets/loaders.dart';
import '../tab_widgets/tab_toasts.dart';
import '../tab_settings/tab_settings.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/navigation_pro.dart';
import '../tab_admin/tab_accounts/tab_accounts_list.dart';
import '../tab_admin/tab_accounts/tab_account_info_screen_tablet.dart';
import '../tab_admin/tab_accounts/tab_staff_payments_screen.dart';
import '../tab_admin/tab_customerView/tab_my_network_screen.dart';
import '../tab_admin/tab_customerView/tab_single_customer.dart';
import '../tab_client/tab_clients_list.dart';
import '../tab_client/tab_client_info_screen.dart';
import '../tab_client/tab_client_billing_screen.dart';
import '../tab_chat/view/tab_chat_wrapper.dart';
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import '../tab_projects/projects.dart';
import '../tab_services/helpers.dart';
import '../tab_files/tab_files_screen.dart';
import '../tab_email/tab_email_screen.dart';
import 'package:print_helper/providers/email_pro.dart';
import 'sidepannel.dart';

class DashboardWrapper extends StatefulWidget {
  final String initialPage;
  final String role;

  const DashboardWrapper({
    super.key,
    this.initialPage = "",
    required this.role,
  });

  @override
  State<DashboardWrapper> createState() => _DashboardWrapperState();
}

class _DashboardWrapperState extends State<DashboardWrapper> {
  String currentPage = "";
  int? selectedClientId;
  AccountModel? selectedAccount;
  DateTime? _lastBackPress;
  bool _backHandledByChild = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialPage.isNotEmpty) {
      currentPage = widget.initialPage;
    } else {
      if (widget.role == "CONTACT") {
        currentPage = "customers";
      } else if (widget.role == "CUSTOMER") {
        currentPage = "customer"; // ✅ NEW PAGE
      } else {
        currentPage = "clients";
      }
    }
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   if (widget.role == "CONTACT") {
    //     final clipro = Provider.of<ClientPro>(context, listen: false);
    //     final auth = getAuthPro(context);

    //     if (clipro.clients.isEmpty) {
    //       await clipro.getClients(ctx: context);
    //     }

    //     debugPrint("${clipro.selectedClient} testtt");
    //     if (clipro.selectedClient == null) {
    //       clipro.selectClientById(auth.user!.clientId);
    //     }
    //   }
    // });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final clipro = Provider.of<ClientPro>(context, listen: false);
      final auth = getAuthPro(context);
      final chatPro = Provider.of<ChatPro>(context, listen: false);

      if (widget.role == "CONTACT") {
        if (clipro.clients.isEmpty) {
          await clipro.getClients(ctx: context);
        }
        // Note: ensureBrandForClient is not available in main ClientPro
        // Branding is managed through API responses in clients data
      }

      // Load conversations to populate unread count badge
      await chatPro.loadConversations(showLoading: false);
      if (mounted) {
        chatPro.initChatListSocket(
          userId: auth.user!.id.toString(),
          context: context,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for global navigation requests (like deep links)
    final navPro = context.watch<NavigationPro>();
    if (navPro.targetPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => currentPage = navPro.targetPage!);
          navPro.clearTargetPage();
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (_backHandledByChild) {
          _backHandledByChild = false;
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          showToast(message: 'Press back again to exit');
        }
      },
      child: Row(
        children: [
          SideBar(
            activePage: currentPage,
            role: widget.role,
            onMenuTap: (page) {
              if (page == "email") {
                final emailPro = context.read<EmailPro>();
                // If already on email page, reset view and refresh
                if (currentPage == "email") {
                  emailPro.selectedFolder = 'inbox';
                  emailPro.selectedFolderId = null;
                  emailPro.selectedMessage = null;
                  emailPro.isAddingAccount = false;
                  emailPro.connectionError = null;
                }
                emailPro.fetchMailData(context);
              }
              setState(() => currentPage = page);
            },
          ),
          Container(width: 1, color: const Color(0xffe6e7e6)),
          Expanded(child: _loadScreen(currentPage)),
        ],
      ),
    );
  }

  Widget _loadScreen(String page) {
    // STAFF ROLE SCREENS
    debugPrint("${widget.role} role");
    if (widget.role == "CUSTOMER") {
      final pro = getAuthPro(context);
      debugPrint(pro.custClientId.toString());
      debugPrint("${pro.custClientId} custclient");
      switch (page) {
        case "chat":
          return const ChatWrapper();
        case "projects":
          return const ProjectsPage();
        case "customer":
          // if (pro.custClientId == 0) {
          //   return const Center(child: CircularProgressIndicator());
          // }
          return SingleCustomer(
            isFromAdmin: false,
            isFromStaff: false,
            isFromClient: false,
            id: pro.custClientId ?? 0,
          );
        case "email":
          return const TabEmailScreen();
        default:
          return const SizedBox();
      }
    }
    if (widget.role == "CONTACT") {
      switch (page) {
        case "chat":
          return const ChatWrapper();
        case "projects":
          return const ProjectsPage();
        case "customers":
          final clientId = getAuthPro(context).user!.clientId;
          debugPrint("$clientId id");
          if (clientId == null) {
            return Center(child: showLoader());
          }
          return TabMyNetworkScreen(
            isFromAdmin: false,
            isFromStaff: false,
            isFromClient: true,
            id: clientId,
            onMenuTap: (newPage) {
              setState(() => currentPage = newPage);
            },
          );

        case "email":
          return const TabEmailScreen();
        default:
          return const SizedBox();
      }
    }
    if (widget.role == "STAFF") {
      switch (page) {
        case "chat":
          return ChatWrapper(); // ChatScreen()
        case "projects":
          return const ProjectsPage();
        case "files":
          return TabFilesScreen(
            onMenuTap: (page) => setState(() => currentPage = page),
            onBackHandled: () => _backHandledByChild = true,
          );
        case "timetrack":
          return const SizedBox(); // TimeTrackScreen()
        case "clients":
          return ClientScreen(
            isFromAdmin: false,
            onMenuTap: (page, id) {
              debugPrint("DASHBOARD SET PAGE=$page CLIENT=$id");
              setState(() {
                currentPage = page;
                selectedClientId = id;
              });
            },
          );
        case "customers":
          return TabMyNetworkScreen(
            isFromAdmin: false,
            isFromStaff: true,
            isFromClient: false,
            id: selectedClientId!,
            onMenuTap: (newPage) {
              setState(() => currentPage = newPage);
            },
          );
        case "client_info":
          if (selectedClientId == null) {
            return Center(child: showLoader());
          }
          return TabClientInfoScreen(
            clientId: selectedClientId!,
            onBack: () {
              setState(() {
                currentPage = "clients";
              });
            },
          );
        case "client_billing":
          if (selectedClientId == null) {
            return Center(child: showLoader());
          }
          return TabClientBillingScreen(
            clientId: selectedClientId!,
            onBack: () {
              setState(() {
                currentPage = "clients";
              });
            },
          );
        case "email":
          return const TabEmailScreen();
        default:
          return const SizedBox();
      }
    }

    // ADMIN ROLE SCREENS
    switch (page) {
      case "chat":
        return ChatWrapper();
      case "projects":
        return const ProjectsPage();
      case "clients":
        return ClientScreen(
          isFromAdmin: true,
          onMenuTap: (page, id) {
            setState(() {
              currentPage = page;
              selectedClientId = id;
            });
          },
        );
      case "customers":
        return TabMyNetworkScreen(
          isFromAdmin: true,
          isFromStaff: false,
          isFromClient: false,
          id: selectedClientId!,
          onMenuTap: (newPage) {
            setState(() => currentPage = newPage);
          },
        );
      case "client_info":
        if (selectedClientId == null) {
          return Center(child: showLoader());
        }
        return TabClientInfoScreen(
          clientId: selectedClientId!,
          onBack: () {
            setState(() {
              currentPage = "clients";
            });
          },
        );
      case "client_billing":
        if (selectedClientId == null) {
          return Center(child: showLoader());
        }
        return TabClientBillingScreen(
          clientId: selectedClientId!,
          onBack: () {
            setState(() {
              currentPage = "clients";
            });
          },
        );
      case "accounts":
        return AccountsScreen(
          onMenuTap: (newPage, account) {
            setState(() {
              currentPage = newPage;
              selectedAccount = account;
            });
          },
        );
      case "account_info":
        if (selectedAccount == null) {
          return Center(child: showLoader());
        }
        return TabAccountInfoTabletScreen(
          account: selectedAccount!,
          onBack: () {
            setState(() {
              currentPage = "accounts";
            });
          },
        );
      case "staff_payments":
        if (selectedAccount == null) {
          return Center(child: showLoader());
        }
        return TabStaffPaymentsScreen(
          account: selectedAccount!,
          onBack: () {
            setState(() {
              currentPage = "accounts";
            });
          },
        );
      case "files":
        return TabFilesScreen(
          onMenuTap: (page) => setState(() => currentPage = page),
          onBackHandled: () => _backHandledByChild = true,
        );
      case "settings":
        return SettingsScreen();
      case "email":
        return const TabEmailScreen();
      default:
        return const SizedBox();
    }
  }
}
