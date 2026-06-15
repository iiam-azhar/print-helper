// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/admin/client/edit_client.dart';
import 'package:print_helper/admin/customers/add_customer.dart';
import 'package:print_helper/admin/customers/edit_customer.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/providers/cust_pro.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/utils/formatter.dart';
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
import '../adminBottombar/admin_bottombar.dart';
import '../staff/bottombar/staff_bottombar.dart';
import '../client/bottombar/client_bottombar.dart';
import 'bottombar/cust_bottombar.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();
  int _activeNetworkTab = 0;

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
    _searchCtrl.dispose();
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
            if (provider.customersLoad) {
              return Center(child: showLoader());
            }

            final clientName =
                provider.client?.companyName.trim().isNotEmpty == true
                ? provider.client!.companyName
                : 'Client';

            return SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(8.w, 12.h, 8.w, 14.h),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _tabChip('Customers', 0),
                          SizedBox(width: 10.w),
                          _tabChip('Assigned Team', 1),
                          SizedBox(width: 10.w),
                          _tabChip('Internal Ops', 2),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
                      child: _activeNetworkTab == 0
                          ? _customersTab(provider, clientName)
                          : _activeNetworkTab == 1
                          ? _assignedTeamTab(provider, clientName)
                          : _internalOpsTab(clientName),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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
                                      onPressed: () async {
                                        printData(
                                          title: 'Banner Login Tap Client ID',
                                          data: item.client!.id,
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
                                                orElse: () => clientDetails
                                                    .contacts
                                                    .first,
                                              );

                                          await authPro.switchUser(
                                            userId: primary.id,
                                            context: context,
                                          );
                                        } else {
                                          showToast(
                                            message:
                                                'No client contact found for login',
                                          );
                                        }
                                      },
                                      icon: ImageWidget(
                                        image: Paths.login,
                                        width: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        printData(
                                          title: 'Banner Edit Tap Client ID',
                                          data: item.client!.id,
                                        );
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          barrierColor: Colors.black.withValues(
                                            alpha: .25,
                                          ),
                                          builder: (_) => FractionallySizedBox(
                                            heightFactor: 0.98,
                                            child: EditClient(
                                              clientId: item.client!.id,
                                            ),
                                          ),
                                        );
                                      },
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
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      surfaceTintColor: Colors.white,
      automaticallyImplyLeading: false,
      titleSpacing: 8.w,
      title: Consumer<CustomerPro>(
        builder: (context, prov, _) {
          final clientName = prov.client?.companyName.trim().isNotEmpty == true
              ? prov.client!.companyName
              : 'Client';
          return Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(width: 8.w),
              ImageWidget(image: Paths.customers, width: 20),
              SizedBox(width: 8.w),
              Expanded(
                child: TextWidget(
                  text: 'Clients/ $clientName',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  maxLines: 1,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => showToast(message: 'Deactivate coming soon'),
          icon: const Icon(Icons.block, size: 15, color: Color(0xFFEF4444)),
          label: const TextWidget(
            text: 'Deactivate',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFFEF4444),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEF4444)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
        ),
        SizedBox(width: 12.w),
      ],
    );
  }

  Widget _tabChip(String label, int index) {
    final active = _activeNetworkTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeNetworkTab = index),
        child: Container(
          height: 36.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: active ? const Color(0xFFE5E7EB) : Colors.transparent,
            ),
          ),
          child: TextWidget(
            text: label,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _customersTab(CustomerPro provider, String clientName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text:
              'End customers of $clientName. Admin can add, edit, and delete on behalf of the client.',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF64748B),
        ),
        SizedBox(height: 10.h),
        Align(
          alignment: Alignment.centerRight,
          child: _solidGreenButton(
            label: '+ Customer',
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
          ),
        ),
        SizedBox(height: 10.h),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search customers...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(child: _fakeDropdown('All Types')),
            SizedBox(width: 10.w),
            Expanded(child: _fakeDropdown('All Status')),
            SizedBox(width: 10.w),
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF3F4F6),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: const Icon(Icons.refresh, color: Color(0xFF6B7280)),
            ),
            SizedBox(width: 10.w),
            Container(
              width: 40.w,
              height: 40.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF3F4F6),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: TextWidget(
                text: provider.totalCustomers.toString(),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        if (provider.customers.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 36.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: const Center(
              child: TextWidget(
                text: 'No customers found.',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount:
                provider.customers.length + (provider.isLoadingMore ? 1 : 0),
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              if (index == provider.customers.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Center(child: showLoader()),
                );
              }
              return _customerCard(provider.customers[index], provider);
            },
          ),
      ],
    );
  }

  Widget _assignedTeamTab(CustomerPro provider, String clientName) {
    final specialists = _assignedSpecialists(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _teamCard(
          title: 'ASSIGNED SPECIALISTS',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (specialists.isEmpty)
                const TextWidget(
                  text: 'No specialists assigned.',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                )
              else
                ...specialists.map(
                  (specialist) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24.r,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: ClipOval(
                            child: ImageWidget(
                              image: specialist.image?.isNotEmpty == true
                                  ? specialist.image!
                                  : Paths.user,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextWidget(
                                text:
                                    '${specialist.name} ${specialist.lastName}'
                                        .trim(),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              TextWidget(
                                text: specialist.email,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Center(
                            child: ImageWidget(
                              image: Paths.delete,
                              width: 18,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 14.h),
              _outlineAction('+  Assign Specialist'),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        _teamCard(
          title: 'SUPERVISOR',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextWidget(
                text: 'No supervisor assigned.',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              SizedBox(height: 12.h),
              _outlineAction('+  Assign Supervisor'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _internalOpsTab(String clientName) {
    final handle = clientName.toLowerCase().replaceAll(' ', '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextWidget(
          text:
              'Main contact can manage all contacts. Additional contacts are view-only except their own settings.',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF64748B),
        ),
        SizedBox(height: 10.h),
        Align(
          alignment: Alignment.centerRight,
          child: _solidGreenButton(label: '+ Add Contact', onTap: () {}),
        ),
        SizedBox(height: 10.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFEAB308)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24.r,
                    backgroundColor: const Color(0xFFFACC15),
                    child: const TextWidget(
                      text: 'A',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: '$clientName Solution',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        TextWidget(
                          text: '@$handle',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const TextWidget(
                      text: 'Main',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              const Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 16,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(width: 6),
                  TextWidget(
                    text: 'No email',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Divider(color: const Color(0xFFE5E7EB), height: 1.h),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _softAction('Edit', icon: Icons.edit_outlined),
                  _softAction('Reset Password', icon: Icons.key_outlined),
                  _solidGreenButton(
                    label: 'Login',
                    onTap: () {},
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          height: 200.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: const Color(0xFFD1D5DB),
              style: BorderStyle.solid,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_alt_1,
                  size: 28,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(height: 10),
                TextWidget(
                  text: 'Add Contact',
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fakeDropdown(String label) {
    return Container(
      height: 42.h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        children: [
          TextWidget(
            text: label,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111827),
          ),
          const Spacer(),
          const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
        ],
      ),
    );
  }

  Widget _teamCard({required String title, required Widget body}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: title,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: const Color(0xFF64748B),
          ),
          SizedBox(height: 10.h),
          Divider(color: const Color(0xFFD1D5DB), height: 1.h),
          SizedBox(height: 10.h),
          body,
        ],
      ),
    );
  }

  Widget _outlineAction(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: TextWidget(
        text: text,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF334155),
      ),
    );
  }

  Widget _solidGreenButton({
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14.w : 16.w,
          vertical: compact ? 9.h : 10.h,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: TextWidget(
          text: label,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _softAction(String label, {required IconData icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          SizedBox(width: 6.w),
          TextWidget(
            text: label,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ],
      ),
    );
  }

  List<AssignedSpecialistModel> _assignedSpecialists(CustomerPro provider) {
    final specialists = <AssignedSpecialistModel>[];
    final seenIds = <int>{};

    for (final specialist in provider.client?.assignedSpecialists ?? const []) {
      if (seenIds.add(specialist.id)) {
        specialists.add(specialist);
      }
    }

    for (final customer in provider.customers) {
      for (final specialist in customer.assignedSpecialists) {
        if (seenIds.add(specialist.id)) {
          specialists.add(specialist);
        }
      }
    }

    return specialists;
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
                      onPressed: () {
                        if (widget.isFromAdmin) {
                          navTo(
                            context: context,
                            page: AdminBottomBar(pageNum: 2),
                            removeUntil: true,
                          );
                        } else if (widget.isFromStaff) {
                          navTo(
                            context: context,
                            page: StaffBottomBar(pageNum: 2),
                            removeUntil: true,
                          );
                        } else if (widget.isFromClient) {
                          navTo(
                            context: context,
                            page: ClientBottomBar(pageNum: 2),
                            removeUntil: true,
                          );
                        } else {
                          navTo(
                            context: context,
                            page: CustBottomBar(pageNum: 2),
                            removeUntil: true,
                          );
                        }
                      },
                    ),
                    _imageButton(
                      image: Paths.chat,
                      width: 22,
                      onPressed: () {
                        if (widget.isFromAdmin) {
                          navTo(
                            context: context,
                            page: AdminBottomBar(pageNum: 2),
                            removeUntil: true,
                          );
                        } else if (widget.isFromStaff) {
                          navTo(
                            context: context,
                            page: StaffBottomBar(pageNum: 2),
                            removeUntil: true,
                          );
                        } else if (widget.isFromClient) {
                          navTo(
                            context: context,
                            page: ClientBottomBar(pageNum: 2),
                            removeUntil: true,
                          );
                        } else {
                          navTo(
                            context: context,
                            page: CustBottomBar(pageNum: 2),
                            removeUntil: true,
                          );
                        }
                      },
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
