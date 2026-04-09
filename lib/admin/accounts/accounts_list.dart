import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/accounts/add_account.dart';
import 'package:print_helper/admin/accounts/edit_account.dart';
import 'package:print_helper/admin/filter/filter_screen.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../providers/auth_pro.dart';
import '../../services/helpers.dart';
import '../../utils/formatter.dart';
import '../../widgets/loaders.dart';
import '../../widgets/spacers.dart';
import '../../widgets/text_widget.dart';

class AccountsScreen extends StatefulWidget {
  final bool isFromAdmin;
  const AccountsScreen({super.key, required this.isFromAdmin});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<AdminPro>(context, listen: false);
      pro.getAccounts(ctx: context);
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
          if (!pro.isLoadingMore && pro.currentPage < pro.lastPage) {
            pro.getAccounts(
              ctx: context,
              page: pro.currentPage + 1,
              loadMore: true,
            );
          }
        }
      });
    });
  }

  Future<void> _onRefresh() async {
    final pro = getAdminPro(context);

    await pro.getAccounts(
      ctx: context,
      page: 1,
      loadMore: false, // ✅ full refresh
    );
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
                if (provider.accounts.isEmpty) {
                  return Center(
                    child: TextWidget(
                      text: "No accounts found!",
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.w,
                          ),
                          itemCount:
                              provider.accounts.length +
                              (provider.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == provider.accounts.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(child: showLoader()),
                              );
                            }
                            final item = provider.accounts[index];
                            return provider.accounts.isEmpty
                                ? const SizedBox()
                                : _accountCard(item, context, provider);
                          },
                        ),
                      ),
                    ),
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
                text: "Accounts (${provider.totalAccounts})",
                fontWeight: FontWeight.bold,
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
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: Colors.black.withValues(alpha: 0.25),
              builder: (_) => FractionallySizedBox(
                heightFactor: 0.98,
                child: const AccountAddContent(),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
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
                  onPressed: () => filterbottomSheet(context, pro),
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

  void filterbottomSheet(dynamic context, AdminPro pro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: FilterSheet(
          initialFilters: pro.accountFilters,
          isFromStaff: true,
          isFromClient: false,
        ),
      ),
    ).then((filters) {
      if (!mounted) return;
      if (filters != null && filters is Map<String, dynamic>) {
        pro.applyAccountFilters(filters, context);
      }
    });
  }

  Widget _accountCard(
    AccountModel item,
    BuildContext context,
    AdminPro provider,
  ) {
    return _ExpandableAccountCard(
      item: item,
      provider: provider,
      topRowBuilder: (isExpanded) => _topRow(item, provider),
      detailsBuilder: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: AppColors.grey.withValues(alpha: .5),
            thickness: 1.2.w,
          ),
          Spacers.sb10(),
          ...item.phones.map(
            (p) => TextWidget(
              text: '${p.type}: ${p.number}',
              fontWeight: FontWeight.w500,
              viewCase: ViewCase.title,
              fontSize: 13,
            ),
          ),
          Spacers.sb2(),
          ...item.emails.map(
            (p) =>
                TextWidget(text: p, fontWeight: FontWeight.w400, fontSize: 12),
          ),
          Spacers.sb15(),
          Center(
            child: Container(
              width: 180.w,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.grey.withValues(alpha: .5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _imageButton(
                        image: Paths.email,
                        width: 26,
                        onPressed: () {
                          if (item.emails.isNotEmpty) {
                            tryLaunchUrl(
                              url: 'mailto:${item.emails.first}',
                              message: 'Could not open email app',
                            );
                          } else {
                            showToast(message: 'No email address available');
                          }
                        },
                      ),
                      _imageButton(
                        image: Paths.call,
                        width: 20,
                        onPressed: () {
                          if (item.phones.isNotEmpty) {
                            tryLaunchUrl(
                              url: 'tel:${item.phones.first.number}',
                              message: 'Could not open dialer',
                            );
                          } else {
                            showToast(message: 'No phone number available');
                          }
                        },
                      ),
                      _imageButton(
                        image: Paths.chat,
                        width: 23,
                        onPressed: () {
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => ChatScreen(
                          //       receiverUserId: item.id,
                          //       title: '${item.name} ${item.lastName}',
                          //     ),
                          //   ),
                          // );
                        },
                      ),
                    ],
                  ),
                  if (item.staffDetails != null &&
                      item.staffDetails!.languages.isNotEmpty)
                    Center(
                      child: TextWidget(
                        text: item.staffDetails!.languages.join(' • '),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  Spacers.sb2(),
                ],
              ),
            ),
          ),
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
            borderRadius: BorderRadius.circular(40.r),
            border: Border.all(color: AppColors.grey),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40.r),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: '${item.name} ${item.lastName}',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              TextWidget(
                text: Frmtr.frmtDate(
                  date: item.createdAt,
                  outForm: 'dd, MMM yyyy hh:mm a',
                ),
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              Spacers.sb2(),
              TextWidget(
                text: "4 Projects  •  1222 Files",
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ),
        Switch(
          value: item.status,
          activeTrackColor: const Color(0XFF00a650),
          activeThumbColor: AppColors.white,
          onChanged: (val) {
            provider.toggleStatus(item.id, val, context);
          },
        ),

        Spacers.sbw10(),
        Builder(
          builder: (iconCtx) {
            return GestureDetector(
              onTap: () {
                final RenderBox box = iconCtx.findRenderObject() as RenderBox;
                final Offset pos = box.localToGlobal(Offset.zero);
                final Size size = box.size;
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: "PopupMenu",
                  barrierColor: Colors.black.withValues(alpha: 0.15),
                  transitionDuration: Duration(milliseconds: 250),
                  transitionBuilder: (_, animation, _, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: Offset(0, -0.05),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
                  pageBuilder: (_, _, _) {
                    return GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Stack(
                        children: [
                          Positioned(
                            top: pos.dy + size.height + 6,
                            left: pos.dx - 110,
                            child: GestureDetector(
                              onTap: () {},
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 12.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 18,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _popupIcon(
                                      icon: Paths.login,
                                      label: "Login",
                                      onTap: () async {
                                        Navigator.pop(context);
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

                                    Spacers.sbw20(),
                                    _popupIcon(
                                      icon: Paths.edit,
                                      label: "Edit",
                                      onTap: () {
                                        Navigator.pop(context);
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) {
                                            return FractionallySizedBox(
                                              heightFactor: 0.98,
                                              child: EditAccount(account: item),
                                            );
                                          },
                                        );
                                      },
                                    ),

                                    Spacers.sbw20(),
                                    _popupIcon(
                                      icon: Paths.delete,
                                      label: "Delete",
                                      onTap: () {
                                        _confirmDelete(context, item.id);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: Container(
                width: 35.w,
                height: 33.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13.r),
                  border: Border.all(color: Colors.grey, width: 1),
                ),
                child: Icon(Icons.more_vert, size: 20.sp),
              ),
            );
          },
        ),
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
                Navigator.pop(context); // close showGeneralDialog popup
                final pro = getAdminPro(context);
                bool success = await pro.deleteAccount(id, context);
                if (!mounted) return;
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

  Widget _popupIcon({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageWidget(image: icon, width: 22),
          Spacers.sb2(),
          TextWidget(
            text: label,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
        ],
      ),
    );
  }

  Widget _imageButton({
    required String image,
    required double width,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: ImageWidget(image: image, width: width),
    );
  }
}

class _ExpandableAccountCard extends StatefulWidget {
  final AccountModel item;
  final AdminPro provider;
  final Widget Function(bool isExpanded) topRowBuilder;
  final Widget Function() detailsBuilder;

  const _ExpandableAccountCard({
    required this.item,
    required this.provider,
    required this.topRowBuilder,
    required this.detailsBuilder,
  });

  @override
  State<_ExpandableAccountCard> createState() => _ExpandableAccountCardState();
}

class _ExpandableAccountCardState extends State<_ExpandableAccountCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        color: Colors.white,
        border: widget.item.roleName.toUpperCase() == 'ADMIN'
            ? Border.all(color: Colors.black, width: 1.5.w)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: _isExpanded
                    ? const Color(0xffeff6ff)
                    : Colors.transparent,
                borderRadius: _isExpanded
                    ? BorderRadius.vertical(top: Radius.circular(18.r))
                    : BorderRadius.circular(18.r),
              ),
              child: widget.topRowBuilder(_isExpanded),
            ),
          ),
          if (_isExpanded) ...[
            Padding(
              padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 14.w),
              child: widget.detailsBuilder(),
            ),
          ],
        ],
      ),
    );
  }
}
