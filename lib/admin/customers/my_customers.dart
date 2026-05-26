import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/customers/add_customer.dart';
import 'package:print_helper/admin/customers/edit_customer.dart';
// Unused import removed
import 'package:print_helper/models/customer_models.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/providers/cust_pro.dart';
import 'package:print_helper/utils/formatter.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/loaders.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/admin/client/bottombar/client_bottombar.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/widgets/spacers.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../filter/filter_screen.dart';

class MyCustomersScreen extends StatefulWidget {
  final int id;
  const MyCustomersScreen({super.key, required this.id});

  @override
  State<MyCustomersScreen> createState() => _MyCustomersScreenState();
}

class _MyCustomersScreenState extends State<MyCustomersScreen> {
  final _scrollController = ScrollController();

  Color _getSidebarColor(BuildContext context) {
    try {
      final authPro = Provider.of<AuthPro>(context, listen: false);
      final custPro = Provider.of<CustomerPro>(context, listen: false);
      final clPro = Provider.of<ClientPro>(context, listen: false);

      final role = authPro.user?.roleName;
      final isCustomer = role == "CUSTOMER";
      final isContact = role == "CONTACT"; // Client

      if (isCustomer || isContact) {
        String? primaryHex = custPro.client?.brandingPrimaryColor;
        if (primaryHex == null || primaryHex.isEmpty) {
          primaryHex = clPro.selectedClient?.primaryColor;
        }

        if (primaryHex != null && primaryHex.isNotEmpty) {
          return _hexToColor(primaryHex);
        }
        return Colors.black;
      }
    } catch (e) {
      debugPrint("Error getting sidebar color: $e");
    }
    return AppColors.amber;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<CustomerPro>(context, listen: false);
      pro.getCustomers(ctx: context, page: 1, clientId: widget.id);
    });
    _scrollController.addListener(_scrollPaginationListener);
  }

  void _scrollPaginationListener() {
    final pro = Provider.of<CustomerPro>(context, listen: false);
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!pro.isLoadingMore && pro.currentPage < pro.lastPage) {
        pro.getCustomers(
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
      backgroundColor: const Color(0xFFF3F4F7),
      appBar: _appBar(context),
      body: SafeArea(
        child: Consumer<CustomerPro>(
          builder: (context, provider, _) {
            if (provider.customersLoad) return Center(child: showLoader());

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  child: CustomButton(
                    title: "Contact Multiple Customers",
                    stadium: false,
                    height: 40.h,
                    buttonColor: _getSidebarColor(context),
                    textColor: AppColors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    borderRadius: 12,
                    onTap: () {},
                  ),
                ),
                if (provider.customers.isEmpty)
                  Expanded(
                    child: Center(
                      child: TextWidget(
                        text: 'No customers found.',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        provider.getCustomers(
                          ctx: context,
                          page: 1,
                          clientId: widget.id,
                        );
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 4.h,
                        ),
                        itemCount:
                            provider.customers.length +
                            (provider.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == provider.customers.length) {
                            return Padding(
                              padding: EdgeInsets.all(12.w),
                              child: Center(child: showLoader()),
                            );
                          }
                          return _customerCard(
                            provider.customers[index],
                            provider,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context) {
    final provider = Provider.of<CustomerPro>(context);
    final authPro = Provider.of<AuthPro>(context, listen: false);
    final role = authPro.user?.roleName ?? "";

    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 2,
      surfaceTintColor: AppColors.white,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          ImageWidget(image: Paths.customers, width: 22),
          SizedBox(width: 8.w),
          Consumer<CustomerPro>(
            builder: (context, pro, _) {
              if (pro.customersLoad) {
                return Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(width: 100, height: 20, color: Colors.white),
                );
              }
              return TextWidget(
                text: "Customers (${pro.totalCustomers})",
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.black,
              );
            },
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: Colors.black.withValues(alpha: .25),
              builder: (_) => FractionallySizedBox(
                heightFactor: .98,
                child: AddCustomer(clientId: widget.id, isFromClient: true),
              ),
            ).then((res) {
              if (!mounted) return;
              if (res == true) {
                provider.getCustomers(
                  ctx: context,
                  page: 1,
                  clientId: widget.id,
                );
              }
            });
          },
          child: provider.customersLoad && role == "CONTACT"
              ? Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(width: 70, height: 26, color: Colors.white),
                )
              : Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11.r),
                    border: Border.all(
                      color: _getSidebarColor(context),
                      width: 1.5,
                    ),
                  ),
                  child: const TextWidget(
                    text: "+ Customer",
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
        ),
        SizedBox(width: 8.w),
        Consumer<CustomerPro>(
          builder: (context, pro, _) {
            final count = pro.appliedFilterCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FractionallySizedBox(
                        heightFactor: 0.90,
                        child: FilterSheet(
                          initialFilters: pro.customerFilters,
                          isFromStaff: false,
                          isFromClient: true,
                        ),
                      ),
                    ).then((filters) {
                      if (!mounted) return;
                      if (filters != null && filters is Map<String, dynamic>) {
                        pro.applyCustFilters(filters, context, widget.id);
                      }
                    });
                  },
                  icon: ImageWidget(image: Paths.filter, width: 18),
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
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
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
        SizedBox(width: 8.w),
      ],
    );
  }

  Widget _customerCard(CustomerModel item, CustomerPro provider) {
    return _ExpandableCustomerCard(
      item: item,
      provider: provider,
      parentContext: context,
      topRowBuilder: (isExpanded) =>
          _topRow(context, item, provider, isExpanded),
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
    BuildContext context,
    CustomerModel item,
    CustomerPro provider,
    bool isExpanded,
  ) {
    final isPersonal = item.companyCategoryName.toLowerCase() == 'personal';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        if (!isPersonal) ...[
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: ImageWidget(
                image: (item.imageUrl == null || item.imageUrl!.isEmpty)
                    ? Paths.user
                    : item.imageUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 12.w),
        ],
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: isPersonal ? "Personal Account" : item.companyName,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              TextWidget(
                text: item.companyCategoryName,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              TextWidget(
                text: frmtDateTime(item.createdAt),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        // Right Column (Switch, Menu, Projects/Files)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 42.w,
                  height: 24.h,
                  child: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: item.status,
                      onChanged: (val) {
                        provider
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
                            });
                      },
                      activeTrackColor: const Color(0xFF10B981),
                      activeThumbColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                _buildPopupMenu(item),
                SizedBox(width: 4.w),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.black,
                  size: 20,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextWidget(
              text: "0 Projects • 0 Files",
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ],
        ),
      ],
    );
  }

  Widget _contactCard(
    ContactModel contact,
    CustomerPro provider,
    CustomerModel item,
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40.r),
                border: Border.all(color: Colors.black12, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40.r),
                child: ImageWidget(
                  image: (contact.image == null || contact.image!.isEmpty)
                      ? Paths.user
                      : contact.image!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Spacers.sbw12(),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: "${contact.name} ${contact.lastName}".trim(),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        Spacers.sb2(),
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
                          ),
                        ),
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
                      provider.toggleCustContact(
                        clientId: item.id,
                        custId: contact.contactId,
                        newStatus: val,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        Spacers.sb15(),
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
                      width: 28,
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
                      width: 21,
                      onPressed: () {
                        navTo(
                          context: context,
                          page: const ClientBottomBar(pageNum: 2),
                          removeUntil: true,
                        );
                      },
                    ),
                    _imageButton(
                      image: Paths.chat,
                      width: 22,
                      onPressed: () {
                        navTo(
                          context: context,
                          page: const ClientBottomBar(pageNum: 2),
                          removeUntil: true,
                        );
                      },
                    ),
                  ],
                ),
                if (contact.languages.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: 6.h,
                      left: 9.w,
                      right: 9.w,
                    ),
                    child: Center(
                      child: TextWidget(
                        text: contact.languages.join(" • "),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (index != total - 1) Spacers.sb10(),
        if (index != total - 1)
          Divider(color: AppColors.grey.withValues(alpha: .5), thickness: 1),
        if (index != total - 1) Spacers.sb10(),
      ],
    );
  }

  Widget _buildPopupMenu(CustomerModel item) {
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 20, color: Colors.black),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          if (value == 'edit') {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: Colors.black.withValues(alpha: .25),
              builder: (_) => FractionallySizedBox(
                heightFactor: 0.98,
                child: EditCustomer(
                  customerId: item.id,
                  clientId: item.clientId,
                  isFromClient: true,
                ),
              ),
            );
          } else if (value == 'delete') {
            _confirmDelete(context, item.id, item.clientId);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                ImageWidget(image: Paths.edit, width: 18),
                SizedBox(width: 12.w),
                const Text(
                  'Edit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                ImageWidget(image: Paths.delete, width: 18, color: Colors.red),
                SizedBox(width: 12.w),
                const Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id, int clientId) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const TextWidget(
            text: "Delete Customer",
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
          content: const TextWidget(
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
                final pro = Provider.of<CustomerPro>(context, listen: false);
                bool success = await pro.deleteCust(id, context);
                if (!mounted) return;
                if (success) {
                  showToast(message: "Customer deleted successfully");
                  pro.getCustomers(ctx: context, clientId: clientId, page: 1);
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

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class _ExpandableCustomerCard extends StatefulWidget {
  final CustomerModel item;
  final CustomerPro provider;
  final BuildContext parentContext;
  final Widget Function(bool isExpanded) topRowBuilder;
  final List<Widget> Function() contactsBuilder;

  const _ExpandableCustomerCard({
    required this.item,
    required this.provider,
    required this.parentContext,
    required this.topRowBuilder,
    required this.contactsBuilder,
  });

  @override
  State<_ExpandableCustomerCard> createState() =>
      _ExpandableCustomerCardState();
}

class _ExpandableCustomerCardState extends State<_ExpandableCustomerCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
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
                    ? BorderRadius.vertical(top: Radius.circular(16.r))
                    : BorderRadius.circular(16.r),
              ),
              child: widget.topRowBuilder(_isExpanded),
            ),
          ),
          if (_isExpanded) ...[
            Padding(
              padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 14.w),
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
