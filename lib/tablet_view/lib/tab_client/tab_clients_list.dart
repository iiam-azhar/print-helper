import 'package:flutter/material.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'tab_client_info_screen.dart';
import 'tab_client_billing_screen.dart';
import 'tab_add_client.dart';
import '../tab_constants/paths.dart';
import 'package:print_helper/models/client_models.dart';
import '../tab_services/helpers.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_spacers.dart';
import '../tab_widgets/tab_text_widget.dart';
import 'package:provider/provider.dart';
import '../tab_admin/tab_filter/tab_filter_screen.dart';
import '../tab_constants/colors.dart';
import '../tab_widgets/loaders.dart';
import '../tab_widgets/tab_toasts.dart';
import 'tab_edit_client.dart';

class ClientScreen extends StatefulWidget {
  final bool isFromAdmin;
  final Function(String page, int id)? onMenuTap;
  final VoidCallback? onChatTap;

  const ClientScreen({
    super.key,
    required this.isFromAdmin,
    this.onMenuTap,
    this.onChatTap,
  });

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  DateTime? currentBackPressTime;
  bool canPopNow = false;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _expandedClientIds = <int>{};

  void _toggleClientExpanded(int clientId) {
    setState(() {
      if (_expandedClientIds.contains(clientId)) {
        _expandedClientIds.remove(clientId);
      } else {
        _expandedClientIds.add(clientId);
      }
    });
  }

  @override
  // void initState() {
  //   super.initState();
  //   _scrollController = ScrollController()
  //     ..addListener(() {
  //       final provider = getClientPro(context);
  //       if (_scrollController.position.pixels >=
  //           _scrollController.position.maxScrollExtent - 200) {
  //         provider.getClients(
  //           ctx: context,
  //           page: provider.currentPage + 1,
  //           loadMore: true,
  //         );
  //       }
  //     });
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     getClientPro(context).getClients(ctx: context);
  //   });
  // }
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<ClientPro>(context, listen: false);
      // pro.getClients(ctx: context, page: 1);
      pro.getClients(ctx: context, page: pro.currentPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(child: _buildBody()),
                  Consumer<ClientPro>(
                    builder: (context, provider, _) {
                      return _buildPagination(provider);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final pro = getClientPro(context);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Consumer<ClientPro>(
        builder: (context, provider, child) {
          final count = pro.appliedFilterCount;
          return Row(
            children: [
              Row(
                children: [
                  ImageWidget(image: Paths.clientprofile, width: 24),
                  Spacers.sbw8(),
                  TextWidget(
                    text: "Clients (${pro.totalClients})",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              const Spacer(),
              if (widget.isFromAdmin)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 35,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _openRightSideSheet(context, const AddClient());
                  },

                  child: const TextWidget(
                    text: "+ Client",
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Spacers.sbw12(),
              Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      _openRightSideSheet(
                        context,
                        FilterSheet(
                          initialFilters: pro.clientFilters,
                          isFromStaff: false,
                          isFromClient: true,
                        ),
                      ).then((filters) {
                        if (filters != null &&
                            filters is Map<String, dynamic>) {
                          pro.applyClientFilters(filters, context);
                        }
                      });
                    },
                    icon: ImageWidget(image: Paths.filter, width: 24),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: -0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.yellow[700],
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Spacers.sbw12(),
            ],
          );
        },
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

  Widget _buildBody() {
    return Consumer<ClientPro>(
      builder: (context, provider, _) {
        if (provider.clientsLoad) {
          return Center(child: showLoader());
        }
        // final clients = provider.clients;
        if (provider.clients.isEmpty) {
          return _noClientsFound();
        }
        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            itemCount: provider.clients.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              // if (index == provider.clients.length) {
              //   return provider.isLoadingMore
              //       ? Padding(
              //           padding: const EdgeInsets.all(16.0),
              //           child: Center(child: showLoader()),
              //         )
              //       : SizedBox();
              // }

              if (index == provider.clients.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: showLoader()),
                );
              }
              final item = provider.clients[index];

              return _companyCard(item, context, provider, index);
            },
          ),
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    final provider = Provider.of<ClientPro>(context, listen: false);
    await provider.getClients(ctx: context, page: 1);
  }

  Widget _companyCard(
    ClientModel item,
    dynamic context,
    ClientPro provider,
    int index,
  ) {
    final isExpanded = _expandedClientIds.contains(item.id);
    final authPro = Provider.of<AuthPro>(context, listen: false);
    final role = authPro.user?.roleName ?? "";
    // final clPro = Provider.of<ClientPro>(context, listen: false);
    // Color primaryColor = AppColors.primary; // default fallback
    // final brandHex = clPro.selectedClient?.brandSecondaryColor;
    // if (brandHex != null && brandHex.isNotEmpty) {
    //   primaryColor = _hexToColor(brandHex);
    // }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isExpanded ? const Color(0xFFEFF4FB) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 12),
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: ImageWidget(
                      image: item.logo == null || item.logo == ""
                          ? Paths.user
                          : item.logo.toString(),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: .start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                TextWidget(
                                  text: item.companyName,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 15,
                                ),
                                TextWidget(
                                  text: item.companyType,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                TextWidget(
                                  text: "0 Project - 0 File",
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                ),
                                const SizedBox(height: 5),
                                GestureDetector(
                                  onTap: () {
                                    if (widget.onMenuTap != null) {
                                      debugPrint(
                                        "CLIENT → CUSTOMERS, clientId = ${item.id}",
                                      );
                                      widget.onMenuTap!("customers", item.id);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: role == "STAFF"
                                          ? AppColors.amber
                                          : AppColors.amber,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextWidget(
                                      text:
                                          "${provider.clients[index].customersCount} Customer",
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: TextWidget(
                              text: '${item.createdDate}-${item.createdTime}',
                              fontSize: 12,
                              color: const Color(0xFF8E9BB0),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(width: role != "STAFF" ? 0 : 190),
                          SizedBox(
                            width: role != "STAFF" ? 170 : 100,
                            child: Row(
                              crossAxisAlignment: .center,
                              children: [
                                SizedBox(
                                  width: 55,
                                  height: 40,
                                  child: FittedBox(
                                    fit: BoxFit.fill,
                                    child: Switch(
                                      value: item.status,
                                      activeTrackColor: Color(0XFF00a650),
                                      activeThumbColor: AppColors.white,
                                      onChanged: (val) => provider
                                          .toggleStatus(item.id, val, context)
                                          .whenComplete(() {
                                            if (!mounted) return;
                                            provider.getClients(
                                              ctx: context,
                                              page: 1,
                                            );
                                          }),
                                    ),
                                  ),
                                ),
                                if (role != "STAFF") ...[
                                  PopupMenuButton<String>(
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
                                    constraints: const BoxConstraints(
                                      minWidth: 150,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    onSelected: (value) {
                                      if (value == 'info') {
                                        if (widget.onMenuTap != null) {
                                          widget.onMenuTap!(
                                            "client_info",
                                            item.id,
                                          );
                                        } else {
                                          navTo(
                                            context: context,
                                            page: TabClientInfoScreen(
                                              clientId: item.id,
                                            ),
                                          );
                                        }
                                      } else if (value == 'network') {
                                        if (widget.onMenuTap != null) {
                                          widget.onMenuTap!(
                                            "customers",
                                            item.id,
                                          );
                                        }
                                      } else if (value == 'edit') {
                                        _openRightSideSheet(
                                          context,
                                          EditClient(clientId: item.id),
                                        );
                                      } else if (value == 'billing') {
                                        if (widget.onMenuTap != null) {
                                          widget.onMenuTap!(
                                            "client_billing",
                                            item.id,
                                          );
                                        } else {
                                          navTo(
                                            context: context,
                                            page: TabClientBillingScreen(
                                              clientId: item.id,
                                            ),
                                          );
                                        }
                                      } else if (value == 'delete') {
                                        _confirmDelete(context, item.id);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem<String>(
                                        value: 'info',
                                        height: 40,
                                        child: Row(
                                          children: [
                                            ImageWidget(
                                              image: Paths.info,
                                              width: 18,
                                              color: Colors.black87,
                                            ),
                                            const SizedBox(width: 10),
                                            const TextWidget(
                                              text: 'Info',
                                              fontSize: 14,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'network',
                                        height: 40,
                                        child: Row(
                                          children: [
                                            ImageWidget(
                                              image: Paths.customers,
                                              width: 18,
                                              color: Colors.black87,
                                            ),
                                            const SizedBox(width: 10),
                                            const TextWidget(
                                              text: 'My Network',
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
                                        value: 'billing',
                                        height: 40,
                                        child: Row(
                                          children: [
                                            ImageWidget(
                                              image: Paths.billingIcon,
                                              width: 18,
                                              color: Colors.black87,
                                            ),
                                            const SizedBox(width: 10),
                                            const TextWidget(
                                              text: 'Billing',
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
                                ],
                                IconButton(
                                  onPressed: () =>
                                      _toggleClientExpanded(item.id),
                                  icon: ImageWidget(
                                    image: isExpanded ? Paths.up : Paths.down,
                                    width: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),

            ...List.generate(item.contacts.length, (i) {
              return _contactCard(
                item.contacts[i],
                provider,
                item,
                i,
                item.contacts.length,
              );
            }),
          ],
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
    final authPro = Provider.of<AuthPro>(context, listen: false);
    final role = authPro.user?.roleName ?? "";

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AVATASR
              SizedBox(width: 12),
              Container(
                width: 50,
                height: 50,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: ImageWidget(
                    image: contact.avatar.isEmpty ? Paths.user : contact.avatar,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // MAIN CONTENT
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// COLUMN 1 — NAME + LANGUAGE (ALIGNED LIKE COMPANY)
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextWidget(
                            text: contact.name,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (contact.languages.any((e) => e.trim().isNotEmpty)) ...[
                            const SizedBox(height: 2),
                            TextWidget(
                              text: contact.languages.where((e) => e.trim().isNotEmpty).join(" • "),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.black54,
                            ),
                          ],
                        ],
                      ),
                    ),

                    /// COLUMN 2 — PHONE
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: contact.phones
                            .map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: TextWidget(
                                  text: p,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    /// COLUMN 3 — EMAIL
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: contact.emails
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: TextWidget(
                                  text: e,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    /// RIGHT SIDE — SWITCH + ICONS
                    SizedBox(
                      width: role != "STAFF" ? 170 : 100,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 55,
                            height: 40,
                            child: FittedBox(
                              child: Switch(
                                value: contact.status,
                                activeTrackColor: const Color(0XFF00a650),
                                activeThumbColor: AppColors.white,
                                onChanged: (val) {
                                  provider.toggleContactStatus(
                                    clientId: item.id,
                                    contactId: contact.contactId,
                                    newStatus: val,
                                  );
                                },
                              ),
                            ),
                          ),
                          if (widget.isFromAdmin)
                            _iconButton(
                              icon: Paths.login,
                              onTap: () async {
                                final authPro = Provider.of<AuthPro>(
                                  context,
                                  listen: false,
                                );
                                await authPro.switchUser(
                                  userId: contact.contactId,
                                  context: context,
                                );
                              },
                            ),

                          if (contact.emails.any((e) => e.trim().isNotEmpty))
                            _iconButton(
                              icon: Paths.email,
                              onTap: () {
                                tryLaunchUrl(
                                  url: 'mailto:${contact.emails.firstWhere((e) => e.trim().isNotEmpty)}',
                                  message: 'Could not open email app',
                                );
                              },
                            ),
                          _iconButton(
                            icon: Paths.chat,
                            onTap: () => widget.onChatTap?.call(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (index != total - 1) const Divider(height: 1),
      ],
    );
  }

  Widget _iconButton({required String icon, required VoidCallback onTap}) {
    return Expanded(
      child: IconButton(
        onPressed: onTap,
        icon: ImageWidget(image: icon, width: 20, color: Colors.black),
      ),
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
                // Navigator.pop(context);
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

  Widget _noClientsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ImageWidget(
            image: Paths.clientprofile,
            width: 90,
            color: Colors.grey.shade400,
          ),
          Spacers.sb15(),
          TextWidget(
            text: "No clients found",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
          Spacers.sb5(),
          Spacers.sb10(),
          Consumer<ClientPro>(
            builder: (context, provider, _) {
              if (provider.appliedFilterCount == 0)
                return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  provider.clearClientFilters(context);
                  provider.getClients(ctx: context, page: 1, loadMore: false);
                  showToast(message: "Filters cleared");
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary,
                  ),
                  child: const TextWidget(
                    text: "Reset Filters",
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Widget _buildPagination() {
  //   return Container(
  //     height: 72,
  //     padding: const EdgeInsets.symmetric(horizontal: 24),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: .03),
  //           blurRadius: 10,
  //           offset: const Offset(0, -2),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.end,
  //       children: [
  //         IconButton(
  //           onPressed: page > 1 ? () => setState(() => page--) : null,
  //           icon: const Icon(Icons.chevron_left),
  //         ),
  //         const SizedBox(width: 8),
  //         for (int i = 1; i <= 6; i++)
  //           GestureDetector(
  //             onTap: () => setState(() => page = i),
  //             child: Container(
  //               margin: const EdgeInsets.symmetric(horizontal: 6),
  //               padding: const EdgeInsets.symmetric(
  //                 horizontal: 10,
  //                 vertical: 3,
  //               ),
  //               decoration: BoxDecoration(
  //                 color: page == i ? Colors.yellow[700] : Colors.white,
  //                 borderRadius: BorderRadius.circular(20),
  //                 border: Border.all(color: Colors.black12),
  //               ),
  //               child: Text(
  //                 "$i",
  //                 style: TextStyle(
  //                   color: page == i ? Colors.black : Colors.black87,
  //                 ),
  //               ),
  //             ),
  //           ),
  //         const SizedBox(width: 8),
  //         IconButton(
  //           onPressed: () => setState(() => page++),
  //           icon: const Icon(Icons.chevron_right),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  //  Widget _buildPagination(ClientPro provider) {
  //   if (provider.lastPage <= 1) return const SizedBox.shrink();

  //   final int currentPage = provider.currentPage;
  //   final int lastPage = provider.lastPage;

  //   // Generate visible page numbers with ellipsis
  //   List<int> pages = [];

  //   if (lastPage <= 7) {
  //     pages = List.generate(lastPage, (i) => i + 1);
  //   } else {
  //     pages.add(1);

  //     if (currentPage > 3) pages.add(-1);

  //     int start = (currentPage - 1).clamp(2, lastPage - 2);
  //     int end = (currentPage + 1).clamp(2, lastPage - 1);

  //     for (int i = start; i <= end; i++) {
  //       pages.add(i);
  //     }

  //     if (currentPage < lastPage - 2) pages.add(-1);

  //     pages.add(lastPage);
  //   }

  //   return Container(
  //     height: 72,
  //     padding: const EdgeInsets.symmetric(horizontal: 24),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: .03),
  //           blurRadius: 10,
  //           offset: const Offset(0, -2),
  //         ),
  //       ],
  //     ),
  //     child: Align(
  //       alignment: Alignment.centerRight,
  //       child: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           /// FIRST <<
  //           _pageCircle(
  //             label: "«",
  //             enabled: currentPage > 1,
  //             onTap: () => provider.getClients(ctx: context, page: 1),
  //           ),

  //           /// PREVIOUS <
  //           _pageCircle(
  //             label: "<",
  //             enabled: currentPage > 1,
  //             onTap: () =>
  //                 provider.getClients(ctx: context, page: currentPage - 1),
  //           ),

  //           const SizedBox(width: 8),

  //           /// PAGE NUMBERS
  //           ...pages.map((p) {
  //             if (p == -1) {
  //               return Container(
  //                 margin: const EdgeInsets.symmetric(horizontal: 6),
  //                 child: const Text("...", style: TextStyle(fontSize: 16)),
  //               );
  //             }

  //             final bool isActive = p == currentPage;

  //             return GestureDetector(
  //               onTap: () {
  //                 if (!isActive) {
  //                   provider.getClients(ctx: context, page: p);
  //                 }
  //               },
  //               child: Container(
  //                 margin: const EdgeInsets.symmetric(horizontal: 6),
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 14,
  //                   vertical: 10,
  //                 ),
  //                 decoration: BoxDecoration(
  //                   color: isActive ? Colors.yellow[700] : Colors.white,
  //                   shape: BoxShape.circle,
  //                   border: Border.all(color: Colors.black12),
  //                 ),
  //                 child: Text(
  //                   "$p",
  //                   style: TextStyle(
  //                     color: isActive ? Colors.black : Colors.black87,
  //                     fontWeight: FontWeight.w600,
  //                   ),
  //                 ),
  //               ),
  //             );
  //           }),

  //           const SizedBox(width: 8),

  //           /// NEXT >
  //           _pageCircle(
  //             label: ">",
  //             enabled: currentPage < lastPage,
  //             onTap: () =>
  //                 provider.getClients(ctx: context, page: currentPage + 1),
  //           ),

  //           /// LAST >>
  //           _pageCircle(
  //             label: "»",
  //             enabled: currentPage < lastPage,
  //             onTap: () => provider.getClients(ctx: context, page: lastPage),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _pageCircle({
  //   required String label,
  //   required bool enabled,
  //   required VoidCallback onTap,
  // }) {
  //   IconData? icon;
  //   if (label == "<") icon = Icons.chevron_left;
  //   if (label == ">") icon = Icons.chevron_right;
  //   if (label == "«") icon = Icons.keyboard_double_arrow_left;
  //   if (label == "»") icon = Icons.keyboard_double_arrow_right;

  //   return GestureDetector(
  //     onTap: enabled ? onTap : null,
  //     child: Container(
  //       width: 40,
  //       height: 40,
  //       margin: const EdgeInsets.symmetric(horizontal: 6),
  //       decoration: BoxDecoration(
  //         shape: BoxShape.circle,
  //         color: enabled ? Colors.white : Colors.grey.shade200,
  //         border: Border.all(color: Colors.black12),
  //       ),
  //       child: Center(
  //         child: icon != null
  //             ? Icon(
  //                 icon,
  //                 size: 18,
  //                 color: enabled ? Colors.black : Colors.grey,
  //               )
  //             : Text(
  //                 label,
  //                 style: TextStyle(
  //                   fontSize: 14,
  //                   color: enabled ? Colors.black : Colors.grey,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildPagination(ClientPro provider) {
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
              onTap: () => provider.getClients(ctx: context, page: 1),
            ),

            /// PREVIOUS <
            _pageCircle(
              label: "<",
              enabled: currentPage > 1,
              onTap: () =>
                  provider.getClients(ctx: context, page: currentPage - 1),
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
                    provider.getClients(ctx: context, page: p);
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
                  provider.getClients(ctx: context, page: currentPage + 1),
            ),

            /// LAST >>
            _pageCircle(
              label: "»",
              enabled: currentPage < lastPage,
              onTap: () => provider.getClients(ctx: context, page: lastPage),
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
}
