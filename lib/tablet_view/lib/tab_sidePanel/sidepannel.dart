import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/providers/auth_pro.dart';
import '../tab_constants/colors.dart';
import '../tab_constants/paths.dart';

// shared providers instead of tablet-specific versions
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/providers/cust_pro.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_text_widget.dart';
import 'package:provider/provider.dart';
// use mobile chat provider
import 'package:print_helper/admin/chat/provider/chat_pro.dart';
import 'sidebar_shimmer.dart';
import '../tab_services/helpers.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/tablet_view/lib/tab_admin/tab_accounts/tab_account_info_screen_tablet.dart';
import 'package:print_helper/tablet_view/lib/tab_widgets/tab_toasts.dart';
import 'package:print_helper/tablet_view/lib/tab_client/tab_client_info_screen.dart';

class SideBar extends StatefulWidget {
  final String activePage;
  final Function(String)? onMenuTap;
  final String role;
  const SideBar({
    super.key,
    required this.activePage,
    this.onMenuTap,
    required this.role,
  });

  @override
  State<SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  bool get isContact => widget.role == "CONTACT";
  bool get isStaff => widget.role == "STAFF";
  bool get isAdmin => widget.role == "ADMIN";
  bool get isCustomer => widget.role == "CUSTOMER";
  bool get isContactOrCustomer =>
      widget.role == "CONTACT" || widget.role == "CUSTOMER";

  String buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return Paths.logoWhite;
    if (path.startsWith('http')) {
      return path; // already full URL
    }
    return "https://13.222.158.20/storage/$path";
  }

  @override
  Widget build(BuildContext context) {
    // final staff = authPro.user?.roleName == "STAFF";
    return Consumer<ClientPro>(
      builder: (context, clipro, _) {
        return Consumer<CustomerPro>(
          builder: (context, custPro, _) {
            final bool showBrandLoader =
                (isCustomer &&
                (custPro.client == null ||
                    custPro.client!.brandingPrimaryColor.isEmpty));

            if (showBrandLoader) {
              // return Container(
              //   width: MediaQuery.of(context).size.width < 1050 ? 80 : 300,
              //   color: Colors.black, // 🔥 IMPORTANT (visible background)
              //   child: const Center(
              //     child: CircularProgressIndicator(
              //       color: Colors.white,
              //       strokeWidth: 2.5,
              //     ),
              //   ),
              // );
              bool isCollapsed = MediaQuery.of(context).size.width < 1050;
              return SideBarShimmer(collapsed: isCollapsed);
            }
            debugPrint("==== SIDEBAR DEBUG ====");
            debugPrint("ROLE = ${widget.role}");
            debugPrint("selectedClient = ${clipro.selectedClient?.id}");
            debugPrint("brandPrimary = ${clipro.selectedClient?.primaryColor}");
            debugPrint(
              "brandSecondary = ${clipro.selectedClient?.secondaryColor}",
            );
            debugPrint("=======================");
            return LayoutBuilder(
              builder: (context, constraints) {
                bool isCollapsed = MediaQuery.of(context).size.width < 1050;
                double width = isCollapsed ? 80 : 255;

                Color sidebarColor;
                Color secondaryColor;
                // final brandLogo = clipro.selectedClient?.brandLogo;

                // final custPro = context.read<CustomerPro>();

                String? brandLogo;
                if (isCustomer) {
                  brandLogo = buildImageUrl(custPro.client?.brandingLogo);
                  debugPrint("customer $brandLogo");
                } else if (isContact) {
                  brandLogo = buildImageUrl(clipro.selectedClient?.logo);
                  debugPrint("client $brandLogo");
                } else {
                  brandLogo = null;
                }
                if (isStaff) {
                  sidebarColor = AppColors.white;
                  secondaryColor = AppColors.amber;
                }
                //  CUSTOMER MUST COME BEFORE CONTACT
                else if (isCustomer) {
                  final primaryHex = custPro.client?.brandingPrimaryColor;
                  final secondaryHex = custPro.client?.brandingSecondaryColor;

                  sidebarColor = (primaryHex is String && primaryHex.isNotEmpty)
                      ? hexToColor(primaryHex)
                      : Colors.black;

                  secondaryColor =
                      (secondaryHex is String && secondaryHex.isNotEmpty)
                      ? hexToColor(secondaryHex)
                      : AppColors.amber;
                }
                // CONTACT only when NOT customer
                else if (isContact) {
                  final brandPrimeHex = clipro.selectedClient?.primaryColor;
                  final brandSecondHex = clipro.selectedClient?.secondaryColor;

                  sidebarColor =
                      (brandPrimeHex != null && brandPrimeHex.isNotEmpty)
                      ? hexToColor(brandPrimeHex)
                      : Colors.black;

                  secondaryColor =
                      (brandSecondHex != null && brandSecondHex.isNotEmpty)
                      ? hexToColor(brandSecondHex)
                      : AppColors.amber;
                } else {
                  sidebarColor = Colors.black;
                  secondaryColor = AppColors.amber;
                }
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: width,
                  height: double.infinity,
                  color: sidebarColor,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Column(
                            crossAxisAlignment: isCollapsed
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCollapsed ? 0 : 20,
                                ),
                                child: ImageWidget(
                                  image:
                                      brandLogo != null && brandLogo.isNotEmpty
                                      ? brandLogo
                                      : isStaff
                                      ? Paths.logoBlck
                                      : Paths.logoWhite,
                                  width: isCollapsed ? 60 : 140,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 30),
                              Consumer<ChatPro>(
                                builder: (context, chatPro, _) {
                                  return _menuItem(
                                    icon: Paths.chat,
                                    title: "Chat",
                                    page: "chat",
                                    collapsed: isCollapsed,
                                    active: widget.activePage == "chat",
                                    clipro: clipro,
                                    badge: chatPro.totalUnreadCount,
                                  );
                                },
                              ),
                              _menuItem(
                                icon: Paths.task,
                                title: "Projects",
                                page: "projects",
                                collapsed: isCollapsed,
                                active: widget.activePage == "projects",
                                clipro: clipro,
                              ),
                              _menuItem(
                                icon: Paths.foldr,
                                title: "Files",
                                page: "files",
                                collapsed: isCollapsed,
                                active: widget.activePage == "files",
                                clipro: clipro,
                              ),
                              _menuItem(
                                icon: Paths.email,
                                title: "Email",
                                page: "email",
                                collapsed: isCollapsed,
                                active: widget.activePage == "email",
                                clipro: clipro,
                              ),

                              _menuItem(
                                icon: isContact
                                    ? Paths.customers
                                    : Paths.clientprofile,
                                title: isContact
                                    ? "Customers"
                                    : isCustomer
                                    ? "Customer"
                                    : "Clients",
                                page: isContact
                                    ? "customers"
                                    : isCustomer
                                    ? "customer"
                                    : "clients",
                                collapsed: isCollapsed,
                                active: isContact
                                    ? widget.activePage == "customers"
                                    : isCustomer
                                    ? widget.activePage == "customer"
                                    : widget.activePage == "clients",
                                clipro: clipro,
                              ),
                              if (isAdmin)
                                _menuItem(
                                  icon: Paths.accounts,
                                  title: "Accounts",
                                  page: "accounts",
                                  collapsed: isCollapsed,
                                  active: widget.activePage == "accounts",
                                  clipro: clipro,
                                ),
                              if (!isAdmin)
                                _menuItem(
                                  icon: Paths.billingIcon,
                                  title: "Payment",
                                  page: "payment",
                                  collapsed: isCollapsed,
                                  active: widget.activePage == "payment",
                                  clipro: clipro,
                                ),

                              if (isAdmin)
                                _menuItem(
                                  icon: Paths.settings,
                                  title: "Settings",
                                  page: "settings",
                                  collapsed: isCollapsed,
                                  active: widget.activePage == "settings",
                                ),

                              // _menuItem(
                              //   icon: Paths.login,
                              //   title: "Logout",
                              //   page: "",
                              //   collapsed: isCollapsed,
                              //   // active: widget.activePage == "settings",
                              // ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final auth = context.read<AuthPro>();
                          final user = auth.user;
                          if (user == null) return;

                          if (isContact && user.clientId != null) {
                            navTo(
                              context: context,
                              page: TabClientInfoScreen(
                                clientId: user.clientId!,
                              ),
                            );
                          } else if (isStaff) {
                            final account = AccountModel(
                              id: user.id,
                              clientId: user.clientId,
                              isPrimary: user.isPrimary,
                              name: user.name,
                              lastName: user.lastName,
                              email: user.email,
                              username: user.username,
                              emailVerifiedAt: null,
                              image: user.image,
                              imageUrl: user.image,
                              language: user.language,
                              role: user.role,
                              accountType: user.accountType,
                              status: user.status,
                              createdAt: user.createdAt,
                              updatedAt: "",
                              createdBy: null,
                              updatedBy: null,
                              customerId: user.customerId,
                              deletedAt: null,
                              roleName: user.roleName,
                              createdByName: "",
                              phones: [],
                              emails: [],
                              creator: null,
                              staffDetails: null,
                            );
                            navTo(
                              context: context,
                              page: TabAccountInfoTabletScreen(
                                account: account,
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: isCollapsed ? 0 : 20,
                            bottom: 8,
                          ),
                          child: Consumer<AuthPro>(
                            builder: (context, auth, _) {
                              final name = auth.user?.name;
                              return Row(
                                mainAxisAlignment: isCollapsed
                                    ? MainAxisAlignment.center
                                    : MainAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(40),
                                    child: ImageWidget(
                                      image:
                                          (auth.user?.image?.isNotEmpty ??
                                              false)
                                          ? auth.user!.image!
                                          : Paths.user,
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (!isCollapsed) ...[
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextWidget(
                                            text:
                                                (name != null &&
                                                    name.isNotEmpty)
                                                ? name
                                                : "My Account",
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.none,
                                          ),
                                          const SizedBox(height: 2),
                                          const TextWidget(
                                            text: "My Profile",
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            decoration: TextDecoration.none,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: GestureDetector(
                          onTap: () {
                            final authPro = Provider.of<AuthPro>(
                              context,
                              listen: false,
                            );
                            authPro.logout(context);
                            debugPrint("Logout tapped");
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isContactOrCustomer
                                  ? secondaryColor
                                  : AppColors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ImageWidget(
                                  image: Paths.login,
                                  width: 22,
                                  color: AppColors.black,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Logout",
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _menuItem({
    required String icon,
    required String title,
    required String page,
    ClientPro? clipro,
    bool active = false,
    bool collapsed = false,
    int badge = 0,
  }) {
    final custPro = Provider.of<CustomerPro>(context, listen: false);
    String? secondaryHex;
    if (isCustomer) {
      secondaryHex = custPro.client?.brandingSecondaryColor;
    } else {
      secondaryHex = clipro?.selectedClient?.secondaryColor;
    }
    Color activeBgColor;
    if (secondaryHex != null && secondaryHex.isNotEmpty) {
      activeBgColor = hexToColor(secondaryHex);
    } else {
      activeBgColor = AppColors.primary;
    }
    return GestureDetector(
      onTap: () {
        if (page == "payment") {
          showToast(message: "Payment module coming soon");
          return;
        }
        if (widget.onMenuTap != null) widget.onMenuTap!(page);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : 20,
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: active ? activeBgColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: ImageWidget(
                    image: icon,
                    width: collapsed ? 26 : 24,
                    // color: active ? Colors.black : Colors.white,
                    color: isStaff || isContact || isCustomer
                        ? Colors.white
                        : Colors.white,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: TextWidget(
                          text: badge > 99 ? '99+' : badge.toString(),
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (!collapsed) ...[
              const SizedBox(width: 15),
              Expanded(
                child: TextWidget(
                  text: title,
                  color: isStaff || isContact || isCustomer
                      ? AppColors.white
                      : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }



  Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
