import 'package:flutter/material.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:provider/provider.dart';

import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_services/helpers.dart';
import '../../tab_utils/formatter.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_toasts.dart';
import '../tab_filter/tab_filter_screen.dart';
import 'tab_add_account.dart';
import 'tab_edit_account.dart';

class AccountsScreen extends StatefulWidget {
  final ValueChanged<String>? onMenuTap;

  const AccountsScreen({super.key, this.onMenuTap});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _expandedAccountIds = <int>{};

  static const double _rightActionWidth =
      _switchSlotWidth + (_actionSlotWidth * 3);
  static const double _switchSlotWidth = 50;
  static const double _actionSlotWidth = 32;

  void _toggleAccountExpanded(int accountId) {
    setState(() {
      if (_expandedAccountIds.contains(accountId)) {
        _expandedAccountIds.remove(accountId);
      } else {
        _expandedAccountIds.add(accountId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<AdminPro>(context, listen: false);
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
                      child: RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          itemCount: provider.accounts.length,
                          itemBuilder: (context, index) {
                            final item = provider.accounts[index];
                            return _accountCard(item, context, provider);
                          },
                        ),
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
                text: 'Accounts (${provider.totalAccounts})',
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
            _openRightSideSheet(context, AccountAddContent());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const TextWidget(
              text: '+ Account',
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
    final bool isExpanded = _expandedAccountIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isExpanded ? const Color(0xFFEFF4FB) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.only(
              left: 14,
              right: 14,
              top: 14,
              bottom: 10,
            ),
            child: _topRow(item, provider, isExpanded),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 57),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: SizedBox()),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: item.phones.map((phone) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextWidget(
                                  text: '${phone.type}: ${phone.number}',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: item.emails.map((email) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextWidget(
                                  text: email,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(
                          width: _rightActionWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: _switchSlotWidth,
                                height: 40,
                              ),
                              SizedBox(
                                width: _actionSlotWidth,
                                child: item.emails.isNotEmpty
                                    ? _iconButtonTwo(
                                        Paths.email,
                                        25,
                                        onTap: () {
                                          tryLaunchUrl(
                                            url: 'mailto:${item.emails.first}',
                                            message: 'Could not open email app',
                                          );
                                        },
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              SizedBox(
                                width: _actionSlotWidth,
                                child: _iconButtonTwo(
                                  Paths.chat,
                                  20,
                                  onTap: () {
                                    if (widget.onMenuTap != null) {
                                      widget.onMenuTap!('chat');
                                      return;
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: _actionSlotWidth),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _topRow(AccountModel item, AdminPro provider, bool isExpanded) {
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
                  text: '0 Project - 0 File',
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
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
                width: _rightActionWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _switchSlotWidth,
                      height: 40,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: Switch(
                          value: item.status,
                          activeTrackColor: const Color(0XFF00a650),
                          activeThumbColor: AppColors.white,
                          onChanged: (val) =>
                              provider.toggleStatus(item.id, val, context),
                        ),
                      ),
                    ),
                    SizedBox(width: _actionSlotWidth),
                    SizedBox(
                      width: _actionSlotWidth,
                      child: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.black54,
                        ),
                        color: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: 12,
                        shadowColor: Colors.black26,
                        offset: const Offset(0, 44),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 150),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (value) async {
                          if (value == 'login') {
                            final authPro = Provider.of<AuthPro>(
                              context,
                              listen: false,
                            );
                            await authPro.switchUser(
                              userId: item.id,
                              context: context,
                            );
                          } else if (value == 'edit') {
                            _openRightSideSheet(
                              context,
                              EditAccount(account: item),
                            );
                          } else if (value == 'delete') {
                            _confirmDelete(context, item.id);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem<String>(
                            value: 'login',
                            height: 40,
                            child: Row(
                              children: [
                                ImageWidget(
                                  image: Paths.login,
                                  width: 18,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 10),
                                const TextWidget(
                                  text: 'Login',
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'edit',
                            height: 40,
                            child: Row(
                              children: [
                                ImageWidget(
                                  image: Paths.edit,
                                  width: 18,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 10),
                                const TextWidget(
                                  text: 'Edit',
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            height: 40,
                            child: Row(
                              children: [
                                ImageWidget(
                                  image: Paths.delete,
                                  width: 18,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 10),
                                const TextWidget(
                                  text: 'Delete',
                                  fontSize: 14,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      width: _actionSlotWidth,
                      child: IconButton(
                        onPressed: () => _toggleAccountExpanded(item.id),
                        icon: ImageWidget(
                          image: isExpanded ? Paths.up : Paths.down,
                          width: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ),
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
            text: 'Delete Account',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
          content: TextWidget(
            text: 'Are you sure you want to delete this account?',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TextWidget(
                text: 'Cancel',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                decoration: TextDecoration.none,
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final pro = getAdminPro(context);
                final success = await pro.deleteAccount(id, context);
                if (success) {
                  showToast(message: 'Account deleted successfully');
                  pro.getAccounts(ctx: context);
                } else {
                  showToast(message: 'Failed to delete account');
                }
              },
              child: const TextWidget(
                text: 'Delete',
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
    List<int> pages = [];

    if (lastPage <= 7) {
      pages = List.generate(lastPage, (i) => i + 1);
    } else {
      pages.add(1);
      if (currentPage > 3) pages.add(-1);

      final int start = (currentPage - 1).clamp(2, lastPage - 2);
      final int end = (currentPage + 1).clamp(2, lastPage - 1);

      for (int i = start; i <= end; i++) {
        pages.add(i);
      }

      if (currentPage < lastPage - 2) pages.add(-1);
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
            _pageCircle(
              label: '«',
              enabled: currentPage > 1,
              onTap: () => provider.getAccounts(ctx: context, page: 1),
            ),
            _pageCircle(
              label: '<',
              enabled: currentPage > 1,
              onTap: () =>
                  provider.getAccounts(ctx: context, page: currentPage - 1),
            ),
            const SizedBox(width: 8),
            ...pages.map((p) {
              if (p == -1) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: const Text('...', style: TextStyle(fontSize: 16)),
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
                    '$p',
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            _pageCircle(
              label: '>',
              enabled: currentPage < lastPage,
              onTap: () =>
                  provider.getAccounts(ctx: context, page: currentPage + 1),
            ),
            _pageCircle(
              label: '»',
              enabled: currentPage < lastPage,
              onTap: () => provider.getAccounts(ctx: context, page: lastPage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageCircle({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    IconData? icon;
    if (label == '<') icon = Icons.chevron_left;
    if (label == '>') icon = Icons.chevron_right;
    if (label == '«') icon = Icons.keyboard_double_arrow_left;
    if (label == '»') icon = Icons.keyboard_double_arrow_right;

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
      barrierLabel: 'RightSideSheet',
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

  Widget _iconButtonTwo(
    String icon,
    double width, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
        child: ImageWidget(image: icon, width: width),
      ),
    );
  }

  Future<void> _onRefresh() async {
    final provider = Provider.of<AdminPro>(context, listen: false);
    await provider.getAccounts(ctx: context, page: 1);
  }
}
