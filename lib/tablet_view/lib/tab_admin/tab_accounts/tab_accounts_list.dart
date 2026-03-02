import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/admin_pro.dart';
import '../../tab_widgets/tab_image_widget.dart';

import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_toasts.dart';
import 'package:print_helper/models/accounts_models.dart';
import '../../tab_utils/formatter.dart';
import '../../tab_services/helpers.dart';
import 'tab_add_account.dart';
import 'tab_edit_account.dart';
import '../tab_filter/tab_filter_screen.dart';



class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     final pro = Provider.of<AdminPro>(context, listen: false);
  //     pro.getAccounts(ctx: context);
  //     _scrollController.addListener(() {
  //       if (_scrollController.position.pixels >=
  //           _scrollController.position.maxScrollExtent - 200) {
  //         if (!pro.isLoadingMore && pro.currentPage < pro.lastPage) {
  //           pro.getAccounts(
  //             ctx: context,
  //             page: pro.currentPage + 1,
  //             loadMore: true,
  //           );
  //         }
  //       }
  //     });
  //   });
  // }
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<AdminPro>(context, listen: false);
      // Load first page initially
      pro.getAccounts(ctx: context, page: 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: true,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.asset(
                Paths.chatbg,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(.3),
              ),
            ),
          ),
          SafeArea(
            child: Consumer<AdminPro>(
              builder: (context, provider, _) {
                if (provider.accountsLoad && provider.accounts.isEmpty) {
                  return Center(child: showLoader());
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        itemCount: provider.accounts.length,
                        itemBuilder: (context, index) {
                          if (index == provider.accounts.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(child: showLoader()),
                            );
                          }
                          final item = provider.accounts[index];
                          return _accountCard(item, context, provider);
                        },
                      ),
                    ),
                    _buildPagination(provider),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      elevation: 2,
      automaticallyImplyLeading: false,
      title: Consumer<AdminPro>(
        builder: (context, provider, child) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ImageWidget(image: Paths.accounts, width: 28),
              Spacers.sbw12(),
              TextWidget(
                                            text: "Accounts (${provider.totalAccounts})",                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFam: MyFontFam.poppins,
                color: const Color(0XFF414345),
              ),
            ],
          );
        },
      ),
      actions: [
        GestureDetector(
          onTap: () {
            _openRightSideSheet(context, AccountAddContent());
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const TextWidget(
              text: "+ Account",
              fontWeight: FontWeight.w500,
              fontSize: 11,
              fontFam: MyFontFam.poppins,
              color: Color(0XFF414345),
            ),
          ),
        ),
        Spacers.sbw10(),
        Consumer<AdminPro>(
          builder: (context, pro, _) {
            final count = pro.appliedFilterCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    _openRightSideSheet(
                      context,
                      FilterSheet(
                        initialFilters: pro.accountFilters,
                        isFromStaff: true,
                        isFromClient: false,
                      ),
                    ).then((filters) {
                      if (filters != null && filters is Map<String, dynamic>) {
                        pro.applyAccountFilters(filters, context);
                      }
                    });
                  },
                  icon: ImageWidget(image: Paths.filter, width: 20),
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _accountCard(
    AccountModel item,
    BuildContext context,
    AdminPro provider,
  ) {
    final bool isAdmin = item.roleName.toLowerCase() == 'admin';
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: isAdmin ? Border.all(color: Colors.black87, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topRow(item, provider),
          Divider(color: AppColors.grey.withValues(alpha: .5), thickness: 1.2),
          Spacers.sb10(),
          Spacers.sb5(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.staffDetails!.languages.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextWidget(
                        text: p,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(width: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.phones.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextWidget(
                        text: "${p.type}: ${p.number}",
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.emails.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextWidget(
                        text: e, // or e['mail']
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                width: 250,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 10),
                    _iconButtonTwo(Paths.email),
                    _iconButtonTwo(Paths.call),
                    _iconButtonTwo(Paths.chat),
                  ],
                ),
              ),
            ],
          ),
          // TextWidget(
          //   text: item.contact.phConnect.email,
          //   fontWeight: FontWeight.w500,
          //   fontSize: 11,
          // ),
          // Spacers.sb8(),
          // TextWidget(
          //   text: "Personal No.",
          //   fontWeight: FontWeight.w500,
          //   fontSize: 12,
          // ),
          // TextWidget(
          //   text: item.contact.personal.phone,
          //   fontWeight: FontWeight.bold,
          //   fontSize: 11,
          // ),
          // TextWidget(
          //   text: item.contact.personal.email,
          //   fontWeight: FontWeight.w500,
          //   fontSize: 11,
          // ),
          // Spacers.sb15(),
          // Center(
          //   child: Container(
          //     width: 180,
          //     decoration: BoxDecoration(
          //       border: Border.all(
          //         color: AppColors.grey.withValues(alpha: .5),
          //         width: 1.5,
          //       ),
          //       borderRadius: BorderRadius.circular(18),
          //     ),
          //     child: Column(
          //       children: [
          //         Row(
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             _iconButton(Paths.email),
          //             _iconButton(Paths.call),
          //             _iconButton(Paths.chat),
          //           ],
          //         ),
          //         // Center(
          //         //   child: TextWidget(
          //         //     text: item,
          //         //     fontWeight: FontWeight.w500,
          //         //     fontSize: 11,
          //         //   ),
          //         // ),
          //         Spacers.sb2(),
          //         Spacers.sb2(),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _topRow(AccountModel item, AdminPro provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: AppColors.grey),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: ImageWidget(
              image: item.imageUrl == null || item.imageUrl.toString().isEmpty
                  ? Paths.user
                  : item.imageUrl.toString(),
              width: 45,
              height: 45,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Spacers.sbw12(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextWidget(
                  text: '${item.name} ${item.lastName}',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: AppColors.black,
                ),
              ),

              Expanded(
                child: TextWidget(
                  text: "4 Projects  •  1222 Files",
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: TextWidget(
                  text: Frmtr.frmtDate(
                    date: item.createdAt,
                    outForm: 'MM/dd/yy - hh:mma',
                  ),
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(
                width: 250,
                child: Row(
                  children: [
                    SizedBox(
                      width: 55,
                      height: 33,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: Switch(
                          value: item.status,
                          activeTrackColor: Color(0XFF00a650),
                          activeThumbColor: AppColors.white,
                          onChanged: (val) =>
                              provider.toggleStatus(item.id, val, context),
                        ),
                      ),
                    ),
                    Spacers.sbw20(),
                    _iconButton(
                      icon: Paths.login,
                      onTap: () async {
                        // Navigator.of(context, rootNavigator: true).pop();
                        final authPro = Provider.of<AuthPro>(
                          context,
                          listen: false,
                        );
                        await authPro.switchUser(
                          userId: item.id,
                          context: context,
                        );
                      },
                    ),
                    _iconButton(
                      icon: Paths.edit,
                      onTap: () {
                        _openRightSideSheet(
                          context,
                          EditAccount(account: item),
                        );
                      },
                    ),
                    _iconButton(
                      icon: Paths.delete,
                      onTap: () {
                        _confirmDelete(context, item.id);
                      },
                    ),

                    // Builder(
                    //   builder: (iconCtx) {
                    //     return GestureDetector(
                    //       onTap: () {
                    //         final RenderBox box =
                    //             iconCtx.findRenderObject() as RenderBox;
                    //         final Offset pos = box.localToGlobal(Offset.zero);
                    //         final Size size = box.size;
                    //         showGeneralDialog(
                    //           context: context,
                    //           barrierDismissible: true,
                    //           barrierLabel: "PopupMenu",
                    //           barrierColor: Colors.black.withValues(
                    //             alpha: 0.15,
                    //           ),
                    //           transitionDuration: Duration(milliseconds: 250),
                    //           transitionBuilder: (_, animation, _, child) {
                    //             return FadeTransition(
                    //               opacity: CurvedAnimation(
                    //                 parent: animation,
                    //                 curve: Curves.easeOut,
                    //               ),
                    //               child: SlideTransition(
                    //                 position:
                    //                     Tween<Offset>(
                    //                       begin: Offset(0, -0.05),
                    //                       end: Offset.zero,
                    //                     ).animate(
                    //                       CurvedAnimation(
                    //                         parent: animation,
                    //                         curve: Curves.easeOut,
                    //                       ),
                    //                     ),
                    //                 child: child,
                    //               ),
                    //             );
                    //           },
                    //           pageBuilder: (_, _, _) {
                    //             return GestureDetector(
                    //               onTap: () => Navigator.pop(context),
                    //               child: Stack(
                    //                 children: [
                    //                   Positioned(
                    //                     top: pos.dy + size.height + 6,
                    //                     left: pos.dx - 110,
                    //                     child: GestureDetector(
                    //                       onTap: () {},
                    //                       child: Container(
                    //                         padding: EdgeInsets.symmetric(
                    //                           horizontal: 14,
                    //                           vertical: 12,
                    //                         ),
                    //                         decoration: BoxDecoration(
                    //                           color: Colors.white.withValues(
                    //                             alpha: 0.95,
                    //                           ),
                    //                           borderRadius:
                    //                               BorderRadius.circular(16),
                    //                           boxShadow: [
                    //                             BoxShadow(
                    //                               color: Colors.black
                    //                                   .withValues(alpha: 0.15),
                    //                               blurRadius: 18,
                    //                               offset: Offset(0, 6),
                    //                             ),
                    //                           ],
                    //                         ),

                    //                         child: Row(
                    //                           mainAxisSize: MainAxisSize.min,
                    //                           children: [
                    //                             _popupIcon(
                    //                               icon: Paths.login,
                    //                               label: "Login",
                    //                               onTap: () async {
                    //                                 Navigator.pop(context);
                    //                                 // Navigator.of(context, rootNavigator: true).pop();
                    //                                 final authPro =
                    //                                     Provider.of<AuthPro>(
                    //                                       context,
                    //                                       listen: false,
                    //                                     );
                    //                                 await authPro.switchUser(
                    //                                   userId: item.id,
                    //                                   context: context,
                    //                                 );
                    //                               },
                    //                             ),
                    //                             Spacers.sbw20(),
                    //                             _popupIcon(
                    //                               icon: Paths.edit,
                    //                               label: "Edit",
                    //                               onTap: () {
                    //                                 Navigator.pop(context);
                    //                                 // showModalBottomSheet(
                    //                                 //   context: context,
                    //                                 //   isScrollControlled: true,
                    //                                 //   backgroundColor:
                    //                                 //       Colors.transparent,
                    //                                 //   builder: (_) {
                    //                                 //     return FractionallySizedBox(
                    //                                 //       heightFactor: 0.98,
                    //                                 //       child: EditAccount(
                    //                                 //         account: item,
                    //                                 //       ),
                    //                                 //     );
                    //                                 //   },
                    //                                 // );

                    //                                 _openRightSideSheet(
                    //                                   context,
                    //                                   EditAccount(
                    //                                     account: item,
                    //                                   ),
                    //                                 );
                    //                               },
                    //                             ),

                    //                             Spacers.sbw20(),
                    //                             _popupIcon(
                    //                               icon: Paths.delete,
                    //                               label: "Delete",
                    //                               onTap: () {
                    //                                 _confirmDelete(
                    //                                   context,
                    //                                   item.id,
                    //                                 );
                    //                               },
                    //                             ),
                    //                           ],
                    //                         ),
                    //                       ),
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //             );
                    //           },
                    //         );
                    //       },
                    //       child: Container(
                    //         width: 35,
                    //         height: 33,
                    //         decoration: BoxDecoration(
                    //           color: Colors.white,
                    //           borderRadius: BorderRadius.circular(13),
                    //           border: Border.all(color: Colors.grey, width: 1),
                    //         ),
                    //         child: Icon(Icons.more_vert, size: 20),
                    //       ),
                    //     );
                    //   },
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Spacers.sbw10(),
      ],
    );
  }

  void _confirmDelete(dynamic context, int id) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: TextWidget(
            text: "Delete Account",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
          content: TextWidget(
            text: "Are you sure you want to delete this account?",
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TextWidget(
                text: "Cancel",
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                decoration: TextDecoration.none,
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // close AlertDialog
                // Navigator.pop(context); // close showGeneralDialog popup
                final pro = getAdminPro(context);
                bool success = await pro.deleteAccount(id, context);
                if (success) {
                  showToast(message: "Account deleted successfully");
                  pro.getAccounts(ctx: context);
                } else {
                  showToast(message: "Failed to delete account");
                }
              },
              child: const TextWidget(
                text: "Delete",
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.red,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPagination(AdminPro provider) {
    if (provider.lastPage <= 1) return const SizedBox.shrink();

    final int currentPage = provider.currentPage;
    final int lastPage = provider.lastPage;

    // Generate visible page numbers (1,2,3,...,last)
    List<int> pages = [];

    if (lastPage <= 7) {
      // If few pages, show all
      pages = List.generate(lastPage, (i) => i + 1);
    } else {
      // Many pages → dynamic sliding window with ellipsis
      pages.add(1);

      if (currentPage > 3) pages.add(-1); // -1 = "..."

      int start = (currentPage - 1).clamp(2, lastPage - 2);
      int end = (currentPage + 1).clamp(2, lastPage - 1);

      for (int i = start; i <= end; i++) {
        pages.add(i);
      }

      if (currentPage < lastPage - 2) pages.add(-1); // -1 = "..."

      pages.add(lastPage);
    }

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// FIRST <<
            _pageCircle(
              label: "«",
              enabled: currentPage > 1,
              onTap: () => provider.getAccounts(ctx: context, page: 1),
            ),

            /// PREVIOUS <
            _pageCircle(
              label: "<",
              enabled: currentPage > 1,
              onTap: () =>
                  provider.getAccounts(ctx: context, page: currentPage - 1),
            ),

            const SizedBox(width: 8),

            /// PAGE NUMBERS + ELLIPSIS
            ...pages.map((p) {
              if (p == -1) {
                // ELLIPSIS
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: const Text("...", style: TextStyle(fontSize: 16)),
                );
              }

              final bool isActive = p == currentPage;

              return GestureDetector(
                onTap: () {
                  if (!isActive) {
                    provider.getAccounts(ctx: context, page: p);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.yellow[700] : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    "$p",
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(width: 8),

            /// NEXT >
            _pageCircle(
              label: ">",
              enabled: currentPage < lastPage,
              onTap: () =>
                  provider.getAccounts(ctx: context, page: currentPage + 1),
            ),

            /// LAST >>
            _pageCircle(
              label: "»",
              enabled: currentPage < lastPage,
              onTap: () => provider.getAccounts(ctx: context, page: lastPage),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget for circle buttons
  Widget _pageCircle({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    IconData? icon;
    if (label == "<") icon = Icons.chevron_left;
    if (label == ">") icon = Icons.chevron_right;
    if (label == "«") icon = Icons.keyboard_double_arrow_left;
    if (label == "»") icon = Icons.keyboard_double_arrow_right;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : Colors.grey.shade200,
          border: Border.all(color: Colors.black12),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: enabled ? Colors.black : Colors.grey,
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled ? Colors.black : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Future<dynamic> _openRightSideSheet(BuildContext context, Widget child) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "RightSideSheet",
      barrierColor: Colors.black.withValues(alpha: .25),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 420,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  bottomLeft: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _iconButton({required String icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: ImageWidget(image: icon, width: 20, color: Colors.black),
    );
  }

  Widget _iconButtonTwo(String icon) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      child: ImageWidget(image: icon, width: 23),
    );
  }
}
