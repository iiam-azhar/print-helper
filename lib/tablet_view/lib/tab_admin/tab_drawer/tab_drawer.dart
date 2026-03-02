import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:print_helper/providers/auth_pro.dart';
import '../tab_accounts/tab_accounts_list.dart';
import '../../tab_services/helpers.dart';
import '../../tab_settings/tab_settings.dart';
import '../../tab_widgets/tab_image_widget.dart';
import 'package:provider/provider.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool billingExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topRight: Radius.circular(25)),
      ),
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 10, 10),
              child: Row(
                children: [
                  const TextWidget(
                    text: "Menu",
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 26),
                  ),
                ],
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.only(left: 15, top: 5, bottom: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: ImageWidget(
                      image:
                          'https://i.pinimg.com/474x/60/5b/9b/605b9b86a82dd0147ed8aa612381326f.jpg',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Spacers.sbw12(),
                  const TextWidget(
                    text: "My Account",
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ],
              ),
            ),

            _menuItem(icon: Paths.timeIcon, title: "Time Track", onTap: () {}),

            _menuItem(
              icon: Paths.accounts,
              title: "Accounts",
              onTap: () {
                navTo(context: context, page: AccountsScreen());
              },
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
              child: GestureDetector(
                onTap: () => setState(() => billingExpanded = !billingExpanded),
                child: Row(
                  children: [
                    ImageWidget(image: Paths.billingIcon, width: 25),
                    Spacers.sbw20(),
                    const Expanded(
                      child: TextWidget(
                        text: "Billing",
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      billingExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),

            if (billingExpanded) ...[
              Spacers.sb10(),
              _subMenuItem(
                title: "Invoices",
                icon: Paths.invoices,
                onTap: () {},
              ),
              Spacers.sb10(),
              _subMenuItem(
                title: "Subscriptions",
                icon: Paths.subscriptions,
                onTap: () {},
              ),
              Spacers.sb10(),
              _subMenuItem(title: "Orders", icon: Paths.orders, onTap: () {}),
            ],

            Spacers.sb15(),

            _menuItem(
              icon: Paths.settings,
              title: "Settings",
              onTap: () {
                navTo(context: context, page: const SettingsScreen());
              },
            ),

            Spacers.sb15(),

            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.info_circle, size: 25),
                  Spacers.sbw20(),
                  const TextWidget(
                    text: "About Us",
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
            ),

            const Spacer(),

            Container(
              margin: const EdgeInsets.only(left: 18),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  topLeft: Radius.circular(25),
                ),
                color: AppColors.primary,
              ),
              child: _menuItem(
                icon: Paths.login,
                title: "Logout",
                onTap: () {
                  final authPro = Provider.of<AuthPro>(context, listen: false);
                  authPro.logout(context);
                  print("1111111111111");
                },
              ),
            ),

            Spacers.sb25(),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required String icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            ImageWidget(image: icon, width: 25),
            Spacers.sbw20(),
            TextWidget(text: title, fontSize: 14, fontWeight: FontWeight.w500),
          ],
        ),
      ),
    );
  }

  Widget _subMenuItem({
    required String title,
    required String icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 55, top: 12),
        child: Row(
          children: [
            ImageWidget(image: icon, width: 25, color: Colors.black),
            Spacers.sbw20(),
            TextWidget(text: title, fontSize: 14, fontWeight: FontWeight.w400),
          ],
        ),
      ),
    );
  }
}
