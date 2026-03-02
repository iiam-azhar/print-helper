import 'package:flutter/material.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/cust_pro.dart';
import '../../tab_utils/formatter.dart';
import 'package:provider/provider.dart';

import 'package:print_helper/models/customer_models.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_widgets/loaders.dart';
import '../tab_filter/tab_filter_screen.dart';
import 'tab_edit_customer.dart';

class SingleCustomer extends StatefulWidget {
  final bool isFromAdmin;
  final bool isFromStaff;
  final bool isFromClient;
  final int id;

  const SingleCustomer({
    super.key,
    required this.isFromAdmin,
    required this.isFromStaff,
    required this.isFromClient,
    required this.id,
  });

  @override
  State<SingleCustomer> createState() => _SingleCustomerState();
}

class _SingleCustomerState extends State<SingleCustomer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final custPro = context.read<CustomerPro>();
      final authPro = context.read<AuthPro>();
      final clientId = widget.isFromClient
          ? authPro.user!.custClientId
          : widget.id;
      custPro.getSingleCustomer(ctx: context, clientId: clientId);
    });
    _scrollController.addListener(_paginationListener);
  }

  void _paginationListener() {
    final pro = context.read<CustomerPro>();
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!pro.isLoadingMore && pro.currentPage < pro.lastPage) {
        pro.getSingleCustomer(
          ctx: context,
          clientId: widget.id,
          page: pro.currentPage + 1,
          loadMore: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: true,
            child: Image.asset(
              Paths.chatbg,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              opacity: const AlwaysStoppedAnimation(.28),
            ),
          ),
          SafeArea(
            child: Consumer<CustomerPro>(
              builder: (context, pro, _) {
                final auth = context.read<AuthPro>();
                final loggedCustomerId = auth.user?.customerId;
                print("loggedCustomerId $loggedCustomerId");
                if (pro.customersLoad) {
                  return Center(child: showLoader());
                }
                final customers = widget.isFromClient
                    ? pro.customers
                          .where((c) => c.id == loggedCustomerId)
                          .toList()
                    : pro.customers;
                if (customers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: TextWidget(
                        text: "No Details found!",
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                  );
                }
                return ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    ...customers.map((c) => _customerCard(c, pro)),
                    if (pro.isLoadingMore)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(child: showLoader()),
                      ),
                    Spacers.sb20(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _appBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      automaticallyImplyLeading: false, //TODO change here
      elevation: 2,
      surfaceTintColor: AppColors.white,
      title: Row(
        children: [
          ImageWidget(image: Paths.customers, width: 28),
          Spacers.sbw12(),
          const TextWidget(
            text: "Customer",
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF414345),
          ),
        ],
      ),
      actions: [
        Consumer<CustomerPro>(
          builder: (dynamic context, pro, _) {
            final count = pro.appliedFilterCount;
            return IconButton(
              onPressed: () {
                _openRightSideSheet(
                  context,
                  FilterSheet(
                    initialFilters: pro.customerFilters,
                    isFromStaff: widget.isFromStaff,
                    isFromClient: widget.isFromClient,
                  ),
                ).then((filters) {
                  if (filters != null) {
                    pro.applyCustFilters(filters, context, widget.id);
                  }
                });
                // showModalBottomSheet(
                //   context: context,
                //   isScrollControlled: true,
                //   backgroundColor: Colors.transparent,
                //   builder: (_) => FractionallySizedBox(
                //     heightFactor: 0.9,
                //     child: FilterSheet(
                //       initialFilters: pro.customerFilters,
                //       isFromStaff: widget.isFromStaff,
                //       isFromClient: widget.isFromClient,
                //     ),
                //   ),
                // ).then((filters) {
                //   if (filters != null) {
                //     pro.applyCustFilters(filters, context, widget.id);
                //   }
                // });
              },
              icon: Stack(
                children: [
                  ImageWidget(image: Paths.filter, width: 20),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.amber,
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _companyHeader(item, provider),
          Divider(color: AppColors.grey.withValues(alpha: .5)),
          Spacers.sb8(),
          ...item.contacts.map(
            (c) => _contactCard(c, provider, item, item.contacts.length),
          ),
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
                height: 33,
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
                          // provider.getCustomers(
                          //   ctx: context,
                          //   page: provider.currentPage,
                          //   clientId: widget.id,
                          // );
                          final authPro = context.read<AuthPro>();
                          final clientId = widget.isFromClient
                              ? authPro.user!.custClientId
                              : widget.id;
                          provider.getSingleCustomer(
                            ctx: context,
                            clientId: clientId,
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
                  print("${item.id}customer idddddd");
                  print("${item.clientId}client idddddd");
                  _openRightSideSheet(
                    context,
                    EditCustomer(customerId: item.id, clientId: item.clientId),
                  );
                },
              ),
              SizedBox(width: 42),
              // _iconButton(
              //   icon: Paths.delete,
              //   onTap: () {
              //     _confirmDelete(context, item.id, item.clientId);
              //   },
              // ),
            ],
          ),
        ),
      ],
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
    ContactModel contact,
    CustomerPro provider,
    CustomerModel item,
    int total,
  ) {
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
                image: contact.imageUrl ?? Paths.user,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ),

          Spacers.sbw12(),

          // COLUMN 1 — Name + Languages
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: TextWidget(
                    text: contact.name,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: contact.languages.map((lang) {
                    return TextWidget(
                      text: lang,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // COLUMN 2 — Phones
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contact.phones.map((p) {
                return TextWidget(
                  text: p,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );
              }).toList(),
            ),
          ),

          // COLUMN 3 — Emails
          SizedBox(width: 30),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contact.emails.map((e) {
                return TextWidget(
                  text: e,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                );
              }).toList(),
            ),
          ),

          // RIGHT — Switch + Action Icons
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
                      value: contact.status,
                      activeTrackColor: const Color(0xFF00a650),
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        provider.toggleCustContact(
                          clientId: item.id,
                          custId: contact.contactId,
                          newStatus: val,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 56),
                _imageButton(image: Paths.email, width: 20, onPressed: () {}),
                _imageButton(image: Paths.call, width: 20, onPressed: () {}),
                _imageButton(image: Paths.chat, width: 20, onPressed: () {}),
              ],
            ),
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
