import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/accounts/account_info_screen.dart';
import 'package:print_helper/admin/accounts/accounts_list.dart';
import 'package:print_helper/admin/client/client_info_screen.dart';
import 'package:print_helper/admin/customers/my_network_screen.dart';
import 'package:print_helper/admin/email/mobile_email_screen.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/admin/settings/settings.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../widgets/spacers.dart';
import '../../widgets/text_widget.dart';
import 'package:print_helper/widgets/toasts.dart';

class CustomDrawer extends StatefulWidget {
  final bool isFromAdmin;
  final bool isFromClient;
  final bool isFromStaff;
  const CustomDrawer({
    super.key,
    required this.isFromAdmin,
    required this.isFromClient,
    required this.isFromStaff,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool billingExpanded = true;

  Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final provider = getCustPro(context);
    final authPro = context.watch<AuthPro>();
    final clipro = context.watch<ClientPro>();

    final role = authPro.user?.roleName;
    final isCustomer = role == "CUSTOMER";
    final isContact = role == "CONTACT"; // Client
    final isStaff = role == "STAFF";
    final isContactOrCustomer = isContact || isCustomer;

    Color sidebarColor;
    Color secondaryColor;

    if (isStaff) {
      sidebarColor = AppColors.white;
      secondaryColor = AppColors.amber;
    } else if (isCustomer || isContact) {
      String? primaryHex = provider.client?.brandingPrimaryColor;
      String? secondaryHex = provider.client?.brandingSecondaryColor;

      if (primaryHex == null || primaryHex.isEmpty) {
        primaryHex = clipro.selectedClient?.primaryColor;
      }
      if (secondaryHex == null || secondaryHex.isEmpty) {
        secondaryHex = clipro.selectedClient?.secondaryColor;
      }

      sidebarColor = (primaryHex != null && primaryHex.isNotEmpty)
          ? hexToColor(primaryHex)
          : Colors.black;

      secondaryColor = (secondaryHex != null && secondaryHex.isNotEmpty)
          ? hexToColor(secondaryHex)
          : AppColors.amber;
    } else {
      sidebarColor = AppColors.white;
      secondaryColor = AppColors.amber;
    }

    final bool isBrandMode = isContactOrCustomer;
    final Color textColor = isBrandMode ? Colors.white : Colors.black;
    final Color iconColor = isBrandMode ? Colors.white : Colors.black;

    final Color logoutBtnBg = isBrandMode ? secondaryColor : Colors.black;
    final Color logoutBtnTxtColor = ThemeData.estimateBrightnessForColor(logoutBtnBg) == Brightness.light ? Colors.black : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sidebarColor,
        borderRadius: BorderRadius.only(topRight: Radius.circular(25.r)),
      ),
      width: 280.w,
      child: Consumer<AuthPro>(
        builder: (context, pro, _) {
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 18.h, 10.w, 10.h),
                  child: Row(
                    children: [
                      TextWidget(
                        text: "Menu",
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: textColor,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.close,
                          size: 26.sp,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: isBrandMode ? Colors.white24 : null),
                (widget.isFromClient || widget.isFromStaff)
                    ? Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            final user = pro.user;
                            if (widget.isFromClient && user?.clientId != null) {
                              navTo(
                                context: context,
                                page: ClientInfoScreen(
                                  clientId: user!.clientId!,
                                ),
                              );
                            } else if (widget.isFromStaff && user != null) {
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
                                page: AccountInfoScreen(
                                  account: account,
                                  isFromAdmin: false,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: isBrandMode
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46.w,
                                  height: 46.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(40.r),
                                    child: ImageWidget(
                                      image:
                                          (pro.user?.image == null ||
                                              pro.user!.image!.isEmpty)
                                          ? Paths.user
                                          : pro.user!.image!,
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Spacers.sbw12(),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextWidget(
                                        text: pro.user?.name ?? "",
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: isBrandMode
                                            ? Colors.white
                                            : const Color(0xff2E1F64),
                                      ),
                                      SizedBox(height: 2.h),
                                      TextWidget(
                                        text: "My Profile",
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isBrandMode
                                            ? Colors.white70
                                            : const Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.only(
                          left: 15.w,
                          top: 5.h,
                          bottom: 12.h,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38.w,
                              height: 38.h,
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40.r),
                                border: Border.all(color: AppColors.grey),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40.r),
                                child: ImageWidget(
                                  image:
                                      (pro.user?.image == null ||
                                          pro.user!.image!.isEmpty)
                                      ? Paths.user
                                      : pro.user!.image!,
                                  width: 36,
                                  height: 35,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Spacers.sbw12(),
                            TextWidget(
                              text: pro.user?.name ?? "",
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: textColor,
                            ),
                          ],
                        ),
                      ),
                _menuItem(
                  icon: Paths.email,
                  title: "Email",
                  isBrandMode: isBrandMode,
                  onTap: () {
                    Navigator.pop(context);
                    navTo(context: context, page: const MobileEmailScreen());
                  },
                ),
                widget.isFromClient
                    ? _menuItem(
                        icon: Paths.customers,
                        title: "My Network",
                        isBrandMode: isBrandMode,
                        onTap: () {
                          Navigator.pop(context);
                          final user = pro.user;
                          if (user?.clientId != null) {
                            navTo(
                              context: context,
                              page: MyNetworkScreen(
                                isFromAdmin: false,
                                id: user!.clientId!,
                                isFromStaff: false,
                                isFromClient: true,
                              ),
                            );
                          }
                        },
                      )
                    : const SizedBox(),
                if (!widget.isFromAdmin)
                  _menuItem(
                    icon: Paths.billingIcon,
                    title: "Payment",
                    isBrandMode: isBrandMode,
                    onTap: () {
                      Navigator.pop(context);
                      showToast(message: "Payment module coming soon");
                    },
                  ),
                widget.isFromAdmin
                    ? _menuItem(
                        icon: Paths.accounts,
                        title: "Accounts",
                        isBrandMode: isBrandMode,
                        onTap: () {
                          navTo(
                            context: context,
                            page: AccountsScreen(
                              isFromAdmin: widget.isFromAdmin,
                            ),
                          );
                        },
                      )
                    : SizedBox(),
                widget.isFromAdmin
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(18.w, 14.h, 10.w, 0),
                        child: GestureDetector(
                          onTap: () => setState(
                            () => billingExpanded = !billingExpanded,
                          ),
                          child: Row(
                            children: [
                              ImageWidget(
                                image: Paths.billingIcon,
                                width: 25.w,
                                color: iconColor,
                              ),
                              Spacers.sbw20(),
                              Expanded(
                                child: TextWidget(
                                  text: "Billing",
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                              Icon(
                                billingExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 24.sp,
                                color: iconColor,
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(),
                if (widget.isFromAdmin)
                  if (billingExpanded) ...[
                    Spacers.sb10(),
                    _subMenuItem(
                      title: "Invoices",
                      icon: Paths.invoices,
                      isBrandMode: isBrandMode,
                      onTap: () {},
                    ),
                    Spacers.sb10(),
                    _subMenuItem(
                      title: "Subscriptions",
                      icon: Paths.subscriptions,
                      isBrandMode: isBrandMode,
                      onTap: () {},
                    ),
                    Spacers.sb10(),
                    _subMenuItem(
                      title: "Orders",
                      icon: Paths.orders,
                      isBrandMode: isBrandMode,
                      onTap: () {},
                    ),
                  ],
                Spacers.sb15(),
                widget.isFromAdmin
                    ? _menuItem(
                        icon: Paths.settings,
                        title: "Settings",
                        isBrandMode: isBrandMode,
                        onTap: () {
                          navTo(context: context, page: SettingsScreen());
                        },
                      )
                    : SizedBox(),
                if (widget.isFromAdmin) Spacers.sb15(),
                Padding(
                  padding: EdgeInsets.only(left: 18.w),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle,
                        size: 25.sp,
                        color: iconColor,
                      ),
                      Spacers.sbw20(),
                      TextWidget(
                        text: "About Us",
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: GestureDetector(
                    onTap: () {
                      final pro = Provider.of<AuthPro>(context, listen: false);
                      pro.logout(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: logoutBtnBg,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ImageWidget(
                            image: Paths.login,
                            width: 22,
                            color: logoutBtnTxtColor,
                          ),
                          Spacers.sbw20(),
                          TextWidget(
                            text: "Logout",
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: logoutBtnTxtColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Spacers.sb25(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _menuItem({
    required String icon,
    required String title,
    required VoidCallback onTap,
    bool isBrandMode = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 8.h, 10.w, 8.h),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            ImageWidget(
              image: icon,
              width: 25.w,
              color: isBrandMode ? Colors.white : Colors.black,
            ),
            Spacers.sbw20(),
            TextWidget(
              text: title,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isBrandMode ? Colors.white : Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _subMenuItem({
    required String title,
    required String icon,
    required VoidCallback onTap,
    bool isBrandMode = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: 55.w, top: 12.h),
        child: Row(
          children: [
            ImageWidget(
              image: icon,
              width: 25,
              color: isBrandMode ? Colors.white : Colors.black,
            ),
            Spacers.sbw20(),
            TextWidget(
              text: title,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isBrandMode ? Colors.white : Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
