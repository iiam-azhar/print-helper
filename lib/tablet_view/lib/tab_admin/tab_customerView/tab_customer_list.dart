import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/providers/cust_pro.dart';
import 'tab_add_customer.dart';
import '../../tab_widgets/tab_custom_button.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:print_helper/models/customer_models.dart';
import '../../tab_services/helpers.dart';
import '../../tab_utils/formatter.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_toasts.dart';
import '../tab_filter/tab_filter_screen.dart';
import '../../tab_client/tab_edit_client.dart';
import 'tab_edit_customer.dart';
import '../tab_adminBottombar/tab_admin_bottombar.dart';

class CustomersScreen extends StatefulWidget {
  final bool isFromAdmin;
  final Function(String)? onMenuTap;
  final int id;
  const CustomersScreen({
    super.key,
    required this.isFromAdmin,
    this.onMenuTap,
    required this.id,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _scrollController = ScrollController();

  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     final pro = Provider.of<CustomerPro>(context, listen: false);
  //     pro.getCustomers(ctx: context, clientId: widget.id);
  //   });
  //   _scrollController.addListener(_scrollPaginationListener);
  // }

  // void _scrollPaginationListener() {
  //   final pro = Provider.of<CustomerPro>(context, listen: false);
  //   if (_scrollController.position.pixels >=
  //       _scrollController.position.maxScrollExtent - 200) {
  //     if (!pro.isLoadingMore && pro.currentPage < pro.lastPage) {
  //       pro.getCustomers(
  //         ctx: context,
  //         clientId: widget.id,
  //         page: pro.currentPage + 1,
  //         loadMore: true,
  //       );
  //     }
  //   }
  // }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<CustomerPro>(context, listen: false);
      // Load first page initially
      pro.getCustomers(ctx: context, page: 1, clientId: widget.id);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                opacity: const AlwaysStoppedAnimation(.28),
              ),
            ),
          ),
          SafeArea(
            child: Consumer<CustomerPro>(
              builder: (context, provider, _) {
                if (provider.customersLoad) return Center(child: showLoader());
                if (provider.customers.isEmpty) {
                  return _noCustomersFound();
                }
                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          children: [
                            if (provider.topCustomer != null)
                              _topPreview(provider),
                            // _header(provider),
                            Spacers.sb12(),
                            ...provider.customers.map(
                              (c) => _customerCard(c, provider),
                            ),
                            if (provider.isLoadingMore)
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: showLoader(),
                                ),
                              ),
                            Spacers.sb20(),
                          ],
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

  Widget _topPreview(CustomerPro item) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: .center,
                  children: [
                    TextWidget(
                      text: 'Client',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    Spacers.sbw40(),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(56),
                        child: ImageWidget(
                          image:
                              (item.client!.image == null ||
                                  item.client!.image!.isEmpty)
                              ? Paths.user
                              : item.client!.image.toString(),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Spacers.sbw20(),
                    Column(
                      crossAxisAlignment: .start,
                      children: [
                        TextWidget(
                          text: item.client!.companyName,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                        Spacers.sb2(),
                        TextWidget(
                          text: item.client!.companyTypeName,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    Spacers.sbw50(),
                    Spacers.sbw50(),
                    Column(
                      children: [
                        TextWidget(
                          text: '511 Projects - 31241 Files',
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                        Spacers.sb2(),
                        TextWidget(
                          text: frmtDateTime(item.client!.createdAt),
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ],
                    ),
                    Spacer(),
                    widget.isFromAdmin
                        ? Row(
                            children: [
                              IconButton(
                                onPressed: () async {
                                  debugPrint(
                                    'Banner Login Tap Client ID: ${item.client!.id}',
                                  );
                                  final clPro = Provider.of<ClientPro>(
                                    context,
                                    listen: false,
                                  );
                                  final authPro = Provider.of<AuthPro>(
                                    context,
                                    listen: false,
                                  );

                                  final clientDetails = await clPro
                                      .getClientDetails(item.client!.id);
                                  if (clientDetails != null &&
                                      clientDetails.contacts.isNotEmpty) {
                                    final primary = clientDetails.contacts
                                        .firstWhere(
                                          (c) => c.isPrimary == 1,
                                          orElse: () =>
                                              clientDetails.contacts.first,
                                        );

                                    await authPro.switchUser(
                                      userId: primary.id,
                                      context: context,
                                    );
                                  }
                                },
                                icon: ImageWidget(
                                  image: Paths.login,
                                  width: 25,
                                  color: AppColors.white,
                                ),
                              ),
                              Spacers.sbw15(),
                              IconButton(
                                onPressed: () {
                                  debugPrint(
                                    'Banner Edit Tap Client ID: ${item.client!.id}',
                                  );
                                  _openRightSideSheet(
                                    context,
                                    EditClient(clientId: item.client!.id),
                                  );
                                },
                                icon: ImageWidget(
                                  image: Paths.edit,
                                  width: 25,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          )
                        : SizedBox(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _header(CustomerPro item) {
  //   print("company type ${item.client!.companyType}");
  //   return Container(
  //     padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
  //     decoration: BoxDecoration(
  //       color: Colors.black,
  //       borderRadius: BorderRadius.circular(14),
  //       boxShadow: [
  //         BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           width: 50,
  //           height: 50,
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             shape: BoxShape.circle,
  //           ),
  //           child: ClipRRect(
  //             borderRadius: BorderRadius.circular(56),
  //             child: ImageWidget(
  //               image:
  //                   (item.client!.image == null || item.client!.image!.isEmpty)
  //                   ? Paths.user
  //                   : item.client!.image.toString(),
  //               width: 50,
  //               height: 50,
  //               fit: BoxFit.cover,
  //             ),
  //           ),
  //         ),
  //         Spacers.sbw10(),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Row(
  //                 crossAxisAlignment: .start,
  //                 children: [
  //                   Expanded(
  //                     child: Column(
  //                       crossAxisAlignment: .start,
  //                       children: [
  //                         TextWidget(
  //                           text: item.client!.companyName,
  //                           fontSize: 14,
  //                           fontWeight: FontWeight.w600,
  //                           color: Colors.white,
  //                           maxLines: 2,
  //                         ),
  //                         TextWidget(
  //                           text: item.client!.companyTypeName,
  //                           fontSize: 14,
  //                           fontWeight: FontWeight.w600,
  //                           color: Colors.white,
  //                         ),
  //                         Spacers.sb2(),
  //                         TextWidget(
  //                           text: frmtDateTime(item.client!.createdAt),
  //                           fontSize: 11,
  //                           fontWeight: FontWeight.w500,
  //                           color: Colors.white70,
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   Expanded(
  //                     child: Column(
  //                       crossAxisAlignment: .end,
  //                       children: [
  //                         TextWidget(
  //                           text: '511 Projects - 31241 Files',
  //                           fontSize: 11,
  //                           fontWeight: FontWeight.w600,
  //                           color: Colors.white,
  //                         ),
  //                         Row(
  //                           mainAxisAlignment: .end,
  //                           children: [
  //                             IconButton(
  //                               onPressed: () {},
  //                               icon: ImageWidget(
  //                                 image: Paths.login,
  //                                 width: 20,
  //                                 color: Colors.white,
  //                               ),
  //                             ),
  //                             IconButton(
  //                               onPressed: () {},
  //                               icon: ImageWidget(
  //                                 image: Paths.edit,
  //                                 width: 20,
  //                                 color: Colors.white,
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  AppBar _appBar(BuildContext context) {
    final provider = Provider.of<CustomerPro>(context);
    final clPro = Provider.of<ClientPro>(context, listen: false);
    final authPro = Provider.of<AuthPro>(context, listen: false);
    final role = authPro.user?.roleName ?? "";
    Color primaryColor = AppColors.primary; // default fallback

    final brandHex = clPro.selectedClient?.secondaryColor;

    if (brandHex != null && brandHex.isNotEmpty) {
      primaryColor = _hexToColor(brandHex);
    }
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 2,
      surfaceTintColor: AppColors.white,
      title: Row(
        children: [
          ImageWidget(image: Paths.customers, width: 28),
          Spacers.sbw12(),
          Consumer<CustomerPro>(
            builder: (context, pro, _) {
              if (pro.customersLoad) {
                return Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(
                    width: 100,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              }

              return TextWidget(
                text: "Customers (${pro.totalCustomers})",
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF414345),
              );
            },
          ),
          Spacer(),
          Expanded(
            flex: 2,
            child: role == "CONTACT" && provider.customersLoad
                ? _contactMultipleCustomersShimmer()
                : CustomButton(
                    padding: EdgeInsetsGeometry.all(10),
                    title: "Contact Multiple Customers",
                    stadium: false,
                    height: 38,
                    buttonColor: role == "CONTACT"
                        ? primaryColor
                        : AppColors.amber,
                    textColor: AppColors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    borderRadius: 12,
                    onTap: () {},
                  ),
          ),
          Spacer(),
        ],
      ),
      leading: IconButton(
        onPressed: () {
          // Navigator.pop(context);

          if (widget.onMenuTap != null) {
            widget.onMenuTap!("clients"); // switch page inside dashboard
          }
        },
        icon: Icon(CupertinoIcons.back),
      ),
      actions: [
        GestureDetector(
          onTap: () {
            _openRightSideSheet(
              context,
              AddCustomer(
                clientId: widget.id,
                // isFromClient: widget.isFromClient,
              ),
            );
          },
          child: provider.customersLoad && role == "CONTACT"
              ? addCustomerButtonShimmer()
              : Container(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: role == "CONTACT" ? primaryColor : AppColors.amber,
                      width: 1.5,
                    ),
                  ),
                  child: TextWidget(
                    text: "+ Customer",
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: const Color(0xFF414345),
                  ),
                ),
        ),
        Spacers.sbw10(),
        Consumer<CustomerPro>(
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
                        initialFilters: pro.customerFilters,
                        isFromStaff: false,
                        isFromClient: true,
                      ),
                    ).then((filters) {
                      if (filters != null && filters is Map<String, dynamic>) {
                        pro.applyCustFilters(filters, context, widget.id);
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
        Spacers.sbw10(),
      ],
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
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

  Widget _customerCard(CustomerModel item, CustomerPro provider) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
          _companyHeader(item, provider),
          Divider(color: AppColors.grey.withValues(alpha: .5)),
          Spacers.sb8(),
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
      ),
    );
  }

  Widget _companyHeader(CustomerModel item, CustomerPro provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: AppColors.grey.withValues(alpha: .5)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: ImageWidget(
              image: item.imageUrl ?? Paths.user,
              width: 45,
              height: 45,
              fit: BoxFit.cover,
            ),
          ),
        ),

        Spacers.sbw12(),

        // COLUMN 1 — Company Name + Category + Date
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: item.companyName,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: 2),

              Row(
                children: [
                  TextWidget(
                    text: item.companyCategoryName,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.black87,
                  ),

                  SizedBox(width: 8),
                  Text("|", style: TextStyle(color: Colors.grey)),
                  SizedBox(width: 8),

                  TextWidget(
                    text: frmtDateTime(item.createdAt),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),

        // COLUMN 2 — Projects + Files  (same alignment as Accounts screen)
        Expanded(
          flex: 2,
          child: TextWidget(
            text: "4 Projects  •  3 Files",
            fontWeight: FontWeight.w500,
            fontSize: 12,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // RIGHT COLUMN — Switch + Edit/Delete icons (exactly like Accounts screen)
        SizedBox(
          width: 250,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 55,
                height: 40,
                child: FittedBox(
                  child: Switch(
                    value: item.status,
                    activeTrackColor: Color(0XFF00a650),
                    activeThumbColor: AppColors.white,
                    onChanged: (val) => provider
                        .toggleStatus(
                          clientId: item.clientId,
                          custId: item.id,
                          newStatus: val,
                        )
                        .whenComplete(() {
                          if (!mounted) return;
                          provider.getCustomers(
                            ctx: context,
                            page: provider.currentPage,
                            clientId: widget.id,
                          );
                        }),
                  ),
                ),
              ),
              // Spacers.sbw20(),
              SizedBox(width: 90),
              SizedBox(),
              _iconButton(
                icon: Paths.edit,
                onTap: () {
                  debugPrint("${item.id}customer idddddd");
                  debugPrint("${item.clientId}client idddddd");
                  _openRightSideSheet(
                    context,
                    EditCustomer(customerId: item.id, clientId: item.clientId),
                  );
                },
              ),
              _iconButton(
                icon: Paths.delete,
                onTap: () {
                  _confirmDelete(context, item.id, item.clientId);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(dynamic context, int id, int clientId) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: TextWidget(
            text: "Delete Customer",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
          content: TextWidget(
            text: "Are you sure you want to delete this Customer?",
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
                // Navigator.pop(context);
                final pro = getCustPro(context);
                bool success = await pro.deleteCust(id, context);
                if (success) {
                  showToast(message: "Customer deleted successfully");
                  pro.getCustomers(ctx: context, clientId: clientId);
                } else {
                  showToast(message: "Failed to Delete Customer");
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

  Widget _iconButton({required String icon, required VoidCallback onTap}) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: ImageWidget(image: icon, width: 20, color: Colors.black),
      ),
    );
  }

  Widget _contactCard(
    ContactModel c,
    CustomerPro provider,
    CustomerModel item,
    int index,
    int total,
  ) {
    final authPro = Provider.of<AuthPro>(context, listen: false);
    final role = authPro.user?.roleName ?? "";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.grey),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: ImageWidget(
                image: c.imageUrl ?? Paths.user,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ),

          Spacers.sbw12(),

          // COLUMN 1 — Contact Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextWidget(
                        text: c.name,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: c.languages.map((lang) {
                        return TextWidget(
                          text: lang,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // COLUMN 2 — Phones
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: c.phones.map((p) {
                return TextWidget(
                  text: p,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );
              }).toList(),
            ),
          ),

          // COLUMN 3 — Emails
          SizedBox(width: 22),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: c.emails.map((e) {
                return TextWidget(
                  text: e,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                );
              }).toList(),
            ),
          ),

          // RIGHT SIDE — Switch + Icons
          SizedBox(
            width: 300,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 55,
                  height: 33,
                  child: FittedBox(
                    child: Switch(
                      value: c.status,
                      activeTrackColor: Color(0XFF00a650),
                      activeThumbColor: AppColors.white,
                      onChanged: (val) => provider.toggleCustContact(
                        clientId: item.id,
                        custId: c.contactId,
                        newStatus: val,
                      ),
                    ),
                  ),
                ),

                role == "CONTACT" || role == "STAFF"
                    ? SizedBox(width: 59)
                    : Spacers.sbw20(),
                _imageButton(Paths.email, 20, () {
                  if (c.emails.isNotEmpty) {
                    tryLaunchUrl(
                      url: 'mailto:${c.emails.first}',
                      message: 'Could not open email app',
                    );
                  } else {
                    showToast(message: 'No email address available');
                  }
                }),
                _imageButton(
                  Paths.call,
                  20,
                  () => navTo(
                    context: context,
                    page: AdminBottomBar(pageNum: 2),
                    removeUntil: true,
                  ),
                ),
                _imageButton(
                  Paths.chat,
                  20,
                  () => navTo(
                    context: context,
                    page: AdminBottomBar(pageNum: 2),
                    removeUntil: true,
                  ),
                ),
                role == "CONTACT" || role == "STAFF"
                    ? SizedBox()
                    : _imageButton(Paths.login, 20, () async {
                        final authPro = Provider.of<AuthPro>(
                          context,
                          listen: false,
                        );
                        // await authPro.switchUser(
                        //   userId: item.id,
                        //   context: context,
                        // );
                        await authPro.switchUser(
                          userId: item.contacts[index].contactId,
                          context: context,
                        );

                        debugPrint(
                          "${item.contacts[index].contactId} contact id",
                        );
                      }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noCustomersFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ImageWidget(
            image: Paths.customers, // or create a no_data icon
            width: 80,
            color: Colors.grey.shade400,
          ),
          Spacers.sb15(),
          TextWidget(
            text: "No customers found",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
          Spacers.sb5(),
          TextWidget(
            text: "Try adding a new customer",
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }

  Widget _imageButton(String image, double width, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: GestureDetector(
        onTap: onTap,
        child: ImageWidget(image: image, width: width),
      ),
    );
  }

  Widget _contactMultipleCustomersShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget addCustomerButtonShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Container(width: 70, height: 10, color: Colors.white),
      ),
    );
  }

  Widget _buildPagination(CustomerPro provider) {
    if (provider.lastPage <= 1) return SizedBox.shrink();

    int currentPage = provider.currentPage;
    int lastPage = provider.lastPage;
    List<int> pages = [];

    if (lastPage <= 7) {
      pages = List.generate(lastPage, (i) => i + 1);
    } else {
      pages.add(1);
      if (currentPage > 3) pages.add(-1);

      int start = (currentPage - 1).clamp(2, lastPage - 2);
      int end = (currentPage + 1).clamp(2, lastPage - 1);

      for (int i = start; i <= end; i++) {
        pages.add(i);
      }

      if (currentPage < lastPage - 2) pages.add(-1);
      pages.add(lastPage);
    }

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _pageButton("«", currentPage > 1, () {
            provider.getCustomers(ctx: context, clientId: widget.id, page: 1);
          }),
          _pageButton("<", currentPage > 1, () {
            provider.getCustomers(
              ctx: context,
              clientId: widget.id,
              page: currentPage - 1,
            );
          }),
          SizedBox(width: 8),
          ...pages.map((p) {
            if (p == -1) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text("...", style: TextStyle(fontSize: 16)),
              );
            }

            bool active = p == currentPage;
            return GestureDetector(
              onTap: () {
                if (!active) {
                  provider.getCustomers(
                    ctx: context,
                    clientId: widget.id,
                    page: p,
                  );
                }
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 6),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.amber : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  "$p",
                  style: TextStyle(
                    color: active ? Colors.black : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
          SizedBox(width: 8),
          _pageButton(">", currentPage < lastPage, () {
            provider.getCustomers(
              ctx: context,
              clientId: widget.id,
              page: currentPage + 1,
            );
          }),
          _pageButton("»", currentPage < lastPage, () {
            provider.getCustomers(
              ctx: context,
              clientId: widget.id,
              page: lastPage,
            );
          }),
        ],
      ),
    );
  }

  Widget _pageButton(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        margin: EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : Colors.grey.shade200,
          border: Border.all(color: Colors.black12),
        ),
        child: Center(
          child: Text(
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

  Future<void> _onRefresh() async {
    final provider = Provider.of<CustomerPro>(context, listen: false);
    await provider.getCustomers(ctx: context, page: 1, clientId: widget.id);
  }
}
