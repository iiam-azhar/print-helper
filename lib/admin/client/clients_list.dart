import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/customers/customer_list.dart';
import 'package:print_helper/admin/client/add_client.dart';
import 'package:print_helper/admin/client/edit_client.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../models/client_models.dart';
import '../../providers/auth_pro.dart';
import '../../providers/client_pro.dart';
import '../../services/helpers.dart';
import '../../widgets/loaders.dart';
import '../../widgets/spacers.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/toasts.dart';
import '../filter/filter_screen.dart';

class ClientScreen extends StatefulWidget {
  final bool isFromAdmin;
  final bool isFromStaff;
  final bool isFromClient;
  final VoidCallback? onChatTap;
  const ClientScreen({
    super.key,
    required this.isFromAdmin,
    required this.isFromStaff,
    required this.isFromClient,
    this.onChatTap,
  });

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        final provider = getClientPro(context);
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
          provider.getClients(
            ctx: context,
            page: provider.currentPage + 1,
            loadMore: true,
          );
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getClientPro(context).getClients(ctx: context);
    });
  }

  Future<void> _onRefresh() async {
    final provider = getClientPro(context);
    await provider.getClients(ctx: context, page: 1, loadMore: false);
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
            child: Consumer<ClientPro>(
              builder: (context, provider, _) {
                if (provider.clientsLoad) {
                  return Center(child: showLoader());
                }
                if (provider.clients.isEmpty && !provider.clientsLoad) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextWidget(
                          text: "No clients found.",
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          fontFam: MyFontFam.poppins,
                          color: AppColors.grey,
                        ),
                        Spacers.sb20(),
                        if (provider.clientFilters.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              provider.clearClientFilters(context);
                              provider.getClients(
                                ctx: context,
                                page: 1,
                                loadMore: false,
                              );
                              showToast(message: "Filters cleared");
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.r),
                                color: AppColors.primary,
                              ),
                              child: TextWidget(
                                text: "Reset Filters",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    itemCount: provider.clients.length + 1,
                    itemBuilder: (context, index) {
                      if (index == provider.clients.length) {
                        return provider.isLoadingMore
                            ? Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(child: showLoader()),
                              )
                            : SizedBox();
                      }
                      final item = provider.clients[index];
                      return _clientCard(item, context, provider, index);
                    },
                  ),
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
      title: Consumer<ClientPro>(
        builder: (context, provider, child) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Spacers.sbw12(),
              ImageWidget(image: Paths.clientprofile, width: 26),
              Spacers.sbw12(),
              TextWidget(
                text: "Clients (${provider.totalClients})",
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0XFF414345),
              ),
            ],
          );
        },
      ),
      actions: [
        widget.isFromAdmin || widget.isFromStaff
            ? GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    barrierColor: Colors.black.withValues(alpha: .25),
                    builder: (_) => FractionallySizedBox(
                      heightFactor: 0.98,
                      child: const AddClient(),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 22.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: TextWidget(
                    text: "+ Client",
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0XFF414345),
                  ),
                ),
              )
            : SizedBox(),
        Spacers.sbw10(),
        Consumer<ClientPro>(
          builder: (context, pro, _) {
            final count = pro.appliedFilterCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => _filterBottomSheet(context, pro),
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

  void _filterBottomSheet(dynamic context, ClientPro pro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: FilterSheet(
          initialFilters: pro.clientFilters,
          isFromStaff: false,
          isFromClient: true,
        ),
      ),
    ).then((filters) {
      if (filters != null && filters is Map<String, dynamic>) {
        pro.applyClientFilters(filters, context);
      }
    });
  }

  Widget _clientCard(
    ClientModel item,
    BuildContext context,
    ClientPro provider,
    int index,
  ) {
    return _ExpandableClientCard(
      item: item,
      provider: provider,
      index: index,
      parentContext: context,
      isFromAdmin: widget.isFromAdmin,
      isFromStaff: widget.isFromStaff,
      isFromClient: widget.isFromClient,
      onChatTap: widget.onChatTap,
      topRowBuilder: (isExpanded) =>
          _topRow(context, item, provider, index, isExpanded),
      contactsBuilder: () => List.generate(item.contacts.length, (i) {
        return _contactCard(
          item.contacts[i],
          provider,
          item,
          i,
          item.contacts.length,
        );
      }),
    );
  }

  Widget _topRow(
    dynamic context,
    ClientModel item,
    ClientPro provider,
    int index,
    bool isExpanded,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48.w,
              height: 48.h,
              padding: EdgeInsets.all(1.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40.r),
                border: Border.all(color: const Color(0x8D9E9E9E), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40.r),
                child: ImageWidget(
                  image: item.logo == null || item.logo == ""
                      ? Paths.user
                      : item.logo.toString(),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Spacers.sbw12(),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: item.companyName,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    maxLines: 2,
                  ),
                  TextWidget(
                    text: item.companyType,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  Spacers.sb2(),
                  Row(
                    children: [
                      TextWidget(
                        text: item.createdDate,
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      const TextWidget(
                        text: " • ",
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      TextWidget(
                        text: item.createdTime,
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Switch(
                        value: item.status,
                        activeTrackColor: const Color(0XFF00a650),
                        activeThumbColor: AppColors.white,
                        onChanged: (val) {
                          provider
                              .toggleStatus(item.id, val, context)
                              .whenComplete(() {
                                if (!context.mounted) return;
                                provider.getClients(ctx: context, page: 1);
                              });
                        },
                      ),
                      Spacers.sbw8(),
                      Builder(
                        builder: (iconCtx) {
                          return GestureDetector(
                            onTap: () {
                              final RenderBox box =
                                  iconCtx.findRenderObject() as RenderBox;
                              final Offset pos = box.localToGlobal(Offset.zero);
                              final Size size = box.size;
                              showGeneralDialog(
                                context: context,
                                barrierDismissible: true,
                                barrierLabel: "PopupMenu",
                                barrierColor: Colors.black.withValues(
                                  alpha: 0.15,
                                ),
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
                                                vertical: 10.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.95,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
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
                                                  Spacers.sbw8(),
                                                  _popupIcon(
                                                    icon: Paths.edit,
                                                    label: "Edit",
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      showModalBottomSheet(
                                                        context: context,
                                                        isScrollControlled:
                                                            true,
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        builder: (_) {
                                                          return FractionallySizedBox(
                                                            heightFactor: 0.98,
                                                            child: EditClient(
                                                              clientId: item.id,
                                                            ),
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
                                                      _confirmDelete(
                                                        context,
                                                        item.id,
                                                      );
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
                                border: Border.all(
                                  color: Colors.grey,
                                  width: 1,
                                ),
                              ),
                              child: Icon(Icons.more_vert, size: 20.sp),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Spacers.sbw8(),
            Expanded(
              child: TextWidget(
                text: "0 Projects  •  0 Files",
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    navTo(
                      context: context,
                      page: CustomersScreen(
                        isFromAdmin: widget.isFromAdmin,
                        id: item.id,
                        isFromStaff: widget.isFromStaff,
                        isFromClient: widget.isFromClient,
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(top: 5.h),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: TextWidget(
                      text:
                          '${provider.clients[index].customersCount} Customer',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Spacers.sbw8(),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.black54,
                  size: 20.sp,
                ),
              ],
            ),
          ],
        ),
      ],
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

  Widget _contactCard(
    ContactModel contact,
    ClientPro provider,
    ClientModel item,
    int index,
    int total,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40.r),
                border: Border.all(color: const Color(0x8D9E9E9E), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40.r),
                child: ImageWidget(
                  image: contact.avatar == "" ? Paths.user : contact.avatar,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Spacers.sbw12(),
            Expanded(
              child: Row(
                crossAxisAlignment: .end,
                mainAxisAlignment: .spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: contact.name,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Spacers.sb5(),
                        ...contact.phones.map(
                          (p) => TextWidget(
                            text: p,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Spacers.sb2(),
                        ...contact.emails.map(
                          (e) => TextWidget(
                            text: e,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            viewCase: ViewCase.lower,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Spacers.sb5(),
                      ],
                    ),
                  ),
                  Switch(
                    padding: EdgeInsets.zero,
                    value: contact.status,
                    activeTrackColor: const Color(0xFF00a650),
                    activeThumbColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      provider.toggleContactStatus(
                        clientId: item.id,
                        contactId: contact.contactId,
                        newStatus: val,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        Spacers.sb20(),
        Center(
          child: Container(
            width: 200.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: Colors.grey.withValues(alpha: .45),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _imageButton(
                      image: Paths.email,
                      width: 26,
                      onPressed: () {
                        if (contact.emails.isNotEmpty) {
                          tryLaunchUrl(
                            url: 'mailto:${contact.emails.first}',
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
                      onPressed: () => widget.onChatTap?.call(),
                    ),
                    _imageButton(
                      image: Paths.chat,
                      width: 23,
                      onPressed: () => widget.onChatTap?.call(),
                    ),
                    widget.isFromAdmin
                        ? _imageButton(
                            image: Paths.login,
                            width: 19,
                            onPressed: () async {
                              final authPro = Provider.of<AuthPro>(
                                context,
                                listen: false,
                              );
                              await authPro.switchUser(
                                userId: contact.contactId,
                                context: context,
                              );
                            },
                          )
                        : SizedBox(),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 6.h, left: 9.w, right: 9.w),
                  child: Center(
                    child: TextWidget(
                      text: contact.languages.map((e) => e).join(" •  "),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (index != total - 1) Spacers.sb10(),
        if (index != total - 1)
          Divider(color: AppColors.grey.withValues(alpha: .5), thickness: 1),
        if (index != total - 1) Spacers.sb20(),
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
            text: "Delete Client",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
          content: TextWidget(
            text: "Are you sure you want to delete this Client?",
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
                Navigator.pop(context);
                Navigator.pop(context);
                final pro = getClientPro(context);
                bool success = await pro.deleteClient(id, context);
                if (success) {
                  showToast(message: "Client deleted successfully");
                  pro.getClients(ctx: context);
                } else {
                  showToast(message: "Failed to Client account");
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

class _ExpandableClientCard extends StatefulWidget {
  final ClientModel item;
  final ClientPro provider;
  final int index;
  final BuildContext parentContext;
  final bool isFromAdmin;
  final bool isFromStaff;
  final bool isFromClient;
  final VoidCallback? onChatTap;
  final Widget Function(bool isExpanded) topRowBuilder;
  final List<Widget> Function() contactsBuilder;

  const _ExpandableClientCard({
    required this.item,
    required this.provider,
    required this.index,
    required this.parentContext,
    required this.isFromAdmin,
    required this.isFromStaff,
    required this.isFromClient,
    this.onChatTap,
    required this.topRowBuilder,
    required this.contactsBuilder,
  });

  @override
  State<_ExpandableClientCard> createState() => _ExpandableClientCardState();
}

class _ExpandableClientCardState extends State<_ExpandableClientCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 8,
            offset: Offset(0, 4),
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
              padding: EdgeInsets.all(16.w),
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
            // Padding(
            //   padding: EdgeInsets.symmetric(horizontal: 16.w),
            //   child: Divider(color: AppColors.grey.withValues(alpha: .5), thickness: 1),
            // ),
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Spacers.sb10(), ...widget.contactsBuilder()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
