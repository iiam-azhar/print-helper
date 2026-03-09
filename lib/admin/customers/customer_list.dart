import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/customers/add_customer.dart';
import 'package:print_helper/admin/customers/edit_customer.dart';
import 'package:print_helper/providers/cust_pro.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/utils/formatter.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/customer_models.dart';
import '../../providers/auth_pro.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/spacers.dart';
import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../widgets/loaders.dart';
import '../../widgets/toasts.dart';
import '../filter/filter_screen.dart';
import '../../utils/console_util.dart';

class CustomersScreen extends StatefulWidget {
  final bool isFromAdmin;
  final bool isFromStaff;
  final bool isFromClient;
  final int id;
  const CustomersScreen({
    super.key,
    required this.isFromAdmin,
    required this.isFromStaff,
    required this.isFromClient,
    required this.id,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    printData(title: "isFromClient:", data: widget.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = Provider.of<CustomerPro>(context, listen: false);
      pro.getCustomers(ctx: context, clientId: widget.id);
      setState(() {});
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
    // print("widget.isFromAdmin ${widget.isFromAdmin}");
    // print("widget.isFromStaff ${widget.isFromStaff}");
    // print("widget.isFromClient ${widget.isFromClient}");
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
                if (provider.customersLoad) {
                  return Center(child: showLoader());
                }
                return ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  children: [
                    widget.isFromAdmin || widget.isFromStaff
                        ? _header(provider)
                        : SizedBox(),
                    widget.isFromAdmin || widget.isFromStaff
                        ? Spacers.sb12()
                        : SizedBox(),
                    provider.customers.isEmpty
                        ? SizedBox()
                        : CustomButton(
                            title: "Contact Multiple Customers",
                            stadium: false,
                            height: 45,
                            textColor: AppColors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            buttonColor:
                                (!widget.isFromAdmin &&
                                    !widget.isFromStaff &&
                                    provider.client?.brandingPrimaryColor !=
                                        null)
                                ? hexToColor(
                                    provider.client!.brandingPrimaryColor,
                                  )
                                : AppColors.primary,
                            borderRadius: 12,
                            onTap: () {},
                          ),
                    provider.customers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40.h),
                              child: TextWidget(
                                text: "No customers",
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey,
                              ),
                            ),
                          )
                        : Spacers.sb12(),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(CustomerPro item) {
    final client = item.client;
    if (client == null) {
      return SizedBox();
    }
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.w),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(56.r),
              child: ImageWidget(
                image:
                    (item.client!.image == null || item.client!.image!.isEmpty)
                    ? Paths.user
                    : item.client!.image.toString(),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Spacers.sbw10(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          TextWidget(
                            text: item.client!.companyName,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            maxLines: 1,
                          ),
                          TextWidget(
                            text: item.client!.companyTypeName,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            maxLines: 1,
                          ),
                          Spacers.sb2(),
                          TextWidget(
                            text: frmtDateTime(item.client!.createdAt),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                    Spacers.sbw5(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .end,
                        children: [
                          TextWidget(
                            text: '511 Projects - 31241 Files',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          widget.isFromAdmin
                              ? Row(
                                  mainAxisAlignment: .end,
                                  children: [
                                    IconButton(
                                      onPressed: () {},
                                      icon: ImageWidget(
                                        image: Paths.login,
                                        width: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {},
                                      icon: ImageWidget(
                                        image: Paths.edit,
                                        width: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : SizedBox(),
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
    );
  }

  AppBar _appBar(BuildContext context) {
    // final pro = getCustPro(context);
    // final Color primaryColor = widget.isFromClient
    //     ? hexToColor(pro.client!.brandingPrimaryColor)
    //     : AppColors.primary;

    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 2,
      surfaceTintColor: AppColors.white,
      automaticallyImplyLeading: false,
      title: Consumer<CustomerPro>(
        builder: (context, prov, _) {
          return Row(
            children: [
              ImageWidget(image: Paths.customers, width: 28),
              Spacers.sbw12(),
              TextWidget(
                text: "Customers (${prov.totalCustomers})",
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF414345),
              ),
            ],
          );
        },
      ),
      actions: [
        widget.isFromAdmin || widget.isFromStaff || widget.isFromClient
            ? GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    barrierColor: Colors.black.withValues(alpha: .25),
                    builder: (_) => FractionallySizedBox(
                      heightFactor: .98,
                      child: AddCustomer(
                        clientId: widget.id,
                        isFromClient: widget.isFromClient,
                      ),
                    ),
                  );
                },
                child: Consumer<CustomerPro>(
                  builder: (context, pro, _) {
                    if (widget.isFromClient && pro.client == null) {
                      return addCustomerShimmer();
                    }
                    final Color primaryColor =
                        widget.isFromClient && pro.client != null
                        ? hexToColor(pro.client!.brandingPrimaryColor)
                        : AppColors.primary;

                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: primaryColor, width: 1.5),
                      ),
                      child: TextWidget(
                        text: "+ Customer",
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: const Color(0xFF414345),
                      ),
                    );
                  },
                ),
              )
            : SizedBox(),
        Spacers.sbw10(),
        Consumer<CustomerPro>(
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

  void _filterBottomSheet(dynamic context, CustomerPro pro) {
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
      if (filters != null && filters is Map<String, dynamic>) {
        pro.applyCustFilters(filters, context, widget.id);
      }
    });
  }

  Widget _customerCard(CustomerModel item, CustomerPro provider) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      padding: EdgeInsets.all(16.w),
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
      crossAxisAlignment: .center,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40.r),
            border: Border.all(color: Colors.black12, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40.r),
            child: ImageWidget(
              image: item.imageUrl ?? Paths.user,
              width: 40,
              height: 40,
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
              ),
              TextWidget(
                text: item.companyCategoryName,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Colors.black87,
              ),
              Spacers.sb2(),
              TextWidget(
                text: frmtDateTime(item.createdAt),
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
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
                mainAxisAlignment: .end,
                children: [
                  Switch(
                    padding: EdgeInsets.zero,
                    value: item.status,
                    activeTrackColor: const Color(0xFF00a650),
                    activeThumbColor: Colors.white,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      setState(() {});
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
                                            vertical: 10.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
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
                                              Spacers.sbw8(),
                                              _popupIcon(
                                                icon: Paths.edit,
                                                label: "Edit",
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  showModalBottomSheet(
                                                    context: context,
                                                    isScrollControlled: true,
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    builder: (_) {
                                                      return FractionallySizedBox(
                                                        heightFactor: 0.98,
                                                        child: EditCustomer(
                                                          customerId: item.id,
                                                          clientId:
                                                              item.clientId,
                                                          isFromClient: widget
                                                              .isFromClient,
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
                                                    item.clientId,
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
                            border: Border.all(color: Colors.grey, width: 1),
                          ),
                          child: Icon(Icons.more_vert, size: 20.sp),
                        ),
                      );
                    },
                  ),
                ],
              ),
              TextWidget(
                text: '4 Projects • 3 Files',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Colors.black87,
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
                Navigator.pop(context);
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
                  image: contact.imageUrl ?? Paths.user,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Spacers.sbw12(),
            Expanded(
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: .start,
                    children: [
                      TextWidget(
                        text: contact.name,
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
                        ),
                      ),
                    ],
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
            width: 220.w,
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
                  mainAxisAlignment: .center,
                  // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                      width: 22,
                      onPressed: () {},
                    ),
                    _imageButton(
                      image: Paths.chat,
                      width: 22,
                      onPressed: () {},
                    ),
                    widget.isFromAdmin
                        ? _imageButton(
                            image: Paths.login,
                            width: 22,
                            onPressed: () async {
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
                            },
                          )
                        : SizedBox(),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 6.h, left: 6.w, right: 6.w),
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
          Divider(color: AppColors.grey.withValues(alpha: .5)),
        if (index != total - 1) Spacers.sb10(),
      ],
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

  Widget addCustomerShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: 95.w,
        height: 28.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }
}
